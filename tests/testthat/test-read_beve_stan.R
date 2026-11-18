source(test_path("fixtures", "fixture-matrix.R"))
fixture <- test_path("fixtures", "draws.beve")

test_that("the fixture round-trips to its source matrix", {
  expect_identical(read_beve_stan(fixture), fixture_matrix())
})

test_that("column names survive", {
  expect_identical(
    colnames(read_beve_stan(fixture)),
    c("lp__", "accept_stat__", "treedepth__", "mu", "theta[1]", "theta[2]", "theta[3]")
  )
})

test_that("the example file is the fixture", {
  example <- system.file("extdata", "draws.beve", package = "bever")
  expect_identical(read_beve_stan(example), read_beve_stan(fixture))
})

test_that("a missing file gives a clear error", {
  expect_error(read_beve_stan(tempfile(fileext = ".beve")), "BEVE file not found")
})

test_that("a bad path argument gives a clear error", {
  expect_error(read_beve_stan(NA_character_), "single file path")
  expect_error(read_beve_stan(c("a", "b")), "single file path")
})

test_that("a truncated file gives an R error, not a crash", {
  bytes <- readBin(fixture, "raw", file.size(fixture))
  for (keep in c(0, 1, 10, 100, length(bytes) %/% 2, length(bytes) - 1)) {
    cut <- tempfile(fileext = ".beve")
    writeBin(bytes[seq_len(keep)], cut)
    expect_error(read_beve_stan(cut), "cannot parse", info = paste(keep, "bytes"))
  }
})

test_that("a file that is not BEVE gives an R error", {
  csv <- tempfile(fileext = ".csv")
  writeLines(c("lp__,mu", "-1,0.5"), csv)
  expect_error(read_beve_stan(csv), "cannot parse")
})

test_that("a header that disagrees with the data gives an R error", {
  bytes <- readBin(fixture, "raw", file.size(fixture))
  # The u64 after the "rows" key holds 100 (0x64); claim 99 instead.
  at <- grepRaw(charToRaw("rows"), bytes) + 5L
  expect_identical(bytes[at], as.raw(100))
  bytes[at] <- as.raw(99)
  bad <- tempfile(fileext = ".beve")
  writeBin(bytes, bad)
  expect_error(read_beve_stan(bad), "inconsistent")
})

test_that("a column count the file cannot fill gives an R error", {
  bytes <- readBin(fixture, "raw", file.size(fixture))
  # After the "data" key come the array header (0x05) and the column count,
  # 7 in one byte (7 * 4 = 0x1c). Write a large count in the eight-byte form
  # instead: 2^31 is too large for R, 2^31 - 1 is not but needs 1.7 TB.
  at <- grepRaw(charToRaw("data"), bytes) + 5L
  expect_identical(bytes[at], as.raw(0x1c))
  counts <- list(
    "100 x 2147483648 is too large for an R matrix" = c(0x03, 0, 0, 0, 0x02, 0, 0, 0),
    "100 x 2147483647 needs 1717986917600 bytes" = c(0xff, 0xff, 0xff, 0xff, 0x01, 0, 0, 0)
  )
  for (message in names(counts)) {
    bad <- tempfile(fileext = ".beve")
    writeBin(c(bytes[seq_len(at - 1L)], as.raw(counts[[message]]), bytes[-seq_len(at)]), bad)
    expect_error(read_beve_stan(bad), paste("cannot parse .*", message))
  }
})
