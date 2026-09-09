# Contract: easyTSA public R API (feature 001)

Exported functions after this feature. Anything not listed is internal.

## `tsa_run(m, rrr = NULL, control = NULL, intervention = NULL, alpha = 0.05, beta = 0.20, diversity = "estimate", futility = TRUE, information_axis = "sample", model = "random_dl", outcome = "negative", label.e = NULL, label.c = NULL, title = NULL, file = NULL, keep_file = !is.null(file))`

- Input: `metabin` object and settings (see data-model, Analysis request).
- Effect: writes the Analysis file (temp unless `file` given), starts or reuses the JVM, loads the file in the program, runs its calculations, extracts results.
- Returns: `easytsa` object (data-model, TSA result). Every statistic comes from the program.
- Errors (all before any result is built):
  - program not found: message names `TSA_HOME` / `options(easyTSA.jar)` and https://ctu.dk/tsa/
  - JVM not available: message names Java and https://adoptium.net
  - program calculation failure: the Java exception message, prefixed "TSA program:"
  - unsupported input (`metacont`, unsupported `sm`): message states what is supported
- `tsa_create()` is kept as an alias of `tsa_run()` for one release, with a deprecation note.

## `print(x)`, `summary(x)` for `easytsa`

- `print`: title, arms, model, trials, participants, anticipated effect (source: "estimated by TSA" or "user"), alpha/power, D² and factor, RIS, IF, last Z and boundary, conclusion.
- `summary`: per-look table (Look, Study, Year, N, IF, Z, Boundary, Futility) and adjusted CI table. Values printed are the program's, rounded only for display.

## `tsa_plot(x, ...)`

- Unchanged signature (title, subtitle, xlab, ylab, show_futility, show_conventional, show_labels, show_favours, ris_label, colours, ylim, sizes, x_pad).
- Draws exclusively from `x$looks`, `x$bounds`, `x$ris`, `x$settings`. Returns a `ggplot`.
- Works without the program (stored `easytsa` objects).

## `tsa_write(x_or_request, file, ...)`, `tsa_read(file)`

- `tsa_write` accepts an `easytsa` object or the arguments of `tsa_run()` and writes the program file. Boundary defaults: conventional 5% two-sided; alpha-spending O'Brien-Fleming, sample-size axis, power from `beta`, effect user-defined percent values or "estimate", heterogeneity "Model Variance Based" unless `diversity` is numeric.
- `tsa_read` unchanged: trials data frame plus `settings` attribute.

## `tsa_jar(jar = NULL)`, `tsa_launch(x, ...)`, `tsa_engine(jar = NULL, restart = FALSE)`

- `tsa_jar`: resolve program location; `""` when absent.
- `tsa_launch`: unchanged (starts the GUI on a file).
- `tsa_engine`: start or reuse the headless JVM with the jar; returns an environment with `io`, `jar`, `java_version`, `tsa_version`. Exported so users can pre-warm or diagnose.

## Removed from the public API

`tsa_ris()`, `tsa_diversity()`, `tsa_bounds()`, `tsa_futility()`, `tsa_spending()` (R reimplementations). Their code moves to `tests/testthat/helper-oracle.R`.

## Datasets

`atb_peecs` unchanged. New `inst/extdata/atb_peecs_result.rds`: an `easytsa` object produced by the program, used by examples and tests when the program is absent.

## Golden values (program, bundled example, D² user 35.62%, RRR 31.98%)

| Look | n_cum | IF | Z | Boundary |
|---|---|---|---|---|
| 1 Lee SP 2017 | 100 | 0.0921 | 4.1589 | 7.2927 |
| 2 Hastier-De Chelle A 2022 | 326 | 0.3003 | 0.0294 | 3.9086 |
| 3 Shichijo S 2022 | 706 | 0.6502 | 0.6366 | 2.5440 |
| 4 Liao F 2024 | 1258 | 1.1587 | 1.3564 | 1.96 |
| 5 Qiu J 2024 | 1813 | 1.6698 | 0.8429 | 1.96 |
| 6 Chen T 2025 | 1894 | 1.7444 | 1.4737 | 1.96 |
| 7 Zhao YR 2025 | 2156 | 1.9857 | 1.6337 | 1.96 |

RIS 1085.741; model-variance D² 0.56756; pooled RR 0.7355; final Z 1.6337. Inner-wedge golden values to be captured once the drift argument is settled (research R2).
