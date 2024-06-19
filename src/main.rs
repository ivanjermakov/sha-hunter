use std::{cmp::Ordering, env};

use anyhow::{Context, Result};
use hex_literal::hex;
use sha2::{Digest, Sha256};

mod hex;

fn main() -> Result<()> {
    let prefix = env::args().nth(1).context("prefix argument")?;
    let mut min = [1; 32];
    let goal = hex!("000004FF");

    for i in 1i128.. {
        let data = [prefix.as_bytes(), &format!("{:x}", i).into_bytes()].concat();

        let mut hasher = Sha256::new();
        hasher.update(&data);
        let hash = hasher.finalize();

        if hash[..].cmp(&min) == Ordering::Less {
            min = hash[..].try_into()?;
            println!("{} {}", String::from_utf8(data)?, hex::hex(&hash));
            if hash[..].cmp(&goal) == Ordering::Less {
                return Ok(());
            }
        }
    }

    Ok(())
}
