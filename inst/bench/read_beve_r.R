# Read a BEVE draws file in the sims1253/cmdstan layout with base R only.
# It streams from a connection and reads each column straight into a
# preallocated matrix, so it holds the draws once.
read_beve_r <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))
  byte <- function() as.integer(readBin(con, "raw", 1))
  expect <- function(tag) if (byte() != tag) stop("unexpected BEVE tag in ", path)
  size <- function() {
    b <- byte()
    width <- bitwAnd(b, 3L)
    if (width == 0L) return(bitwShiftR(b, 2L))
    v <- c(b, as.integer(readBin(con, "raw", c(1, 3, 7)[width])))
    sum(v * 256^(seq_along(v) - 1)) %/% 4
  }
  string <- function() rawToChar(readBin(con, "raw", size()))
  u64 <- function() {
    expect(0x71)
    v <- readBin(con, "integer", 2, size = 4, endian = "little")
    v[1] + v[2] * 2^32
  }
  expect(0x03)
  out <- list()
  for (i in seq_len(size())) {
    key <- string()
    if (key == "names") {
      expect(0x3C)
      out$names <- vapply(seq_len(size()), function(j) string(), "")
    } else if (key %in% c("rows", "cols")) {
      out[[key]] <- u64()
    } else if (key == "data") {
      expect(0x05)
      m <- matrix(NA_real_, out$rows, size(), dimnames = list(NULL, out$names))
      for (j in seq_len(ncol(m))) {
        expect(0x64)
        m[, j] <- readBin(con, "double", size(), size = 8, endian = "little")
      }
      out$matrix <- m
    }
  }
  out$matrix
}
