# bever

bever reads a BEVE file of posterior draws into an R matrix. The file comes from an experimental fork of CmdStan, and bever parses it in Rust through [extendr](https://extendr.github.io/).

## Status

bever is experimental, and it will not get new features. The repository will be archived.

No released CmdStan writes BEVE. The fork sims1253/cmdstan wrote it with `output format=beve` at revision [64659d8](https://github.com/sims1253/cmdstan/tree/64659d87f3438d9e9fe48d309e8f72c3dee1590b) (the writer is `src/cmdstan/io/beve_writer.hpp`). The fork's `develop` branch no longer accepts `format=beve`, so bever reads only files that this revision already wrote. The fork uses the [glaze](https://github.com/stephenberry/glaze) library to write BEVE, and glaze needs C++23, a newer standard than Stan targets. The format was discussed in [Proof of concept: binary output format for CmdStan](https://discourse.mc-stan.org/t/proof-of-concept-binary-output-format-for-cmdstan/40846), and cmdstanr is moving to Parquet instead.

## What the file holds

Each file holds one BEVE object:

```
{ names: [string], rows: u64, cols: u64, data: [[f64]] }
```

`data` is column major: `data[j]` holds every draw of column `names[j]`. The names are the ones in the header of a CmdStan CSV, so for sampling they start with `lp__` and the sampler diagnostics.

The writer ignores all of CmdStan's text output. The file has no configuration, step size, adapted metric, timing or chain id. If you save warmup draws, they are in the same matrix as the sampling draws, and nothing marks where warmup ends.

## Limits

bever trusts the file. It checks that the names, the row and column counts and the data agree, and a truncated file gives an error. It does not check a count against the size of the file, so a corrupt count can make bever ask R for much more memory than the file holds. bever ignores any bytes after the object. Read only files that the fork wrote.

## Install and use

You need Rust 1.96.1 or later.

```r
# install.packages("remotes")
remotes::install_github("sims1253/bever")
```

```r
library(bever)
path <- system.file("extdata", "draws.beve", package = "bever")
draws <- read_beve_stan(path)  # a 100 x 7 double matrix
colnames(draws)
summary(draws[, "mu"])
```

`read_beve_stan()` is the only function. It returns a double matrix with one row per draw and the CmdStan names as column names. A missing or truncated file, or one whose header and data disagree, gives an R error.

## Benchmark

These numbers come from one chain of 1000 draws of `vector[N] z ~ std_normal()`, with N = 100 (107 columns) and N = 10,000 (10,007 columns). CmdStan 2.39.0 wrote the CSV. Each cell is the median time over 5 calls, and the rise in the R process's peak resident memory on the first call.

| Reader | 107 columns | 10,007 columns |
|---|---|---|
| cmdstanr full read | 0.101 s / 13 MB | 2.610 s / 380 MB |
| cmdstanr, one variable | 0.024 s / 8 MB | 0.945 s / 113 MB |
| data.table::fread | 0.013 s / 3 MB | 1.018 s / 265 MB |
| bever | 0.001 s / 4 MB | 0.188 s / 78 MB |
| base R reader | 0.004 s / 9 MB | 0.472 s / 116 MB |

The machine was an AMD Ryzen 5 PRO 5650U with R 4.6.2, cmdstanr 0.9.0, posterior 1.7.0, data.table 1.18.6.1 and rustc 1.98.1. Other jobs used the CPU during the run (load average 16 to 24 on 12 threads). A second run under more load took about three times as long for every reader, with the readers in the same order. The memory figures changed by less than 10 percent between the two runs.

The rows measure different things. "cmdstanr full read" builds a posterior `draws_array` with all variables. "cmdstanr, one variable" reads only `z[1]`, without the sampler diagnostics. `data.table::fread` reads the CSV into a data table. bever and the base R reader ([inst/bench/read_beve_r.R](inst/bench/read_beve_r.R)) return a matrix. The base R reader has about 40 lines. The format does not need compiled code.

What the benchmark does not show:

- The fork did not write the BEVE files. [inst/bench/write_beve.R](inst/bench/write_beve.R) wrote them from the CSV in the fork's layout. To check the layout, the fork's `StanOutput` struct was compiled with glaze 7.0.1 and 9.1.0 and used to write the same draws. For the test fixture, its output is byte for byte the same as the R writer's. For the benchmark files the structure is the same; some values differ in the last bit because data.table and `strtod` round decimal text differently. The fork itself was not built or run.
- It measures one chain only, not a read of several chains.
- It does not measure the Parquet reader in cmdstanr.

To reproduce the table (Linux, because the memory figure comes from `/proc`):

```sh
Rscript inst/bench/make-inputs.R /tmp/bever-bench-inputs
Rscript inst/bench/bench.R /tmp/bever-bench-inputs 5
```

## Where to go instead

Use CmdStan's CSV output with [cmdstanr](https://mc-stan.org/cmdstanr/). For a binary format, follow the Parquet work in cmdstanr: draft pull request [stan-dev/cmdstanr#1342](https://github.com/stan-dev/cmdstanr/pull/1342) adds `read_cmdstan_parquet()`, which can read a subset of variables.
