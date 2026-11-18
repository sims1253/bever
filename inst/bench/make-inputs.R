# Make the benchmark inputs: one chain of 1000 draws from a model with
# N = 100 and N = 10000 standard normal parameters, as a CmdStan CSV and as a
# BEVE file in the sims1253/cmdstan layout.
#
# Needs cmdstanr with a released CmdStan, and data.table. The BEVE file is
# written from the CSV by write_beve.R, not by the fork.
#
#   Rscript inst/bench/make-inputs.R <output dir>
args <- commandArgs(TRUE)
out <- normalizePath(if (length(args)) args[1] else "bench-inputs", mustWork = FALSE)
dir.create(out, showWarnings = FALSE, recursive = TRUE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
source(file.path(here, "write_beve.R"))

stan <- file.path(out, "normals.stan")
writeLines(c(
  "data { int<lower=1> N; }",
  "parameters { vector[N] z; }",
  "model { z ~ std_normal(); }"
), stan)
model <- cmdstanr::cmdstan_model(stan, quiet = TRUE)
for (n in c(100L, 10000L)) {
  fit <- model$sample(
    data = list(N = n), chains = 1, iter_warmup = 200, iter_sampling = 1000,
    seed = 1, refresh = 0, show_messages = FALSE,
    output_dir = out, output_basename = paste0("normals", n)
  )
  csv <- file.path(out, paste0("draws", n, ".csv"))
  file.copy(fit$output_files(), csv, overwrite = TRUE)
  d <- data.table::fread(cmd = paste("grep -v '^#'", shQuote(csv)))
  write_beve_draws(as.matrix(d), file.path(out, paste0("draws", n, ".beve")))
}
cat("CmdStan", cmdstanr::cmdstan_version(), "inputs in", out, "\n")
