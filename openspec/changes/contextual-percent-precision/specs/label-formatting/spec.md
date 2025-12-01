# Label Formatting Specification

## ADDED Requirements

### Requirement: Contextual centerline precision
Centerline labels for percent data MUST show one decimal place when the centerline value is within 5 percentage points of the target value.

#### Scenario: Centerline close to target shows decimal
- **Given** a percent chart with target = 0.90 (90%)
- **When** the centerline value is 0.887
- **Then** the centerline label displays "88,7%"

#### Scenario: Centerline far from target shows whole percent
- **Given** a percent chart with target = 0.90 (90%)
- **When** the centerline value is 0.634
- **Then** the centerline label displays "63%"

#### Scenario: No target uses whole percent
- **Given** a percent chart with no target set
- **When** the centerline value is 0.887
- **Then** the centerline label displays "89%"

#### Scenario: Exact boundary at 5 percentage points
- **Given** a percent chart with target = 0.90 (90%)
- **When** the centerline value is 0.85 (exactly 5 points away)
- **Then** the centerline label displays "85,0%"

---

### Requirement: Range-aware y-axis precision
Y-axis ticks for percent data MUST show one decimal place when the y-axis range spans less than 5 percentage points.

#### Scenario: Narrow range shows decimals
- **Given** a percent chart with y-axis range 0.98 to 1.00
- **When** y-axis ticks are generated
- **Then** ticks display with one decimal (e.g., "98,5%", "99,0%", "99,5%")

#### Scenario: Wide range shows whole percents
- **Given** a percent chart with y-axis range 0.00 to 1.00
- **When** y-axis ticks are generated
- **Then** ticks display as whole percentages (e.g., "0%", "25%", "50%")

#### Scenario: Boundary at 5 percentage points
- **Given** a percent chart with y-axis range spanning exactly 0.05 (5 points)
- **When** y-axis ticks are generated
- **Then** ticks display as whole percentages (threshold is exclusive)

---

### Requirement: Danish decimal notation
All percent labels with decimals MUST use Danish notation with comma as decimal separator.

#### Scenario: Decimal uses comma separator
- **Given** a percent value 0.887 requiring decimal display
- **When** formatted for display
- **Then** the output is "88,7%" (not "88.7%")

---

## MODIFIED Requirements

### Requirement: format_y_value percent handling
The `format_y_value()` function MUST accept optional `target` parameter for contextual precision.

#### Scenario: With target parameter
- **Given** `format_y_value(0.887, "percent", target = 0.90)`
- **When** the function executes
- **Then** returns "88,7%" (within 5 points of target)

#### Scenario: Without target parameter (backward compatible)
- **Given** `format_y_value(0.887, "percent")`
- **When** the function executes
- **Then** returns "89%" (current behavior preserved)
