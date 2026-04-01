// BFHcharts Observable JS Y-Axis Scales
// Dansk talformatering porteret fra R/utils_number_formatting.R og R/utils_y_axis_formatting.R

/**
 * Opret en Y-akse formatter baseret på enhedstype og data
 *
 * @param {string} unit - Enhedstype: "percent", "count", "rate", "time"
 * @param {Array} data - Array af datapunkter med y-værdier (til kontekst)
 * @returns {function} Formatter: (value) => string
 */
export function createYAxisFormatter(unit, data) {
  switch (unit) {
    case "percent":
      return createPercentFormatter(data);
    case "count":
      return createCountFormatter();
    case "rate":
      return createRateFormatter();
    case "time":
      return createTimeFormatter(data);
    default:
      return createCountFormatter();
  }
}

// ============================================================================
// PERCENT FORMATTER
// ============================================================================

/**
 * Range-aware procent formatter med dansk decimaltegn
 * Porteret fra R/utils_y_axis_formatting.R linje 114-151
 */
function createPercentFormatter(data) {
  return function (value) {
    if (value === null || value === undefined || isNaN(value)) return "";

    // Procent-værdier fra R er 0-1, konverter til procentpoint
    const pct = value * 100;

    // Bestem præcision baseret på break-interval (estimeret fra data range)
    // Brug simpel heuristik: kig på data-spændet
    let decimals = 0;
    if (data && data.length >= 2) {
      const yValues = data.map(d => d.y).filter(v => v !== null && !isNaN(v));
      if (yValues.length >= 2) {
        const range = (Math.max(...yValues) - Math.min(...yValues)) * 100;
        if (range < 1) {
          decimals = 2;
        } else if (range < 10) {
          decimals = 1;
        } else {
          decimals = 0;
        }
      }
    }

    return formatDanishDecimal(pct, decimals) + "%";
  };
}

// ============================================================================
// COUNT FORMATTER
// ============================================================================

/**
 * Intelligent K/M/mia. notation med dansk formatering
 * Porteret fra R/utils_number_formatting.R linje 59-129
 */
function createCountFormatter() {
  return function (value) {
    if (value === null || value === undefined || isNaN(value)) return "";
    return formatCountDanish(value);
  };
}

/**
 * Format tælleværdi med K/M/mia. notation
 */
function formatCountDanish(val) {
  const absVal = Math.abs(val);

  if (absVal >= 1e9) {
    return formatScaledNumber(val, 1e9, " mia.");
  } else if (absVal >= 1e6) {
    return formatScaledNumber(val, 1e6, "M");
  } else if (absVal >= 1e3) {
    return formatScaledNumber(val, 1e3, "K");
  } else {
    return formatUnscaledNumber(val);
  }
}

/**
 * Format tal med skaleret suffix (K, M, mia.)
 * Porteret fra R/utils_number_formatting.R linje 59-72
 */
function formatScaledNumber(val, scale, suffix) {
  const scaled = val / scale;
  if (isEffectivelyInteger(scaled)) {
    return Math.round(scaled) + suffix;
  } else {
    return formatDanishDecimal(scaled, 1) + suffix;
  }
}

/**
 * Format tal uden skalering med dansk notation
 * Porteret fra R/utils_number_formatting.R linje 83-98
 */
function formatUnscaledNumber(val) {
  if (isEffectivelyInteger(val)) {
    return formatWithThousandSeparator(Math.round(val));
  } else if (Math.abs(val) < 1) {
    return formatDanishDecimal(val, 2);
  } else {
    return formatDanishDecimal(val, 1);
  }
}

// ============================================================================
// RATE FORMATTER
// ============================================================================

/**
 * Rate formatter med dansk decimaltegn
 * Porteret fra R/utils_number_formatting.R linje 141-156
 */
function createRateFormatter() {
  return function (value) {
    if (value === null || value === undefined || isNaN(value)) return "";
    return formatRateDanish(value);
  };
}

function formatRateDanish(val) {
  if (isEffectivelyInteger(val)) {
    return String(Math.round(val)).replace(".", ",");
  } else if (Math.abs(val) < 1) {
    return formatDanishDecimal(val, 2);
  } else {
    return formatDanishDecimal(val, 1);
  }
}

// ============================================================================
// TIME FORMATTER
// ============================================================================

/**
 * Tidsformatter med dansk enhedsbetegnelse
 * Porteret fra R/utils_time_formatting.R linje 24-129
 */
function createTimeFormatter(data) {
  // Bestem tidsenhed baseret på max-værdi (værdier antages i minutter)
  let maxMinutes = 0;
  if (data && data.length > 0) {
    const yValues = data.map(d => d.y).filter(v => v !== null && !isNaN(v));
    if (yValues.length > 0) {
      maxMinutes = Math.max(...yValues);
    }
  }

  const timeUnit = determineTimeUnit(maxMinutes);

  return function (value) {
    if (value === null || value === undefined || isNaN(value)) return "";
    return formatTimeDanish(value, timeUnit);
  };
}

/**
 * Bestem tidsenhed fra max-værdi
 * Porteret fra R/utils_time_formatting.R linje 24-32
 */
function determineTimeUnit(maxMinutes) {
  if (isNaN(maxMinutes) || maxMinutes < 60) {
    return "minutes";
  } else if (maxMinutes < 1440) {
    return "hours";
  } else {
    return "days";
  }
}

/**
 * Skalér tidsværdi til passende enhed
 */
function scaleToTimeUnit(valMinutes, timeUnit) {
  switch (timeUnit) {
    case "hours": return valMinutes / 60;
    case "days": return valMinutes / 1440;
    default: return valMinutes;
  }
}

/**
 * Hent dansk tidsenhedslabel med korrekt bøjning
 * Porteret fra R/utils_time_formatting.R linje 64-82
 */
function getDanishTimeLabel(timeUnit, value, isDecimal) {
  if (isDecimal) {
    // Decimaler bruger altid flertal (f.eks. "1,5 timer")
    switch (timeUnit) {
      case "minutes": return " minutter";
      case "hours": return " timer";
      case "days": return " dage";
      default: return " min";
    }
  }

  // Heltal: 1 = ental, ellers flertal
  switch (timeUnit) {
    case "minutes": return value === 1 ? " minut" : " minutter";
    case "hours": return value === 1 ? " time" : " timer";
    case "days": return value === 1 ? " dag" : " dage";
    default: return " min";
  }
}

/**
 * Format tidsværdi med dansk label
 * Porteret fra R/utils_time_formatting.R linje 104-129
 */
function formatTimeDanish(valMinutes, timeUnit) {
  const scaled = scaleToTimeUnit(valMinutes, timeUnit);

  if (isEffectivelyInteger(scaled)) {
    const rounded = Math.round(scaled);
    const label = getDanishTimeLabel(timeUnit, rounded, false);
    return rounded + label;
  } else {
    const label = getDanishTimeLabel(timeUnit, scaled, true);
    return formatDanishDecimal(scaled, 1) + label;
  }
}

// ============================================================================
// HJÆLPEFUNKTIONER
// ============================================================================

/**
 * Tjek om en værdi er effektivt et heltal (inden for floating-point tolerance)
 */
function isEffectivelyInteger(val) {
  return Math.abs(val - Math.round(val)) < 1e-10;
}

/**
 * Format tal med dansk decimaltegn (komma)
 */
function formatDanishDecimal(val, decimals) {
  return val.toFixed(decimals).replace(".", ",");
}

/**
 * Format heltal med punktum som tusindtalsseparator (dansk)
 */
function formatWithThousandSeparator(val) {
  const str = String(Math.abs(Math.round(val)));
  let result = "";
  for (let i = str.length - 1, count = 0; i >= 0; i--, count++) {
    if (count > 0 && count % 3 === 0) {
      result = "." + result;
    }
    result = str[i] + result;
  }
  return val < 0 ? "-" + result : result;
}
