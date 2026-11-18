#' Read a BEVE draws file written by the sims1253/cmdstan fork
#'
#' Reads a `.beve` file that revision 64659d8 of the experimental
#' `sims1253/cmdstan` fork wrote with `output format=beve`. Later revisions of
#' the fork do not write this format, and no released CmdStan writes it.
#'
#' @param path Path to the `.beve` file.
#' @return A double matrix with one row per draw and one column per CmdStan
#'   output column (for sampling: `lp__`, the sampler diagnostics ending in
#'   `__`, then the model's parameters). Column names are the CmdStan names,
#'   such as `"theta[1]"`.
#' @examples
#' path <- system.file("extdata", "draws.beve", package = "bever")
#' draws <- read_beve_stan(path)
#' dim(draws)
#' summary(draws[, "mu"])
#' @export
read_beve_stan <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    stop("`path` must be a single file path.", call. = FALSE)
  }
  path <- path.expand(path)
  if (!file.exists(path)) {
    stop("BEVE file not found: ", path, call. = FALSE)
  }
  draws <- read_beve(path)
  if (is.character(draws)) stop(draws, call. = FALSE)
  draws
}
