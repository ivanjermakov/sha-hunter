use sha2::{Digest, Sha256};

mod hex;

fn main() {
    let mut sha = Sha256::new();
    sha.update(b"Hello, world!");
    println!("{:}", hex::hex(&sha.finalize()));
}
