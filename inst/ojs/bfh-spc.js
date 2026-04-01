// BFHcharts Observable JS - Hoved SPC Chart Modul
// Bygger Observable Plot med BFH styling og Anhøj rules visualisering

import { prepareData } from "./bfh-spc-utils.js";
import { createYAxisFormatter } from "./bfh-spc-scales.js";

/**
 * Opret et BFH-styled SPC chart med Observable Plot
 *
 * @param {object} spcData - Data fra bfh_ojs_define() (via ojs_define)
 * @param {object} options - Valgfrie indstillinger: width, height
 * @returns {HTMLElement} Container med Observable Plot SVG + footer
 */
export function bfhSpcChart(spcData, options = {}) {
  const { points, config, colors } = prepareData(spcData);

  if (points.length === 0) {
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

  // Beregn extended x-position (20% ud over sidste datapunkt)
  const extended = computeExtendedLines(points, config, hasLimits, colors);

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

  // 8. Extended lines (CL og target forlænget 20% ud over sidste datapunkt)
  for (const ext of extended) {
    marks.push(
      Plot.line(ext.data, {
        x: "x",
        y: "y",
        stroke: ext.color,
        strokeWidth: ext.strokeWidth,
        strokeDasharray: ext.strokeDasharray || null
      })
    );
  }

  // 9. Annotationer/noter (pre-beregnet collision avoidance fra R)
  if (spcData.annotations && spcData.annotations.length > 0) {
    const annotations = spcData.annotations.map(a => ({
      ...a,
      label_x: new Date(a.label_x),
      point_x: new Date(a.point_x),
      arrow_x: new Date(a.arrow_x)
    }));

    // Pile fra label til datapunkt
    const withArrows = annotations.filter(a => a.draw_arrow);
    if (withArrows.length > 0) {
      marks.push(
        Plot.arrow(withArrows, {
          x1: "arrow_x",
          y1: "arrow_y",
          x2: "point_x",
          y2: "point_y",
          stroke: colors.hospital_grey,
          strokeWidth: 0.5,
          headLength: 4,
          bend: d => d.curvature !== 0
        })
      );
    }

    // Label-tekst
    marks.push(
      Plot.text(annotations, {
        x: "label_x",
        y: "label_y",
        text: "label_text",
        fill: colors.hospital_dark_grey,
        fontSize: 11,
        lineAnchor: "middle",
        textAnchor: "middle"
      })
    );
  }

  // 10. Højre-side labels (CL-værdi, target-værdi)
  const rightLabels = buildRightLabels(points, config, colors, extended);
  for (const label of rightLabels) {
    marks.push(
      Plot.text([label], {
        x: "x",
        y: "y",
        text: "text",
        fill: label.color,
        fontSize: 11,
        fontWeight: "bold",
        textAnchor: "start",
        dx: 6
      })
    );
  }

  // Y-akse formatter baseret på enhedstype
  const yFormatter = createYAxisFormatter(config.y_axis_unit, points);

  // Beregn x-domæne med extension
  const xExtent = [
    Math.min(...points.map(d => d.x.getTime())),
    Math.max(...points.map(d => d.x.getTime()), ...extended.map(e => e.data[1].x.getTime()))
  ];

  // Byg Observable Plot
  const plot = Plot.plot({
    width,
    height,
    x: {
      type: "utc",
      label: config.xlab || null,
      domain: [new Date(xExtent[0]), new Date(xExtent[1])]
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

  // Wrap i container med footer
  const container = document.createElement("div");
  container.appendChild(plot);

  // Footer
  if (spcData.footer) {
    const footer = document.createElement("div");
    footer.style.fontFamily = "Roboto, Arial, sans-serif";
    footer.style.fontSize = "10px";
    footer.style.color = colors.hospital_dark_grey;
    footer.style.marginTop = "4px";
    footer.style.paddingLeft = "40px";
    footer.textContent = spcData.footer;
    container.appendChild(footer);
  }

  return container;
}


// ============================================================================
// EXTENDED LINES - Forlæng CL og target 20% ud over sidste datapunkt
// Porteret fra R/plot_enhancements.R linje 45-103
// ============================================================================

function computeExtendedLines(points, config, hasLimits, colors) {
  if (points.length < 2) return [];

  const result = [];
  const firstX = points[0].x;
  const lastX = points[points.length - 1].x;
  const rangeMs = lastX.getTime() - firstX.getTime();
  const extendedX = new Date(lastX.getTime() + rangeMs * 0.20);

  // Centerlinje extension (kun seneste fase)
  const latestPart = Math.max(...points.map(d => d.part));
  const latestPartPoints = points.filter(d => d.part === latestPart && d.cl !== null);

  if (latestPartPoints.length > 0) {
    const lastPoint = latestPartPoints[latestPartPoints.length - 1];
    const hasSignal = latestPartPoints.some(d => d.anhoej_signal);

    result.push({
      type: "cl",
      color: colors.hospital_blue,
      strokeWidth: 1.5,
      strokeDasharray: hasSignal ? "6 3" : null,
      data: [
        { x: lastPoint.x, y: lastPoint.cl },
        { x: extendedX, y: lastPoint.cl }
      ]
    });
  }

  // Target extension
  if (config.target_value !== null && config.target_value !== undefined) {
    result.push({
      type: "target",
      color: colors.hospital_dark_grey,
      strokeWidth: 1,
      strokeDasharray: "4 2",
      data: [
        { x: lastX, y: config.target_value },
        { x: extendedX, y: config.target_value }
      ]
    });
  }

  return result;
}


// ============================================================================
// RIGHT LABELS - CL-værdi og target-værdi ved højre kant
// Porteret fra R/fct_add_spc_labels.R
// ============================================================================

function buildRightLabels(points, config, colors, extended) {
  const labels = [];
  if (points.length === 0) return labels;

  // Find extended x-position (eller sidste datapunkt)
  const extX = extended.length > 0
    ? extended[0].data[1].x
    : points[points.length - 1].x;

  // CL label
  const latestPart = Math.max(...points.map(d => d.part));
  const latestPartPoints = points.filter(d => d.part === latestPart && d.cl !== null);
  if (latestPartPoints.length > 0) {
    const clValue = latestPartPoints[latestPartPoints.length - 1].cl;
    const formatter = createYAxisFormatter(config.y_axis_unit, points);
    labels.push({
      x: extX,
      y: clValue,
      text: "CL: " + formatter(clValue),
      color: colors.hospital_blue
    });
  }

  // Target label
  if (config.target_value !== null && config.target_value !== undefined) {
    const formatter = createYAxisFormatter(config.y_axis_unit, points);
    const targetText = config.target_text || ("Mål: " + formatter(config.target_value));
    labels.push({
      x: extX,
      y: config.target_value,
      text: targetText,
      color: colors.hospital_dark_grey
    });
  }

  return labels;
}
