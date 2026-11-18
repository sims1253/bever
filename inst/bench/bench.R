# Run every reader on both inputs, each in its own R process, and print a
# Markdown table of median time and peak extra memory.
#   Rscript inst/bench/make-inputs.R /tmp/bever-bench-inputs
#   Rscript inst/bench/bench.R /tmp/bever-bench-inputs
args <- commandArgs(TRUE)
dir <- normalizePath(if (length(args)) args[1] else "bench-inputs")
reps <- if (length(args) > 1) args[2] else "5"
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
readers <- c(
  cmdstanr_full = "cmdstanr full read", cmdstanr_one = "cmdstanr, one variable",
  fread = "data.table::fread", bever = "bever", pure_r = "pure R reader"
)
rscript <- file.path(R.home("bin"), "Rscript")
res <- do.call(rbind, lapply(names(readers), function(r) {
  do.call(rbind, lapply(c("100", "10000"), function(n) {
    line <- system2(rscript, c(file.path(here, "bench-one.R"), r, n, dir, reps), stdout = TRUE)
    read.delim(text = line, header = FALSE, col.names = c("reader", "n", "s", "mb"))
  }))
}))
cell <- function(r, n) {
  x <- res[res$reader == r & res$n == n, ]
  sprintf("%.3f s / %.0f MB", x$s, x$mb)
}
cat("| Reader | 107 columns | 10,007 columns |\n|---|---|---|\n")
for (r in names(readers)) cat(sprintf("| %s | %s | %s |\n", readers[[r]], cell(r, 100), cell(r, 10000)))
cat("\n", R.version.string, "; cmdstanr ", format(packageVersion("cmdstanr")),
    "; data.table ", format(packageVersion("data.table")),
    "; bever ", format(packageVersion("bever")), "\n", sep = "")
cat(grep("model name", readLines("/proc/cpuinfo"), value = TRUE)[1], "\n")
