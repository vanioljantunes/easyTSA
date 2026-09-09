# Implementation Plan: TSA Software as Calculation Engine

**Branch**: `001-tsa-engine` | **Date**: 2026-09-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-tsa-engine/spec.md`

## Summary

Replace easyTSA's R-side statistics with calls into the user-installed Copenhagen Trial Unit TSA program (`TSA.jar`, version 0.9.5.10 Beta) through rJava. R writes the `.TSA` analysis file from a `meta` object, the jar loads it and computes required information size, cumulative Z-curve, monitoring boundaries, inner wedge, heterogeneity and pooled estimate; R reads those numbers back into an `easytsa` object and plots them. Research (see [research.md](research.md)) proved the jar exposes a complete non-GUI calculation path and that its numbers match the program's interface exactly on the bundled example.

## Technical Context

**Language/Version**: R >= 4.1 (developed on 4.6.0); Java runtime 8 or later for the jar (Java 8 JRE verified)

**Primary Dependencies**: `meta` (input objects), `rJava` (bridge, Imports), `ggplot2` (plot). The TSA program is an external, user-installed dependency located via `TSA_HOME` or `options(easyTSA.jar)`; never bundled (license)

**Storage**: `.TSA` text files (program format) written to a temp dir or a user path; no database

**Testing**: testthat; engine tests skipped when the program is absent (`skip_if_no_tsa()`), so CRAN-style checks pass without it; golden values recorded from the program's interface

**Target Platform**: Windows, macOS, Linux desktops with R and a JVM

**Project Type**: R library

**Performance Goals**: one analysis of up to 50 trials in under 5 seconds after JVM start; JVM started once per session

**Constraints**: no redistribution of TSA files; no reimplementation of any statistic (FR-003); JVM initialised headless (`-Djava.awt.headless=true`); rJava requires a JVM matching R's architecture (64-bit)

**Scale/Scope**: single package, ~8 exported functions, one bundled dataset, binary outcomes first

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

No constitution file exists in this repository or the monorepo root. Gates applied from the spec instead:

- FR-003 / FR-009 (no R-side statistics in the public workflow): PASS after design. The R implementations of RIS, boundaries and futility move to `tests/testthat/helper-oracle.R` as cross-check oracles only and leave `NAMESPACE`.
- FR-005 (no bundling): PASS. `tsa_jar()` locates a user install; DESCRIPTION gains `SystemRequirements: Java (>= 8); TSA 0.9.5.10 Beta (https://ctu.dk/tsa/)`.
- License: reflection on public methods and calls through the public API are ordinary use; no decompilation, modification or redistribution occurs.

Post-design re-check: PASS (design keeps every statistic inside the jar; R only serialises inputs and parses outputs).

## Project Structure

### Documentation (this feature)

```text
specs/001-tsa-engine/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── r-api.md
└── tasks.md            # /speckit-tasks output, not created here
```

### Source Code (repository root)

```text
R/
├── engine.R          # NEW: tsa_engine() JVM start, jar location, class loading, error mapping
├── run.R             # NEW: tsa_run(): meta -> .TSA -> jar -> easytsa object
├── extract.R         # NEW: pull RIS, D2, Z-curve, boundaries, wedge from jar objects
├── write.R           # KEPT: tsa_write(), tsa_read() (file format, unchanged)
├── plot.R            # KEPT: tsa_plot() reads only $looks/$bounds produced by the program
├── launch.R          # KEPT: tsa_jar(), tsa_launch()
├── data.R            # KEPT: atb_peecs
├── guides.R          # REWRITTEN: workflow, program-option mapping, plot, program
├── easyTSA-package.R # UPDATED
├── tsa.R             # tsa_create() becomes a thin alias of tsa_run(); R maths removed
├── boundaries.R      # MOVED to tests/testthat/helper-oracle.R (internal oracle)
└── ris.R             # MOVED to tests/testthat/helper-oracle.R

tests/testthat/
├── helper-tsa.R          # skip_if_no_tsa(), engine fixture
├── helper-oracle.R       # former R-side maths, used only to sanity-check parsed output
├── test-write-read.R     # file round trip (no program needed)
├── test-engine.R         # program-backed: golden values from the interface
└── test-plot.R           # plot from a stored easytsa object (no program needed)

inst/extdata/
├── atb_peecs.TSA         # example file
└── atb_peecs_result.rds  # stored program result for plot/summary tests without the program
```

**Structure Decision**: single R package; a new engine layer (`engine.R`, `run.R`, `extract.R`) sits between the existing file writer and the existing plot. No statistics remain in `R/`.

## Complexity Tracking

No constitution violations. One accepted complexity: `rJava` as a hard Import makes installation depend on a JVM. The alternative (subprocess `java -jar` with a batch entry point) was rejected because the jar has no command-line mode; its batch class opens a Swing folder dialog.
