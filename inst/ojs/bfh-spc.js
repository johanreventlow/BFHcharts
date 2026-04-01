// BFHcharts Observable JS - Hoved SPC Chart Modul
// Bygger Observable Plot med BFH styling og Anhøj rules visualisering

import { prepareData } from "./bfh-spc-utils.js";
import { createYAxisFormatter } from "./bfh-spc-scales.js";

/**
 * Opret et BFH-styled SPC chart med Observable Plot
 *
 * @param {object} spcData - Data fra bfh_ojs_define() (via ojs_define)
 * @param {object} options - Valgfrie indstillinger: width, height
 * @returns {SVGElement} Observable Plot SVG element
 */
export function bfhSpcChart(spcData, options = {}) {
  const { points, config, colors } = prepareData(spcData);

  if (points.length === 0) {
    // Tom data - returner tom SVG med besked
    const div = document.createElement("div");
    div.style.fontFamily = "Roboto, Arial, sans-serif";
    div.style.color = colors.hospital_dark_grey;
    div.style.padding = "2em";
    div.textContent = "No data available for SPC chart.";
    return div;
  }

  const width = options.width || 800;
  const height = options.height || 400;

  // Tjek om data har kontrolgrænser
  const hasLimits = points.some(d => d.ucl !== null && d.lcl !== null);

  // Byg marks i samme rækkefølge som R/plot_core.R linje 146-213
  const marks = [];

  // 1. Kontrolgrænse-ribbon (kun hvis kontrolgrænser findes)
  if (hasLimits) {
    const limitsData = points.filter(d => d.ucl !== null && d.lcl !== null);

    marks.push(
      Plot.areaY(limitsData, {
        x: "x",
        y1: "lcl",
        y2: "ucl",
        fill: colors.very_light_blue,
        fillOpacity: 0.5,
        z: "part"
      })
    );

    // 2. UCL linje
    marks.push(
      Plot.lineY(limitsData, {
        x: "x",
        y: "ucl",
        stroke: colors.light_blue,
        strokeWidth: 0.8,
        z: "part"
      })
    );

    // 3. LCL linje
    marks.push(
      Plot.lineY(limitsData, {
        x: "x",
        y: "lcl",
        stroke: colors.light_blue,
        strokeWidth: 0.8,
        z: "part"
      })
    );
  }

  // 4. Target linje (kun hvis target_value er sat)
  if (config.target_value !== null && config.target_value !== undefined) {
    marks.push(
      Plot.ruleY([config.target_value], {
        stroke: colors.hospital_dark_grey,
        strokeDasharray: "4 2",
        strokeWidth: 1
      })
    );
  }

  // 5. Data linje
  marks.push(
    Plot.lineY(points, {
      x: "x",
      y: "y",
      stroke: colors.hospital_grey,
      strokeWidth: 1.5,
      z: "part"
    })
  );

  // 6. Datapunkter (sigma_signal faar hospital_blue, ellers hospital_grey)
  marks.push(
    Plot.dot(points, {
      x: "x",
      y: "y",
      fill: d => d.sigma_signal ? colors.hospital_blue : colors.hospital_grey,
      r: 3,
      stroke: "white",
      strokeWidth: 0.5
    })
  );

  // 7. Centrallinje per fase med Anhøj signal visning
  // Gruppér punkter per part og render separat for at håndtere linetype
  const parts = [...new Set(points.map(d => d.part))];
  for (const p of parts) {
    const partPoints = points.filter(d => d.part === p && d.cl !== null);
    if (partPoints.length === 0) continue;

    const hasSignal = partPoints.some(d => d.anhoej_signal);
    marks.push(
      Plot.lineY(partPoints, {
        x: "x",
        y: "cl",
        stroke: colors.hospital_blue,
        strokeWidth: 1.5,
        strokeDasharray: hasSignal ? "6 3" : null
      })
    );
  }

  // Y-akse formatter baseret på enhedstype
  const yFormatter = createYAxisFormatter(config.y_axis_unit, points);

  // Byg Observable Plot
  return Plot.plot({
    width,
    height,
    x: {
      type: "utc",
      label: config.xlab || null
    },
    y: {
      label: config.ylab || null,
      tickFormat: yFormatter
    },
    marks,
    style: {
      fontFamily: "Roboto, Arial, sans-serif"
    },
    ...(config.chart_title ? { title: config.chart_title } : {})
  });
}
