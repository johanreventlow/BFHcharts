## ADDED Requirements

### Requirement: Internal config constructors SHALL fail loudly on invalid input

Internal configuration constructors (`spc_plot_config()`, `viewport_dims()`, and related builders in `R/config_objects.R`) SHALL raise informative errors on invalid input rather than silently coercing or emitting warnings and continuing.

**Rationale:**
- Silent coercion creates latent bugs surfaced far from the root cause
- Internal contracts should fail fast; user-facing APIs (`bfh_qic()`) wrap
  with documented graceful handling where appropriate

**Invalid input categories (SHALL error):**
- Wrong type (e.g. character where numeric required)
- NA, Inf, or negative numeric where a positive dimension is required
- Unknown option keys when the constructor has a fixed key set

#### Scenario: Wrong type raises error

**Given** `spc_plot_config()` expects numeric width
**When** called with `width = "big"`
**Then** it SHALL raise an error identifying the invalid parameter and its expected type

```r
expect_error(
  spc_plot_config(width = "big"),
  "width"
)
```

#### Scenario: Negative dimensions rejected

**Given** `viewport_dims()` expects positive dimensions
**When** called with `width_mm = -10`
**Then** it SHALL raise an error

```r
expect_error(
  viewport_dims(width_mm = -10, height_mm = 100),
  "positive"
)
```

#### Scenario: NULL uses documented default

**Given** a constructor with documented NULL-as-default behavior
**When** called with an argument set to `NULL`
**Then** it SHALL return the default value without error
**And** this SHALL be the only legitimate silent path
