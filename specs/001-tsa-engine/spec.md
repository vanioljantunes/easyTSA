# Feature Specification: TSA Software as Calculation Engine

**Feature Branch**: `001-tsa-engine`

**Created**: 2026-09-09

**Status**: Draft

**Input**: User description: "This package is not supposed to replicate the code inside the software, but to use the software as a dependency, run the stats there, and just take back the results. Users run meta-analyses with the meta package; easyTSA should make it easy to run a Trial Sequential Analysis on that output with the Copenhagen Trial Unit TSA software, and adjust the plot in R."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run a TSA on a meta object through the TSA software (Priority: P1)

A researcher has a pairwise meta-analysis object from the meta package (binary outcome, e.g. antibiotics vs none for PEECS). They call one function with that object and a few analysis choices (anticipated effect, power, heterogeneity correction). The package hands the trials and settings to the installed TSA program, lets the program perform every statistical calculation (required information size, cumulative Z-curve, monitoring boundaries, futility boundaries, adjusted confidence interval, conclusion), and returns those results to R as a tidy object. No statistic in the result is computed by the package itself.

**Why this priority**: This is the reason the package exists. The program is the validated, citable reference; reviewers and journals accept its output. A reimplementation in R would need its own validation and would still be "not TSA".

**Independent Test**: With the TSA program installed, run the function on the bundled example data and compare every number in the returned object with the same analysis performed by hand in the program's interface (same file, same boundary settings). All numbers must be identical.

**Acceptance Scenarios**:

1. **Given** a meta object with 7 trials and the program installed, **When** the user runs the analysis with default choices, **Then** the returned object holds, per trial in program order, the cumulative sample size, information fraction, cumulative Z value, monitoring boundary value and futility boundary value exactly as the program reports them, plus the program's required information size, its estimated anticipated effect, its heterogeneity estimate and its conclusion.
2. **Given** the same meta object, **When** the user supplies an anticipated relative risk reduction, a control-arm risk, power and a heterogeneity correction choice ("estimated by the program" or a user value), **Then** the program is run with exactly those settings and the returned object echoes them back.
3. **Given** the program is not installed or cannot be found, **When** the user runs the analysis, **Then** the function stops with a message that names where to download the program and how to tell the package where it is, and no partial numbers are returned.

---

### User Story 2 - Plot and adjust the TSA graph in R (Priority: P2)

Having the program's results in R, the researcher draws the classic TSA graph (Z-curve, boundaries, inner wedge, conventional limits, required information size line) and adjusts it for a manuscript: title, axis labels, colours, study labels, which layers to show, size for export.

**Why this priority**: Manuscript-quality figures are the second most requested output; the program's own graph is hard to restyle and export at journal resolution.

**Independent Test**: From a stored result object (no program needed), produce the graph, change three appearance options and save it at 300 dpi; the plotted points must match the numbers in the result object.

**Acceptance Scenarios**:

1. **Given** a result object, **When** the user calls the plot function with no options, **Then** a graph in the program's layout is produced from the program's numbers.
2. **Given** a result object, **When** the user changes title, labels, colours or hides the inner wedge, **Then** the graph reflects the change and the underlying numbers are unchanged.

---

### User Story 3 - Read the analysis in R and in the program interchangeably (Priority: P3)

The researcher wants to open the same analysis in the program's interface (to explore, to screenshot, or to hand to a co-author) and to bring a file saved by the program back into R.

**Why this priority**: Keeps the workflow transparent and reviewable; collaborators without R can inspect the exact analysis.

**Independent Test**: Write the analysis file from R, open it in the program, verify trials and boundary settings match; save from the program, read it back in R, verify trial data match.

**Acceptance Scenarios**:

1. **Given** a meta object and settings, **When** the user asks for the program file, **Then** a file is written that the program opens without edits and that contains the same trials and boundary settings.
2. **Given** a file saved by the program, **When** the user reads it in R, **Then** the trials and meta-analysis settings are returned as a data frame ready for the meta package.

---

### Edge Cases

- A trial has zero events in one arm: the program's own continuity handling is used; the returned Z values must match the program, not any R correction.
- The accumulated sample size exceeds the required information size: results for looks beyond the size are returned as the program reports them (conventional boundary), with the conclusion the program gives.
- Two trials share a publication year: trial order must be the program's (year, then alphabetical), and cumulative values must follow that order.
- Continuous outcomes (mean difference): supported only if the program computes them through the non-interactive path; otherwise the function refuses clearly.
- The program is installed but Java is missing, or the program version differs from the one the package was built against: a clear message, no silent fallback to R-side arithmetic.
- The program produces no result (invalid settings, e.g. anticipated effect of zero): the program's error text is surfaced to the user.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The package MUST accept a meta-analysis object from the meta package (binary outcomes at minimum) as its input.
- **FR-002**: The package MUST let the user set the anticipated effect (relative risk reduction or arm risks, or "estimate from the data"), type I error, power, information axis and heterogeneity correction ("estimated by the program" or a user value), with defaults equal to the program's defaults.
- **FR-003**: All statistics in the result (required information size, cumulative Z values, monitoring boundaries, futility boundaries, adjusted confidence intervals, heterogeneity estimate, anticipated effect when estimated, conclusion) MUST be produced by the TSA program. The package MUST NOT compute any of these itself.
- **FR-004**: The package MUST return the program's results as a structured R object with one row per look and the analysis settings attached.
- **FR-005**: The package MUST locate a user-installed copy of the program through a documented setting, and MUST refuse to run with an actionable message when the program or its runtime is absent. The program MUST NOT be redistributed with the package (its license forbids it).
- **FR-006**: The package MUST draw the TSA graph from the result object and allow appearance changes (title, axis labels, colours, layer visibility, study labels) without changing the numbers.
- **FR-007**: The package MUST write analysis files the program opens unchanged and read files the program saves.
- **FR-008**: The package MUST document, for every default, which program option it corresponds to.
- **FR-009**: Existing R-side implementations of the statistics MUST be removed from the public workflow so that no user can obtain non-program numbers by accident.

### Key Entities

- **Analysis request**: a meta object plus user choices (anticipated effect, error levels, information axis, heterogeneity correction, labels).
- **Program run**: one execution of the TSA program on one analysis request; has a location of the program, a status, and raw program output.
- **TSA result**: per-look table (study, year, cumulative N, information fraction, Z, boundaries), summary values (required information size, anticipated effect used, heterogeneity, adjusted CI, conclusion), and the settings that produced it.
- **Analysis file**: the program's own file format for trials and boundaries; exchanged in both directions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the bundled example and on the program's own sample analysis, 100% of returned numbers equal the values shown in the program's interface for the same settings (to the precision the program displays).
- **SC-002**: A user with the program installed goes from a fitted meta object to a TSA result and a publication-ready graph in at most 3 function calls and under 1 minute of wall time.
- **SC-003**: A user without the program receives an actionable error on the first call, and 0 numbers are returned in that case.
- **SC-004**: A collaborator can open the file produced by the package in the program and see the same trials and boundary settings with no manual edits.
- **SC-005**: No statistical routine remains in the package's public functions that duplicates a program calculation (verified by code review against FR-003 and FR-009).

## Assumptions

- The TSA program (Copenhagen Trial Unit, version 0.9.5.10 Beta) is installed by the user, together with a Java runtime, and its location is provided once through a setting; the package never bundles it.
- The program can be driven without its graphical interface (its calculation and report components can be invoked directly from R) for the analyses in scope. If a calculation is only reachable through the interface, that analysis is out of scope until a non-interactive path exists.
- Binary outcomes with relative risk, odds ratio or risk difference are in scope for the first release; continuous outcomes follow only if the program path supports them.
- Trial order, continuity correction and random-effects model are the program's; the meta object supplies trial data and labels, not estimates.
- The bundled example dataset remains the seven-study antibiotics vs none PEECS meta-analysis.
- The current R-side statistical functions become internal test oracles only or are removed; they are no longer part of the documented workflow.
