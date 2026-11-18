use extendr_api::prelude::*;
use serde::de::{self, Deserializer, SeqAccess, Visitor};
use serde::Deserialize;
use std::fmt;

/// The object the sims1253/cmdstan BEVE writer serialises:
/// `{names: [str], rows: u64, cols: u64, data: [[f64]]}`, with `data[col][row]`.
#[derive(Deserialize)]
struct StanOutput {
    names: Vec<String>,
    rows: usize,
    cols: usize,
    data: Columns,
}

/// The `data` field, decoded column by column into an R matrix, so the draws
/// are held once in R memory instead of first in nested Rust vectors.
struct Columns(RMatrix<f64>);

impl<'de> Deserialize<'de> for Columns {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> std::result::Result<Self, D::Error> {
        deserializer.deserialize_seq(ColumnsVisitor)
    }
}

struct ColumnsVisitor;

impl<'de> Visitor<'de> for ColumnsVisitor {
    type Value = Columns;

    fn expecting(&self, f: &mut fmt::Formatter) -> fmt::Result {
        f.write_str("an array of equal-length f64 arrays")
    }

    fn visit_seq<A: SeqAccess<'de>>(self, mut seq: A) -> std::result::Result<Columns, A::Error> {
        let ncol = seq
            .size_hint()
            .ok_or_else(|| de::Error::custom("column count is not known"))?;
        let mut matrix: Option<RMatrix<f64>> = None;
        let mut nrow = 0;
        let mut j = 0;
        while let Some(column) = seq.next_element::<Vec<f64>>()? {
            if j == ncol {
                return Err(de::Error::custom("more columns than announced"));
            }
            let m = matrix.get_or_insert_with(|| {
                nrow = column.len();
                RMatrix::new(nrow, ncol)
            });
            if column.len() != nrow {
                return Err(de::Error::custom(format!(
                    "column {} has {} rows, column 1 has {}",
                    j + 1,
                    column.len(),
                    nrow
                )));
            }
            m.data_mut()[j * nrow..(j + 1) * nrow].copy_from_slice(&column);
            j += 1;
        }
        if j != ncol {
            return Err(de::Error::custom("fewer columns than announced"));
        }
        Ok(Columns(matrix.unwrap_or_else(|| RMatrix::new(0, 0))))
    }
}

fn read(path: &str) -> std::result::Result<RMatrix<f64>, String> {
    let file = std::fs::File::open(path).map_err(|e| format!("cannot read '{path}': {e}"))?;
    let output: StanOutput = beve::from_reader_streaming(std::io::BufReader::new(file))
        .map_err(|e| format!("cannot parse '{path}' as BEVE draws: {e}"))?;

    let mut m = output.data.0;
    let (nrow, ncol) = (m.nrows(), m.ncols());
    // With no columns the data cannot show a row count, so only compare rows when ncol > 0.
    if ncol != output.cols || output.names.len() != ncol || (ncol > 0 && nrow != output.rows) {
        return Err(format!(
            "'{path}' is inconsistent: header says {} x {} with {} names, data is {nrow} x {ncol}",
            output.rows,
            output.cols,
            output.names.len()
        ));
    }
    m.set_dimnames(list!(NULL, output.names));
    Ok(m)
}

/// Read a BEVE draws file into a matrix (internal; see read_beve_stan()).
/// Returns the matrix, or the error message as a string for R to raise,
/// so errors never unwind through a Rust panic.
/// @param path Path to the .beve file.
/// @noRd
#[extendr]
fn read_beve(path: &str) -> Robj {
    match read(path) {
        Ok(m) => m.into(),
        Err(msg) => msg.into(),
    }
}

extendr_module! {
    mod bever;
    fn read_beve;
}
