use extendr_api::prelude::*;
use serde::de::{self, Deserializer, SeqAccess, Visitor};
use serde::Deserialize;
use std::cell::Cell;
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
            if matrix.is_none() {
                nrow = column.len();
                matrix = Some(new_matrix(nrow, ncol)?);
            }
            let m = matrix.as_mut().unwrap();
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

thread_local! {
    /// The length of the file that read() is parsing, for new_matrix() to check.
    static FILE_LEN: Cell<Option<u64>> = const { Cell::new(None) };
}

/// Sets FILE_LEN while it lives and clears it when dropped, on every exit path.
struct FileLen;

impl FileLen {
    fn set(len: u64) -> Self {
        FILE_LEN.with(|c| c.set(Some(len)));
        FileLen
    }
}

impl Drop for FileLen {
    fn drop(&mut self) {
        FILE_LEN.with(|c| c.set(None));
    }
}

/// Allocate the matrix, or refuse dimensions R would reject or the file cannot
/// fill. R raises its own error by a long jump that skips Rust cleanup, so it
/// must not see them.
fn new_matrix<E: de::Error>(nrow: usize, ncol: usize) -> std::result::Result<RMatrix<f64>, E> {
    // R_XLEN_T_MAX, the longest vector R allocates.
    const R_MAX_LEN: u64 = 1 << 52;
    let fits = |n: usize| i32::try_from(n).is_ok();
    let len = nrow
        .checked_mul(ncol)
        .filter(|&len| fits(nrow) && fits(ncol) && len as u64 <= R_MAX_LEN)
        .ok_or_else(|| E::custom(format!("{nrow} x {ncol} is too large for an R matrix")))?;
    let bytes = len as u64 * 8;
    let file_len = FILE_LEN.with(Cell::get).unwrap_or(u64::MAX);
    if bytes > file_len {
        return Err(E::custom(format!(
            "{nrow} x {ncol} needs {bytes} bytes, more than the file's {file_len}"
        )));
    }
    Ok(RMatrix::new(nrow, ncol))
}

fn read(path: &str) -> std::result::Result<RMatrix<f64>, String> {
    let cannot_read = |e: std::io::Error| format!("cannot read '{path}': {e}");
    let file = std::fs::File::open(path).map_err(cannot_read)?;
    let output: StanOutput = {
        let _len = FileLen::set(file.metadata().map_err(cannot_read)?.len());
        beve::from_reader_streaming(std::io::BufReader::new(file))
            .map_err(|e| format!("cannot parse '{path}' as BEVE draws: {e}"))?
    };

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
