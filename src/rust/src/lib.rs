use extendr_api::prelude::*;
use serde::Deserialize;

#[derive(Deserialize, Debug)]
struct StanOutput {
    names: Vec<String>,
    rows: usize,
    cols: usize,
    data: Vec<Vec<f64>>,  // column-major: data[col][row]
}

/// Read a BEVE file produced by CmdStan
/// @param path Path to the .beve file
/// @return A named list with 'matrix' (the draws) and 'names' (column names)
/// @export
#[extendr]
fn read_beve(path: &str) -> List {
    let bytes = match std::fs::read(path) {
        Ok(b) => b,
        Err(e) => {
            throw_r_error(format!("Failed to read file: {}", e));
        }
    };
    
    let output: StanOutput = match beve::from_slice(&bytes) {
        Ok(o) => o,
        Err(e) => {
            throw_r_error(format!("Failed to parse BEVE: {:?}", e));
        }
    };
    
    // Create R matrix (R stores column-major, so we transpose)
    let rmatrix = RMatrix::new_matrix(output.rows, output.cols, |r, c| {
        output.data[c][r]
    });
    
    list!(
        matrix = rmatrix,
        names = output.names,
        rows = output.rows as i32,
        cols = output.cols as i32
    )
}

extendr_module! {
    mod bever;
    fn read_beve;
}
