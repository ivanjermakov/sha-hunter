use std::{
    cmp::Ordering,
    env,
    process::exit,
    sync::{Arc, Mutex},
};

use anyhow::{Context, Result};
use hex_literal::hex;
use rayon::prelude::*;
use sha2::{Digest, Sha256};

mod hex;

fn main() -> Result<()> {
    let prefix = env::args().nth(1).context("prefix argument")?;
    let min = Arc::new(Mutex::new([1; 32]));
    let goal = hex!("000000000F");

    (0..u64::MAX).into_par_iter().for_each(|i| {
        let data = [prefix.as_bytes(), &format!("{:x}", i).into_bytes()].concat();

        let mut hasher = Sha256::new();
        hasher.update(&data);
        let hash = hasher.finalize();

        if hash[..].cmp(min.lock().unwrap().as_ref()) == Ordering::Less {
            let v = min.clone();
            let mut v = v.lock().unwrap();
            *v = hash[..].try_into().unwrap();
            println!(
                "{: <32} {}",
                String::from_utf8(data).unwrap(),
                chunk(&hex::hex(&hash), 8)
            );
            if hash[..].cmp(&goal) == Ordering::Less {
                exit(0);
            }
        }
    });

    Ok(())
}

fn chunk(s: &str, n: usize) -> String {
    s.chars()
        .collect::<Vec<_>>()
        .chunks(n)
        .map(|c| c.iter().collect())
        .collect::<Vec<String>>()
        .join(" ")
}
