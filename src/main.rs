use std::{
    cmp::Ordering,
    env,
    process::exit,
    sync::{Arc, Mutex},
    thread::{available_parallelism, spawn},
};

use hex_literal::hex;
use sha2::{Digest, Sha256};

mod hex;

fn main() {
    let min = Arc::new(Mutex::new([1; 32]));
    let cpus = available_parallelism().unwrap().into();
    println!("utilizing {cpus} threads");

    let handles = (0..cpus)
        .map(|n| {
            let prefix = env::args().nth(1).expect("no prefix arg");
            let goal = hex!("000000000F");
            let cpu_flag = format!("{:02x}", n).into_bytes();
            let min = min.clone();

            spawn(move || {
                for i in 0..u64::MAX {
                    let data = [
                        prefix.as_bytes(),
                        &cpu_flag,
                        &format!("{:02x}", i).into_bytes(),
                    ]
                    .concat();

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
