#' Read BEVE file from CmdStan
#'
#' @param path Path to the .beve file
#' @return A matrix with named columns containing posterior samples
#' @export
read_beve_stan <- function(path) {
  if (!file.exists(path)) {
    stop("BEVE file not found: ", path, call. = FALSE)
  }

  result <- read_beve(path)
  mat <- result$matrix
  colnames(mat) <- result$names
  mat
}
