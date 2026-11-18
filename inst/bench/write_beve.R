# Write a draws matrix as BEVE, in the layout of the sims1253/cmdstan writer
# (src/cmdstan/io/beve_writer.hpp, serialised with glaze):
#
#   {names: [string], rows: u64, cols: u64, data: [[f64]]}   data[col][row]
#
# BEVE bytes used here: 0x03 object with string keys, 0x3C typed array of
# strings, 0x71 u64, 0x05 generic array, 0x64 typed array of f64. Sizes use
# BEVE's compressed integers (2 low bits give the width: 1, 2, 4 or 8 bytes).
write_beve_draws <- function(x, path) {
  x <- as.matrix(x)
  storage.mode(x) <- "double"
  stopifnot(!is.null(colnames(x)), nrow(x) < 2^30, ncol(x) < 2^30)
  con <- file(path, "wb")
  on.exit(close(con))
  byte <- function(b) writeBin(as.raw(b), con)
  size <- function(n) {
    if (n < 2^6) byte(n * 4)
    else if (n < 2^14) writeBin(as.integer(n * 4 + 1), con, size = 2, endian = "little")
    else writeBin(as.integer(n * 4 + 2), con, size = 4, endian = "little")
  }
  string <- function(s) {
    b <- charToRaw(enc2utf8(s))
    size(length(b))
    writeBin(b, con)
  }
  u64 <- function(n) {
    byte(0x71)
    writeBin(c(as.integer(n), 0L), con, size = 4, endian = "little")
  }
  byte(0x03); size(4)
  string("names"); byte(0x3C); size(ncol(x)); for (s in colnames(x)) string(s)
  string("rows"); u64(nrow(x))
  string("cols"); u64(ncol(x))
  string("data"); byte(0x05); size(ncol(x))
  for (j in seq_len(ncol(x))) {
    byte(0x64); size(nrow(x))
    writeBin(x[, j], con, size = 8, endian = "little")
  }
  invisible(path)
}
