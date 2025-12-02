# X-Axis Formatting API Specification

**Parent:** `refactor-x-axis-formatting`
**Status:** PROPOSED

## Overview

Refactor the 158-line `apply_x_axis_formatting()` function into smaller, testable units following Single Responsibility Principle.

---

## ADDED Requirements

### Requirement: Main Dispatcher Function

The main `apply_x_axis_formatting()` function SHALL dispatch to specialized formatters based on x-column type. Main function MUST be ≤ 15 lines.

#### Scenario: Temporal data dispatch

**Given** a ggplot object with Date/POSIXct x-axis data
**When** `apply_x_axis_formatting()` is called
**Then** it dispatches to `apply_temporal_x_axis()`

#### Scenario: Numeric data dispatch

**Given** a ggplot object with numeric x-axis data
**When** `apply_x_axis_formatting()` is called
**Then** it dispatches to `apply_numeric_x_axis()`

---

### Requirement: Temporal Axis Formatter

The `apply_temporal_x_axis()` function SHALL handle all temporal x-axis formatting. Function MUST be ≤ 40 lines with max 2 nesting levels.

#### Scenario: Date input formatting

**Given** temporal x-axis data (Date, POSIXct, POSIXt)
**When** `apply_temporal_x_axis()` is called
**Then** it returns a ggplot with properly formatted datetime scale using interval detection and smart labels

---

### Requirement: Numeric Axis Formatter

The `apply_numeric_x_axis()` function SHALL handle numeric x-axis formatting. Function MUST be ≤ 10 lines.

#### Scenario: Numeric sequence formatting

**Given** numeric x-axis data (observation numbers)
**When** `apply_numeric_x_axis()` is called
**Then** it returns a ggplot with pretty breaks (n=8)

---

### Requirement: Date Break Calculator

The `calculate_date_breaks()` function SHALL compute optimal break points for date axes. Function MUST be ≤ 50 lines with unit tests for each interval type.

#### Scenario: Monthly data breaks

**Given** monthly data spanning 24 months
**When** `calculate_date_breaks()` is called
**Then** it returns ≤ 15 POSIXct break points

#### Scenario: Weekly data breaks

**Given** weekly data spanning 52 weeks
**When** `calculate_date_breaks()` is called
**Then** it returns ≤ 15 POSIXct break points with appropriate multiplier

#### Scenario: Daily data breaks

**Given** daily data spanning 60 days
**When** `calculate_date_breaks()` is called
**Then** it returns ≤ 15 POSIXct break points

---

### Requirement: POSIXct Normalization

The `normalize_to_posixct()` function SHALL convert Date to POSIXct. Function MUST be ≤ 10 lines.

#### Scenario: Date conversion

**Given** a Date object "2024-01-15"
**When** `normalize_to_posixct()` is called
**Then** it returns POSIXct "2024-01-15 00:00:00"

#### Scenario: POSIXct passthrough

**Given** a POSIXct object
**When** `normalize_to_posixct()` is called
**Then** it returns the same POSIXct unchanged

---

### Requirement: Interval Rounding Helper

The `round_to_interval_start()` function SHALL floor dates to interval boundaries. Function MUST be ≤ 15 lines.

#### Scenario: Monthly rounding

**Given** a date "2024-01-15" and interval type "monthly"
**When** `round_to_interval_start()` is called
**Then** it returns "2024-01-01"

#### Scenario: Weekly rounding

**Given** a date "2024-01-15" and interval type "weekly"
**When** `round_to_interval_start()` is called
**Then** it returns the start of that week

---

## MODIFIED Requirements

### Requirement: Behavioral Equivalence

All existing SPC charts MUST render identically before and after refactoring.

#### Scenario: Visual regression check

**Given** a set of existing SPC chart test cases
**When** the refactored code is executed
**Then** all charts match their baseline snapshots exactly

---

### Requirement: Code Metrics Improvement

The refactoring MUST achieve the following targets: main function ≤ 15 lines, max nesting ≤ 2, functions 5-6, test coverage ≥ 90%.

#### Scenario: Metric validation

**Given** the refactored codebase
**When** code metrics are measured
**Then** main function is ≤ 15 lines, max nesting is ≤ 2 levels, there are 5-6 functions, and test coverage is ≥ 90%

---

## File Changes

### Modified Files

- `R/plot_core.R` - Refactored `apply_x_axis_formatting()`

### New Files

- `R/utils_x_axis_formatting.R` - Extracted helper functions
- `tests/testthat/test-utils_x_axis_formatting.R` - Unit tests
