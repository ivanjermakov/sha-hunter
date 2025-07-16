use std::{
    cmp::Ordering,
    env,
    process::exit,
    ptr,
    thread::{available_parallelism, spawn},
};

use hex_literal::hex;
use rand::distr::SampleString;
use rand_distr::Alphanumeric;
use sha2::{Digest, Sha256};

mod hex;

fn main() {
    let cpus = available_parallelism().unwrap().into();
    let handles = (0..cpus)
        .map(|n| {
            let prefix = env::args().nth(1).expect("no prefix arg");
            let goal = hex!("000000000F");
            let cpu_flag = format!("{:02x}", n).into_bytes();

            spawn(move || {
                let mut rng = rand::rng();
                loop {
                    let mut data: [u8; 20] = [47; 20];
                    unsafe {
                        ptr::copy_nonoverlapping(
                            prefix.as_bytes().as_ptr(),
                            data[0..13].as_mut_ptr(),
                            13,
                        );
                        ptr::copy_nonoverlapping(cpu_flag.as_ptr(), data[13..15].as_mut_ptr(), 2);
                        let take = Alphanumeric.sample_string(&mut rng, 5);
                        ptr::copy_nonoverlapping(take.as_ptr(), data[15..20].as_mut_ptr(), 5);
                    }

                    let mut hasher = Sha256::new();
                    hasher.update(data);
                    let hash = hasher.finalize();

                    if hash[..].cmp(&goal) == Ordering::Less {
                        println!(
                            "{: <24} {}",
                            String::from_utf8(Vec::from(data)).unwrap(),
                            chunk(&hex::hex(&hash), 8)
                        );
                        exit(0);
                    }
                }
            })
        })
        .collect::<Vec<_>>();

    for handle in handles {
        handle.join().unwrap();
    }
}

fn chunk(s: &str, n: usize) -> String {
    s.chars()
        .collect::<Vec<_>>()
        .chunks(n)
        .map(|c| c.iter().collect())
        .collect::<Vec<String>>()
        .join(" ")
}
