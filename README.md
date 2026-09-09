# easyTSA

**Trial Sequential Analysis for `meta` objects, computed by the TSA program itself.**

---

## 1. What is this package

`easyTSA` runs a Trial Sequential Analysis (TSA) on a meta-analysis you
fitted with the [`meta`](https://cran.r-project.org/package=meta)
package. It does not reimplement the statistics. It writes your trials to
the Copenhagen Trial Unit TSA program's own file, runs that program's
calculation engine inside R (headless, through `rJava`), and brings the
program's numbers back: required information size, cumulative Z-curve,
monitoring boundaries, inner wedge, heterogeneity, conclusion. Then it
draws the TSA graph with `ggplot2` so you can restyle it for a manuscript.

**What you get:**

- **`tsa_run()`** - `metabin` object in, TSA program results out.
- **`tsa_plot()`** - the TSA graph as a `ggplot` (title, labels, colours,
  layers all adjustable).
- **`summary()`** - per-look table and boundary-adjusted CI.
- **`tsa_request()` / `tsa_write()` / `tsa_read()`** - build and exchange
  `.TSA` files (open them in the program's interface, read the program's
  files back).
- **`tsa_engine()` / `tsa_jar()` / `tsa_launch()`** - locate, start and
  open the program.

---

## 2. Install

```r
# install.packages("remotes")
remotes::install_github("vanioljantunes/easyTSA")
```

Then, once per machine:

1. Install a Java runtime (8 or later), e.g. from <https://adoptium.net>.
2. Download the TSA program from <https://ctu.dk/tsa/> and unzip it. It is
   free to use but its license forbids redistribution, so it is not
   bundled.
3. Tell R where it is (put this in your `.Rprofile`):

```r
Sys.setenv(TSA_HOME = "C:/Users/me/TSA 0.9.5.10 Beta")   # folder containing TSA.jar
```

---

## 3. Worked example: prophylactic antibiotics and PEECS after ESD

```r
library(meta)
library(easyTSA)

m <- metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
             studlab = paste(author, year), sm = "RR")

x <- tsa_run(m, label.e = "ATB", label.c = "No ATB",
             title = "Prophylactic antibiotics and PEECS after ESD")
x
summary(x)                 # per-look table: N, IF, Z, boundary, futility
tsa_plot(x, show_labels = TRUE)
```

![TSA plot](man/figures/tsa_peecs.png)

Defaults are the program's defaults: two-sided 5% conventional boundary,
O'Brien-Fleming alpha-spending boundary on the sample-size axis, 80%
power, anticipated effect "Estimate", heterogeneity correction "Model
Variance Based", inner wedge on.

Clinically chosen effect instead of the empirical one:

```r
tsa_run(m, control = 0.12, rrr = 0.30)
tsa_run(m, control = 0.12, rrr = 0.30, diversity = 0.5)   # user-defined D2
```

---

## 4. Verified against the program's interface

For the bundled example with a user-defined effect (control 28.17%,
intervention 19.16%) and user D² 35.62%, `tsa_run()` returns what the
program's own window shows:

| Look | N | IF | Z | Boundary |
|---|---|---|---|---|
| Lee 2017 | 100 | 0.092 | 4.159 | 7.293 |
| Hastier 2022 | 326 | 0.300 | 0.029 | 3.909 |
| Shichijo 2022 | 706 | 0.650 | 0.637 | 2.544 |
| Liao 2024 | 1258 | 1.159 | 1.356 | 1.96 |
| Qiu 2024 | 1813 | 1.670 | 0.843 | 1.96 |
| Chen 2025 | 1894 | 1.744 | 1.474 | 1.96 |
| Zhao 2025 | 2156 | 1.986 | 1.634 | 1.96 |

RIS 1086, D² (model variance based) 56.76%, pooled RR 0.735. These are
the package's test cases (run when `TSA_HOME` is set).

---

## 5. Customising the plot

```r
tsa_plot(x,
  title = "PEECS", subtitle = NULL,
  show_futility = FALSE, show_conventional = FALSE,
  show_labels = TRUE, show_favours = FALSE,
  ris_label = "RIS (D2-adjusted)",
  col_z = "black", col_bound = "firebrick",
  ylim = c(-6, 6)) +
  ggplot2::theme_classic()

ggplot2::ggsave("tsa.png", tsa_plot(x), width = 9, height = 5.5, dpi = 300)
```

---

## 6. Files and the program's interface

```r
tsa_write(x, "peecs.TSA")     # the file the engine used; File > Open in the program
tsa_launch(x)                 # writes the file and starts the program's window
d <- tsa_read("peecs.TSA")    # trials from a program file back into R
```

`tsa_request()` builds the request (and `tsa_write()` the file) without
the program installed, e.g. to hand a file to a co-author.

---

## 7. Documentation

```r
?easyTSA
?"easyTSA-1-workflow"    # setup and the three calls
?"easyTSA-2-results"     # what comes back, argument to program option
?"easyTSA-3-plot"        # plot options
?"easyTSA-4-software"    # the program and the engine
```

## 8. License

MIT for this package. The TSA program and its manual are copyright
Copenhagen Trial Unit and are not part of this package.
