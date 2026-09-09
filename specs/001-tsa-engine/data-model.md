# Data Model: TSA Software as Calculation Engine

## Entities

### Analysis request (R side, input)

| Field | Type | Source | Validation |
|---|---|---|---|
| `meta` | `metabin` object | user | class `metabin`; `sm` in RR, OR, RD; `k >= 1` |
| `rrr` | numeric or NULL | user | in (0, 1) when given; NULL = program estimates |
| `control`, `intervention` | numeric or NULL | user | in (0, 1); at most one of `rrr`/`intervention` |
| `alpha` | numeric | user, default 0.05 | in (0, 1) |
| `beta` | numeric | user, default 0.20 | in (0, 1) |
| `diversity` | `"estimate"` or numeric | user, default `"estimate"` | numeric in [0, 1) |
| `futility` | logical | default TRUE | |
| `information_axis` | `"sample"`, `"events"`, `"statistical"` | default `"sample"` | maps to program codes 302/304/303 |
| `outcome` | `"negative"`/`"positive"` | default `"negative"` | program `outcomeType` 1/-1 |
| `model` | `"random_dl"`, `"random_sj"`, `"random_bt"`, `"fixed"` | default `"random_dl"` | program `effectModel` 11/16/12/10 |
| `label.e`, `label.c`, `title` | character | from `meta` or user | non-empty |

### Analysis file (`.TSA`, exchange format)

Tab-separated `key<TAB>value` lines in `#METAANALYSIS`, `#TRIAL`, `#BOUNDARY`, `#GRAPH` blocks. Unchanged from the current `tsa_write()` / `tsa_read()`; one conventional boundary and one alpha-spending boundary are written per request. Relationship: one Analysis request → exactly one Analysis file.

### Program run (transient)

| Field | Type | Notes |
|---|---|---|
| `jar` | path | from `tsa_jar()` |
| `file` | path | the Analysis file |
| `ma` | Java ref `data.MetaAnalysis` | loaded by `io.NewIO` |
| `boundary` | Java ref `data.SequentialBoundaryDich` | the alpha-spending boundary of the file |
| `status` | `"ok"` or error | Java exceptions mapped to R errors carrying the program's message |

State: created → loaded → calculated → extracted. A failed load or calculation raises; no partial result object is returned (FR-005, SC-003).

### TSA result (`easytsa`, output)

```
easytsa
├── looks        data.frame, one row per trial in program order
│   ├── k          integer look index
│   ├── studlab    character
│   ├── year       integer
│   ├── n          participants in the trial
│   ├── n_cum      cumulative participants (program X coordinate)
│   ├── IF         information fraction (program getTArray)
│   ├── z          cumulative Z, program orientation (positive favours intervention)
│   ├── upper      monitoring boundary (program value; conventional z beyond RIS)
│   └── futility   inner-wedge value or NA
├── bounds       data.frame of boundary points incl. the RIS point (for plotting)
├── ris          list: ris, adjustment, d2, control, intervention, rrr, alpha, beta
├── pooled       list: effect (RR/OR/RD), z, d2, i2, tau, model (from data.MetaAnalysis)
├── conclusion   list: status text, crossed, futile, ris_reached, first_cross, first_futile
├── adjusted_ci  data.frame: conventional and boundary-adjusted CI (program boundary at last look)
├── settings     list echoing the Analysis request plus program codes used
├── file         path of the Analysis file used
└── engine       list: jar path, program version string, java version
```

Invariants: `nrow(looks) == meta$k`; `looks$n_cum` strictly increasing; `looks$upper >= qnorm(1 - alpha/2)`; every numeric in `looks`, `ris`, `pooled` originates from a jar call (no R arithmetic beyond unit conversion percent → proportion).

## Relationships

- Analysis request 1 → 1 Analysis file → 1 Program run → 1 TSA result.
- TSA result → plot (many, appearance only).
- Analysis file ↔ program interface (open / save) without change.
