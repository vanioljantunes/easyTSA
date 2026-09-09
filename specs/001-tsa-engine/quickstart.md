# Quickstart: validating the TSA engine bridge

## Prerequisites

- R >= 4.1 with `meta`, `rJava`, `ggplot2`, `testthat`, `devtools`.
- A Java runtime (8 or later) that rJava can find (`JAVA_HOME` or PATH).
- The TSA program unzipped somewhere, e.g. `C:\Users\me\TSA 0.9.5.10 Beta`, and `TSA_HOME` set to that folder (the one containing `TSA.jar` and `lib/`).

```r
Sys.setenv(TSA_HOME = "C:/Users/me/TSA 0.9.5.10 Beta")
devtools::install()   # from the package root
```

## Scenario 1: engine round trip on the bundled example (User Story 1)

```r
library(meta); library(easyTSA)
m <- metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
             studlab = paste(author, year), sm = "RR")
x <- tsa_run(m, label.e = "ATB", label.c = "No ATB")
x            # RIS, D2 (estimated by the program), conclusion
summary(x)   # per-look table
```

Expected: the per-look table equals the golden values in [contracts/r-api.md](contracts/r-api.md) when run with `rrr = 0.3198, control = 0.2817, diversity = 0.3562`; with defaults, RIS and D² equal what the program shows for "Estimate" and "Model Variance Based" on the same file.

## Scenario 2: program absent (User Story 1, error path)

```r
Sys.setenv(TSA_HOME = "")
options(easyTSA.jar = NULL)
tsa_run(m)
```

Expected: an error naming `TSA_HOME`, `options(easyTSA.jar)` and https://ctu.dk/tsa/; no object returned.

## Scenario 3: plot from a stored result (User Story 2, no program needed)

```r
x <- readRDS(system.file("extdata", "atb_peecs_result.rds", package = "easyTSA"))
p <- tsa_plot(x, show_labels = TRUE, col_z = "black")
ggplot2::ggsave("tsa.png", p, width = 9, height = 5.5, dpi = 300)
```

Expected: a PNG whose points equal `x$looks$z` and `x$looks$upper`.

## Scenario 4: file interchange (User Story 3)

```r
tsa_write(x, "peecs.TSA")      # open this in the program: File > Open
d <- tsa_read("peecs.TSA")     # back to R
```

Expected: the program opens the file unchanged and shows 7 trials and two boundaries; `d` has 7 rows with the same events and totals as `atb_peecs`.

## Test commands

```r
devtools::test()                     # engine tests skip when TSA_HOME is unset
Sys.setenv(TSA_HOME = "..."); devtools::test(filter = "engine")
R CMD build . && R CMD check --as-cran easyTSA_*.tar.gz
```

Expected: all tests pass; check clean apart from the standard note for a SystemRequirements entry.
