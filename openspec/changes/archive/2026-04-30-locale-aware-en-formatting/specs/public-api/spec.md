## MODIFIED Requirements

### Requirement: bfh_qic language parameter SHALL govern both labels and number/date formatting

The `language` parameter on `bfh_qic()` (default `"da"`, supported values `"da"`, `"en"`) SHALL control:

1. **Translated labels** (existing behavior) — text from `inst/i18n/*.yaml` resolved via `i18n_lookup()`
2. **Y-axis number formatting** (new) — count breaks use locale-appropriate decimal and thousand separators
3. **X-axis date formatting** (new) — month/weekday abbreviations and date layout match the requested locale

**Locale-specific formatting contract:**

| Aspect | `language = "da"` | `language = "en"` |
|---|---|---|
| Decimal separator | `,` | `.` |
| Thousand separator | `.` | `,` |
| Month abbreviations (Jan-Dec) | `jan`, `feb`, `mar`, ... `okt`, `nov`, `dec` | `Jan`, `Feb`, ... `Oct`, `Nov`, `Dec` |
| Weekday abbreviations | `man`, `tir`, `ons`, `tor`, `fre`, `lør`, `søn` | `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun` |
| Percent format | `12,5 %` | `12.5%` |

**Rationale:**
- Engelske brugere så tidligere `1.000,5` på y-aksen — formelt forkert engelsk talnotation
- I grænsetilfælde misfortolkes `1.000` som ét (ikke ét tusind), hvilket er klinisk relevant for tællinger
- Pakken dokumenterer allerede engelsk-sprog-support; formatering skal følge med
- Default `"da"` bevarer eksisterende output bit-for-bit for danske brugere

#### Scenario: English count y-axis uses comma thousand separator

- **GIVEN** `data` with y-values producing breaks at 1000, 2000, 3000
- **WHEN** `bfh_qic(data, x, y, language = "en")` is called
- **THEN** the y-axis labels SHALL be `"1,000"`, `"2,000"`, `"3,000"`
- **AND** NOT `"1.000"`, `"2.000"`, `"3.000"` (Danish form)

#### Scenario: Danish count y-axis unchanged

- **GIVEN** the same data
- **WHEN** `bfh_qic(data, x, y, language = "da")` (or default) is called
- **THEN** the y-axis labels SHALL be `"1.000"`, `"2.000"`, `"3.000"`

#### Scenario: English monthly x-axis uses English abbreviations

- **GIVEN** monthly data spanning Jan–Dec
- **WHEN** `bfh_qic(... language = "en")` is called
- **THEN** the x-axis SHALL show `"Jan"`, `"Feb"`, ... `"Dec"`
- **AND** NOT `"jan"`, `"feb"`, ... `"dec"` (Danish form)

#### Scenario: Percent formatting respects language

- **GIVEN** a p-chart with proportions 0.10, 0.125, 0.15
- **WHEN** `bfh_qic(... chart_type = "p", language = "en")` is called
- **THEN** the y-axis SHALL show `"10%"`, `"12.5%"`, `"15%"`
- **WHEN** `language = "da"` is used
- **THEN** the y-axis SHALL show `"10 %"`, `"12,5 %"`, `"15 %"`
