# Regenerate the test fixture and the example file. Run from the package root:
#   Rscript tests/testthat/fixtures/make-fixture.R
# The file comes from the R writer in inst/bench/write_beve.R, which follows
# the sims1253/cmdstan layout. It is not output of the fork itself.
source("inst/bench/write_beve.R")
source("tests/testthat/fixtures/fixture-matrix.R")
write_beve_draws(fixture_matrix(), "tests/testthat/fixtures/draws.beve")
file.copy("tests/testthat/fixtures/draws.beve", "inst/extdata/draws.beve", overwrite = TRUE)
