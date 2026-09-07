# Build data/atb_peecs.rda + inst/extdata/atb_peecs.csv
# Source: MetaHub mentorship project "ATB prophylaxis and PEECS after ESD",
# sheet A_peecs of atb_peecs_data.xlsx (rows with include = TRUE, 2026-09).
# Run from package root: source("data-raw/atb_peecs.R")

atb_peecs <- data.frame(
  author  = c("Lee SP", "Shichijo S", "Hastier-De Chelle A", "Qiu J",
              "Liao F", "Zhao YR", "Chen T"),
  year    = c(2017, 2022, 2022, 2024, 2024, 2025, 2025),
  event.e = c(1, 9, 9, 10, 10, 35, 22),
  n.e     = c(50, 192, 170, 100, 110, 131, 67),
  event.c = c(8, 14, 0, 35, 59, 40, 9),
  n.c     = c(50, 188, 56, 455, 442, 131, 14),
  design  = c("RCT", "RCT", "Observational", "Observational",
              "Observational", "Observational", "Observational"),
  organ   = c("Colorectum", "Colorectum", "Esophagus (POEM)", "Colorectum",
              "Esophagus", "Esophagus", "Stomach"),
  country = c("South Korea", "Japan", "France", "China", "China", "China",
              "China"),
  stringsAsFactors = FALSE
)

utils::write.csv(atb_peecs, "inst/extdata/atb_peecs.csv", row.names = FALSE)
save(atb_peecs, file = "data/atb_peecs.rda", compress = "bzip2", version = 2)
