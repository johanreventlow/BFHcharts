// BFHcharts Observable JS Utilities
// Farver, dato-parsing og hjælpefunktioner

/**
 * Default BFH farvepalette (fallback hvis ikke sendt fra R)
 */
export const defaultColors = {
  hospital_blue: "#007DBB",
  hospital_grey: "#888888",
  hospital_dark_grey: "#565656",
  light_blue: "#009CE8",
  very_light_blue: "#E1EDFB"
};

/**
 * Parse dato-værdier fra R (ISO-strings eller epoch)
 */
export function parseDate(value) {
  if (value instanceof Date) return value;
  if (typeof value === "number") return new Date(value);
  if (typeof value === "string") return new Date(value);
  return null;
}

/**
 * Forbered SPC data til plotting
 * Konverterer datoer, håndterer null/NA, sætter farver
 */
export function prepareData(spcData) {
  const colors = spcData.colors || defaultColors;
  const config = spcData.config || {};

  const points = (Array.isArray(spcData.data) ? spcData.data : toRowArray(spcData.data))
    .map(d => ({
      x: parseDate(d.x),
      y: d.y,
      cl: isNullish(d.cl) ? null : d.cl,
      ucl: isNullish(d.ucl) ? null : d.ucl,
      lcl: isNullish(d.lcl) ? null : d.lcl,
      target: isNullish(d.target) ? null : d.target,
      part: d.part,
      sigma_signal: Boolean(d.sigma_signal),
      anhoej_signal: Boolean(d.anhoej_signal),
      notes: isNullish(d.notes) ? null : String(d.notes)
    }))
    .filter(d => d.x !== null && d.y !== null && !isNaN(d.y));

  return { points, config, colors };
}

/**
 * Convert column-oriented data (from ojs_define) to row-oriented array
 */
function toRowArray(data) {
  if (!data || !data.x) return [];
  const n = data.x.length;
  const rows = [];
  for (let i = 0; i < n; i++) {
    rows.push({
      x: data.x[i],
      y: data.y[i],
      cl: data.cl ? data.cl[i] : null,
      ucl: data.ucl ? data.ucl[i] : null,
      lcl: data.lcl ? data.lcl[i] : null,
      target: data.target ? data.target[i] : null,
      part: data.part ? data.part[i] : 1,
      sigma_signal: data.sigma_signal ? data.sigma_signal[i] : false,
      anhoej_signal: data.anhoej_signal ? data.anhoej_signal[i] : false,
      notes: data.notes ? data.notes[i] : null
    });
  }
  return rows;
}

function isNullish(val) {
  return val === null || val === undefined || val === "NA" || val === "NULL" ||
    (typeof val === "number" && isNaN(val));
}
