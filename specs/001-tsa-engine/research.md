# Research: TSA Software as Calculation Engine

All unknowns from the Technical Context were resolved by direct experiment on 2026-09-09 with TSA 0.9.5.10 Beta, Java 8 JRE (`C:\Program Files\Java\jre1.8.0_503`), R 4.6.0, rJava, using the bundled `atb_peecs.TSA` file whose results had just been displayed in the program's own interface.

## R1. Can the program be driven without its interface?

**Decision**: Yes, through rJava. Start a headless JVM with `TSA.jar` and its `lib/*.jar` on the classpath and call the program's public calculation classes directly.

**Rationale**: Verified end to end. `io.NewIO.loadMetaAnalysis(File)` returns a `data.MetaAnalysis`; `misc.BoundaryCalculations`, `data.LanDeMetsCalculus`, `misc.ProcLanDeMets` and `getZCurveGraphData()` deliver every number the interface shows, with `-Djava.awt.headless=true` and no window. Values obtained vs the interface:

| Quantity | Interface | Headless call |
|---|---|---|
| Required information size | 1085 | 1085.741 |
| Heterogeneity correction factor | (D² 35.62% user) 1.55 | 1.553277 |
| Model-variance D² | 56.76% | 0.5675598 |
| Boundary at looks 1-3 | ~7.3, ~3.9, ~2.55 | 7.2927, 3.9086, 2.544 |
| Z-curve at 100 / 326 / 706 / ... / 2156 patients | 4.2, 0.0, 0.6, 1.4, 0.8, 1.5, 1.6 (read off graph) | 4.1589, 0.0294, 0.6366, 1.3564, 0.8429, 1.4737, 1.6337 |
| Pooled RR, final Z | 0.74, 1.63 | 0.7355, 1.6337 |

**Alternatives considered**: (a) `java -jar` subprocess: `start.Run.main` ignores arguments, no CLI. (b) `batch.StartBatch`: opens a Swing folder chooser, GUI-bound. (c) GUI automation: fragile, blocked by anti-cheat drivers when games run, rejected. (d) Keep the R reimplementation: violates FR-003.

## R2. Which jar calls produce each result?

**Decision** (public API observed by reflection; argument meanings from the interface labels):

| Result | Call |
|---|---|
| Load analysis | `new io.NewIO().loadMetaAnalysis(java.io.File)` → `data.MetaAnalysis` |
| Trials in program order | `ma.getTrialArray()`; each `getYear()`, `getStudy()`, `getTrialSize()` |
| Pooled effect, Z, D², I², tau | `ma.getPooledEffect()`, `getZScore()`, `getDiversity()`, `getInconsistency()`, `getTau()` |
| Boundaries defined in file | `ma.getBoundaryArray()`; `getBoundarySort()` 1001 conventional, 1002 alpha-spending |
| RIS | `misc.BoundaryCalculations.getInformationSize(asb, ma)` (static) |
| Heterogeneity factor | `misc.BoundaryCalculations.getHeterogeneityCorrection(asb, ma)` |
| Information fractions | `misc.BoundaryCalculations.getTArray(sb, ma)` or `new data.LanDeMetsCalculus(ma, asb).calculateT()` |
| Monitoring boundary per look (IF < 1) | `LanDeMetsCalculus.getStandardBoundary(t)` → rows `[t, z]` |
| Z-curve points | `misc.BoundaryCalculations.setDiscreteZCurve(ma, t, ris)` then `ma.getZCurveGraphData().getGraphShapes()` → `getXCoord()` (cumulative patients), `getYCoord()` (Z, already oriented "favours intervention") |
| Anticipated effect used | `data.SequentialBoundaryDich.getControlEffect()`, `getInterventionEffect()` (percent) |
| Alpha, beta, sides | `data.AlphaSpendingBoundary.getAlpha()`, `getBeta()`, `getSide()` |

**Open detail (task-level)**: `misc.ProcLanDeMets.getInnerWedge(double[] t, double, BetaSpendingFunctionInterface, double, double, double)`. Called with `(t, 0.05, bsf, 0.20, 2, 0)` it returns negative Z values (-5.82, -2.43, -0.76); the last argument is a drift term. The correct value must be identified by matching the wedge the interface draws (about 0.97 at 706 patients); candidate is the Lan-DeMets drift `z(1-alpha/2) + z(1-beta)`. Fallback: `misc.BoundaryCalculations.setBoundaryGraphData(...)` fills the boundary's graph and `AlphaSpendingBoundary.getInnerWedgeGraph()`, exactly as the interface does.

## R3. Program conventions the R side must respect

- Trial order: year, then alphabetical study name (interface and `getTrialArray()` agree).
- Continuity handling: taken from the `.TSA` file (`zeroEventHandling`, `zeroEventValue`); the program applies it, R does not.
- Random-effects model: `effectModel` code in the file (11 = DerSimonian-Laird). The Z-curve is the program's; it differs from `meta` (`-1.63` vs `1.84` for the same data), which is expected and is the point of the feature.
- Sign: `getZScore()` is negative for a beneficial harm reduction; the graph data flips it to "favours intervention" using `outcomeType`. The package reports the graph orientation.

## R4. rJava installation and JVM location

**Decision**: `rJava` in Imports; JVM found by rJava's normal rules (`JAVA_HOME`, registry, PATH). `tsa_engine()` starts the JVM once (`.jinit` with the jar classpath, headless flag) and caches the `NewIO` instance in a package environment. If `.jinit` fails, the error message names Java as the missing piece; if the jar is missing, `tsa_jar()` names `TSA_HOME`.

**Rationale**: CRAN binary of rJava installed cleanly on Windows; Java 8 JRE was sufficient. Adoptium is the documented download for users.

**Alternatives considered**: `system2("java", ...)` subprocess (no CLI in the jar, rejected); bundling a JRE (size, license, rejected).

## R5. Testing without the program on CI

**Decision**: `skip_if_no_tsa()` helper; golden values stored in `inst/extdata/atb_peecs_result.rds` (captured from the program) drive plot and summary tests. The former R maths lives in `tests/testthat/helper-oracle.R` and is only used to assert parsed values are in plausible ranges, never exported.

## R6. License posture

**Decision**: use only public methods; never ship the jar, manual, sample file or license PDF; document the download link. The reflection-based, documented API above replaces any earlier inspection of class files.
