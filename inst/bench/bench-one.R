# Time one reader on one input in a fresh R process and print one line.
#   Rscript inst/bench/bench-one.R <reader> <N> <input dir> [reps]
# Peak extra memory is the rise in the process's resident high-water mark
# (VmHWM, Linux only) over the first call, after all packages are loaded.
args <- commandArgs(TRUE)
reader <- args[1]; n <- args[2]; dir <- args[3]
reps <- if (length(args) > 3) as.integer(args[4]) else 5L
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
source(file.path(here, "read_beve_r.R"))
csv <- file.path(dir, paste0("draws", n, ".csv"))
beve <- file.path(dir, paste0("draws", n, ".beve"))
run <- switch(reader,
  cmdstanr_full = function() cmdstanr::read_cmdstan_csv(csv, format = "draws_array")$post_warmup_draws,
  cmdstanr_one = function() cmdstanr::read_cmdstan_csv(csv, variables = "z[1]", sampler_diagnostics = "", format = "draws_array")$post_warmup_draws,
  fread = function() data.table::fread(cmd = paste("grep -v '^#'", shQuote(csv))),
  bever = function() bever::read_beve_stan(beve),
  pure_r = function() read_beve_r(beve),
  stop("unknown reader ", reader)
)
hwm_mb <- function() {
  line <- grep("^VmHWM", readLines("/proc/self/status"), value = TRUE)
  as.numeric(gsub("\\D", "", line)) / 1024
}
for (p in c("cmdstanr", "posterior", "data.table", "bever")) invisible(loadNamespace(p))
before <- hwm_mb()
invisible(run())
peak <- hwm_mb() - before
times <- replicate(reps, system.time(run())[["elapsed"]])
cat(sprintf("%s\t%s\t%.3f\t%.0f\n", reader, n, median(times), peak))
