# The matrix behind fixtures/draws.beve: 100 draws of a CmdStan-like output
# (lp__, two sampler diagnostics, mu, theta[1..3]). theta[3] holds NaN, Inf
# and -Inf so the round trip covers non-finite doubles.
fixture_matrix <- function() {
  set.seed(20261118)
  n <- 100
  x <- cbind(
    "lp__" = -rexp(n, 0.1),
    "accept_stat__" = runif(n),
    "treedepth__" = sample(1:4, n, replace = TRUE),
    "mu" = rnorm(n),
    "theta[1]" = rnorm(n, 1),
    "theta[2]" = rnorm(n, 2),
    "theta[3]" = c(NaN, Inf, -Inf, rnorm(n - 3))
  )
  storage.mode(x) <- "double"
  x
}
