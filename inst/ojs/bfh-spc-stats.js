// BFHcharts Observable JS - Standalone SPC Statistik-motor
// Porteret fra qicharts2 (https://github.com/anhoej/qicharts2)
// Beregner kontrolgrænser, centerlinjer og Anhøj-regler uden R-backend

// ============================================================================
// HOVED-API
// ============================================================================

/**
 * Beregn SPC statistik fra rådata (standalone, ingen R påkrævet)
 *
 * @param {Array} data - Array af objekter med mindst x og y kolonner
 * @param {object} options - Konfiguration:
 *   chartType: "run"|"i"|"mr"|"p"|"u"|"c"|"g" (default "i")
 *   x: string - kolonne-navn for x-akse (default "x")
 *   y: string - kolonne-navn for y-akse/tæller (default "y")
 *   n: string - kolonne-navn for nævner (påkrævet for p/u charts)
 *   target: number - target-værdi (valgfri)
 *   freeze: number - antal observationer til baseline (valgfri)
 *   part: Array<number> - indeks-positioner for fase-splits (valgfri)
 *   cl: number - fast centerlinje (overrider beregning)
 *   multiply: number - multiplikator for y-værdier (default 1)
 *   excludeIndices: Array<number> - indekser der ekskluderes fra beregning
 * @returns {object} SPC data i samme format som bfh_ojs_define() output
 */
export function computeSpc(data, options = {}) {
  const chartType = options.chartType || "i";
  const xCol = options.x || "x";
  const yCol = options.y || "y";
  const nCol = options.n || null;
  const multiply = options.multiply || 1;
  const excludeSet = new Set(options.excludeIndices || []);

  // Forbered data
  const points = data.map((row, i) => {
    const y = Number(row[yCol]) * multiply;
    const n = nCol ? Number(row[nCol]) : null;
    const x = row[xCol];
    return { x, y, n, index: i, excluded: excludeSet.has(i) };
  }).filter(d => !isNaN(d.y));

  // Bestem faser
  const phases = assignPhases(points, options.part, options.freeze);

  // Beregn statistik per fase
  const result = [];
  for (const phase of phases) {
    const phasePoints = phase.points;
    const baselinePoints = phasePoints.filter(d => d.isBaseline && !d.excluded);

    // Beregn y-værdier for charts der kræver nævner
    const yValues = computeChartY(baselinePoints, chartType);
    const allYValues = computeChartY(phasePoints, chartType);

    // Centerlinje
    const cl = options.cl != null ? options.cl : computeCenterline(yValues, chartType);

    // Kontrolgrænser
    const limits = computeControlLimits(baselinePoints, chartType, cl);

    // Anhøj-regler (beregnes på alle y-værdier i fasen, ikke kun baseline)
    const anhoejStats = computeAnhoejRules(allYValues, cl);

    // Byg output-rækker
    for (const pt of phasePoints) {
      const ptY = computePointY(pt, chartType);
      const ptLimits = computePointLimits(pt, chartType, cl, limits);

      result.push({
        x: pt.x,
        y: ptY,
        cl: cl,
        ucl: ptLimits.ucl,
        lcl: ptLimits.lcl,
        target: options.target != null ? options.target : null,
        part: phase.id,
        sigma_signal: ptLimits.ucl !== null &&
          (ptY > ptLimits.ucl || ptY < ptLimits.lcl),
        anhoej_signal: anhoejStats.signal,
        notes: null
      });
    }
  }

  // Returner i bfh_ojs_define-kompatibelt format
  return {
    data: result,
    config: {
      chart_type: chartType,
      y_axis_unit: options.yAxisUnit || "count",
      chart_title: options.chartTitle || null,
      target_value: options.target != null ? options.target : null,
      target_text: options.targetText || null
    },
    colors: null, // Bruger default farver fra bfh-spc-utils.js
    summary: phases.map(phase => {
      const yVals = computeChartY(phase.points, chartType);
      const cl = options.cl != null ? options.cl : computeCenterline(
        computeChartY(phase.points.filter(d => d.isBaseline && !d.excluded), chartType),
        chartType
      );
      const stats = computeAnhoejRules(yVals, cl);
      return {
        fase: phase.id,
        centerlinje: cl,
        laengste_loeb: stats.longestRun,
        laengste_loeb_max: stats.expectedLongestRun,
        antal_kryds: stats.crossings,
        antal_kryds_min: stats.expectedMinCrossings,
        lobelaengde_signal: stats.runsSignal,
        sigma_signal: false // Beregnes per punkt
      };
    })
  };
}


// ============================================================================
// FASE/FREEZE SUPPORT
// ============================================================================

/**
 * Tildel datapunkter til faser baseret på part/freeze parametre
 */
function assignPhases(points, partPositions, freeze) {
  if (!partPositions && !freeze) {
    // Én fase, alle punkter er baseline
    return [{
      id: 1,
      points: points.map(p => ({ ...p, isBaseline: true }))
    }];
  }

  if (freeze && !partPositions) {
    // Freeze: baseline op til freeze, resten bruger baseline-beregning
    return [{
      id: 1,
      points: points.map((p, i) => ({
        ...p,
        isBaseline: i < freeze
      }))
    }];
  }

  // Part positions: split i separate faser
  const splits = Array.isArray(partPositions) ? partPositions : [partPositions];
  const boundaries = [0, ...splits.sort((a, b) => a - b), points.length];
  const phases = [];

  for (let i = 0; i < boundaries.length - 1; i++) {
    const start = boundaries[i];
    const end = boundaries[i + 1];
    const phasePoints = points.slice(start, end).map(p => ({
      ...p,
      isBaseline: true // Hver fase bruger hele fasen som baseline
    }));

    if (phasePoints.length > 0) {
      phases.push({ id: i + 1, points: phasePoints });
    }
  }

  return phases;
}


// ============================================================================
// CENTERLINJE-BEREGNING
// ============================================================================

/**
 * Beregn centerlinje baseret på chart type
 */
function computeCenterline(yValues, chartType) {
  if (yValues.length === 0) return 0;

  switch (chartType) {
    case "run":
      return median(yValues);
    case "mr":
      return mean(yValues);
    default:
      // i, p, u, c, g, xbar, s, t
      return mean(yValues);
  }
}


// ============================================================================
// KONTROLGRÆNSE-FORMLER
// Ref: qicharts2, Montgomery "Introduction to Statistical Quality Control"
// ============================================================================

/**
 * Beregn kontrolgrænser baseret på chart type
 * Returnerer { sigma, ucl_offset, lcl_offset } eller per-punkt funktion
 */
function computeControlLimits(baselinePoints, chartType, cl) {
  if (baselinePoints.length < 2) {
    return { type: "none" };
  }

  switch (chartType) {
    case "run":
      // Run charts har ingen kontrolgrænser
      return { type: "none" };

    case "i": {
      // I-chart: sigma = MR-bar / d2, d2 = 1.128 for n=2
      const mr = movingRanges(baselinePoints.map(d => computePointY(d, "i")));
      const mrBar = mean(mr);
      const sigma = mrBar / D2;
      return { type: "fixed", ucl: cl + 3 * sigma, lcl: Math.max(0, cl - 3 * sigma) };
    }

    case "mr": {
      // MR-chart: UCL = D4 * MR-bar, LCL = D3 * MR-bar
      const yVals = baselinePoints.map(d => computePointY(d, "mr"));
      const mrBar = mean(yVals);
      return { type: "fixed", ucl: D4 * mrBar, lcl: D3 * mrBar };
    }

    case "p": {
      // P-chart: per-punkt grænser (varierer med n)
      const pBar = cl;
      return {
        type: "variable",
        compute: (pt) => {
          const n = pt.n || 1;
          const sigma = Math.sqrt(pBar * (1 - pBar) / n);
          return {
            ucl: Math.min(1, pBar + 3 * sigma),
            lcl: Math.max(0, pBar - 3 * sigma)
          };
        }
      };
    }

    case "u": {
      // U-chart: per-punkt grænser (varierer med n)
      const uBar = cl;
      return {
        type: "variable",
        compute: (pt) => {
          const n = pt.n || 1;
          const sigma = Math.sqrt(uBar / n);
          return {
            ucl: uBar + 3 * sigma,
            lcl: Math.max(0, uBar - 3 * sigma)
          };
        }
      };
    }

    case "c": {
      // C-chart: faste grænser
      const cBar = cl;
      const sigma = Math.sqrt(cBar);
      return { type: "fixed", ucl: cBar + 3 * sigma, lcl: Math.max(0, cBar - 3 * sigma) };
    }

    case "g": {
      // G-chart: geometrisk baseret
      const gBar = cl;
      // G-chart bruger transformeret Poisson-tilnærmelse
      const sigma = Math.sqrt(gBar * (gBar + 1));
      return { type: "fixed", ucl: gBar + 3 * sigma, lcl: Math.max(0, gBar - 3 * sigma) };
    }

    default:
      return { type: "none" };
  }
}

/**
 * Beregn kontrolgrænser for et enkelt punkt
 */
function computePointLimits(pt, chartType, cl, limits) {
  if (limits.type === "none") {
    return { ucl: null, lcl: null };
  }
  if (limits.type === "fixed") {
    return { ucl: limits.ucl, lcl: limits.lcl };
  }
  if (limits.type === "variable") {
    return limits.compute(pt);
  }
  return { ucl: null, lcl: null };
}


// ============================================================================
// CHART-SPECIFIKKE Y-BEREGNINGER
// ============================================================================

/**
 * Beregn y-værdi for et punkt baseret på chart type
 */
function computePointY(pt, chartType) {
  switch (chartType) {
    case "p":
      // Proportion: y/n
      return pt.n ? pt.y / pt.n : pt.y;
    case "u":
      // Rate: y/n
      return pt.n ? pt.y / pt.n : pt.y;
    case "mr":
      // Moving range returnerer den rå y-værdi (MR beregnes separat)
      return pt.y;
    default:
      return pt.y;
  }
}

/**
 * Beregn array af y-værdier for en gruppe punkter
 */
function computeChartY(points, chartType) {
  return points.map(d => computePointY(d, chartType));
}


// ============================================================================
// ANHØJ-REGLER
// Ref: Anhøj J. "Diagnostic value of run chart analysis" (2014)
// ============================================================================

/**
 * Beregn Anhøj rules statistik
 */
export function computeAnhoejRules(yValues, cl) {
  if (yValues.length < 2) {
    return {
      longestRun: 0,
      expectedLongestRun: 0,
      crossings: 0,
      expectedMinCrossings: 0,
      runsSignal: false,
      crossingsSignal: false,
      signal: false
    };
  }

  // Fjern værdier der ligger præcist på centerlinjen
  const useful = yValues.filter(v => v !== cl);
  const n = useful.length;

  if (n < 2) {
    return {
      longestRun: 0,
      expectedLongestRun: 0,
      crossings: 0,
      expectedMinCrossings: 0,
      runsSignal: false,
      crossingsSignal: false,
      signal: false
    };
  }

  // Bestem om hvert punkt er over/under CL
  const above = useful.map(v => v > cl);

  // Longest run: længste serie af consecutive TRUE eller FALSE
  const longestRun = computeLongestRun(above);

  // Antal krydsninger: antal skift mellem over/under
  const crossings = computeCrossings(above);

  // Forventede værdier (Anhøj, 2014)
  // Forventet longest run ≈ log2(n) + 3 (konservativ grænse)
  const expectedLongestRun = Math.round(Math.log2(n) + 3);

  // Forventet minimum krydsninger (lower prediction limit)
  // Baseret på binomial fordeling: E(crossings) = (n-1)/2
  // Nedre grænse ≈ (n-1)/2 - 3*sqrt((n-1)/4)
  // Simplificeret: qicharts2 bruger en tabel, vi bruger tilnærmelsen
  const expectedMinCrossings = Math.max(0,
    Math.round((n - 1) / 2 - 3 * Math.sqrt((n - 1) / 4))
  );

  const runsSignal = longestRun > expectedLongestRun;
  const crossingsSignal = crossings < expectedMinCrossings;

  return {
    longestRun,
    expectedLongestRun,
    crossings,
    expectedMinCrossings,
    runsSignal,
    crossingsSignal,
    signal: runsSignal || crossingsSignal
  };
}

/**
 * Beregn longest run (consecutive TRUE eller FALSE)
 */
function computeLongestRun(above) {
  let maxRun = 1;
  let currentRun = 1;

  for (let i = 1; i < above.length; i++) {
    if (above[i] === above[i - 1]) {
      currentRun++;
    } else {
      currentRun = 1;
    }
    if (currentRun > maxRun) maxRun = currentRun;
  }

  return maxRun;
}

/**
 * Tæl antal krydsninger af centerlinjen
 */
function computeCrossings(above) {
  let count = 0;
  for (let i = 1; i < above.length; i++) {
    if (above[i] !== above[i - 1]) count++;
  }
  return count;
}


// ============================================================================
// MOVING RANGE
// ============================================================================

/**
 * Beregn moving ranges (absolute forskel mellem consecutive værdier)
 */
function movingRanges(values) {
  const mr = [];
  for (let i = 1; i < values.length; i++) {
    mr.push(Math.abs(values[i] - values[i - 1]));
  }
  return mr;
}


// ============================================================================
// STATISTISKE KONSTANTER
// ============================================================================

// d2 for subgroup size n=2 (brugt i I-chart sigma estimation)
const D2 = 1.128;

// D3 og D4 for subgroup size n=2 (brugt i MR-chart)
const D3 = 0;      // Nedre grænse-faktor (0 for n=2)
const D4 = 3.267;  // Øvre grænse-faktor


// ============================================================================
// HJÆLPEFUNKTIONER
// ============================================================================

function mean(arr) {
  if (arr.length === 0) return 0;
  return arr.reduce((sum, v) => sum + v, 0) / arr.length;
}

function median(arr) {
  if (arr.length === 0) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid];
}
