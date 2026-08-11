//! Alea PRNG, ported 1:1 from the flashcards implementation
//! (which mirrors ts-fsrs / AleaGenerator semantics).
//!
//! All arithmetic intentionally uses `f64` to reproduce JavaScript `Number`
//! behaviour, including `>>> 0` (mod 2^32) and `| 0` (mod 2^32, signed).

const TWO_32: f64 = 4_294_967_296.0;
const SCALE: f64 = 2.328_306_436_538_696_3e-10;

/// JS `x >>> 0` / `x | 0`: truncate `x` modulo 2^32, then reinterpret as
/// unsigned (for `>>>`) or signed (for `|`) 32-bit integer.
fn to_uint32(x: f64) -> u32 {
    (x % TWO_32) as u32
}

fn to_int32(x: f64) -> i32 {
    to_uint32(x) as i32
}

/// JS Mash generator (stateful).
struct Mash {
    n: f64,
}

impl Mash {
    fn new() -> Self {
        Self {
            n: 0xefc8_249du32 as f64,
        }
    }

    fn next(&mut self, data: &str) -> f64 {
        let mut next = self.n;
        for c in data.chars() {
            next += c as u32 as f64;
            let mut h = 0.025_196_032_824_169_38 * next;
            next = to_uint32(h) as f64;
            h -= next;
            h *= next;
            next = to_uint32(h) as f64;
            h -= next;
            next += h * TWO_32;
        }
        self.n = next;
        to_uint32(next) as f64 * SCALE
    }
}

/// Deterministic PRNG from a string seed.
pub struct Alea {
    c: i32,
    s0: f64,
    s1: f64,
    s2: f64,
}

impl Alea {
    pub fn new(seed: &str) -> Self {
        let mut mash = Mash::new();
        let mut s0 = mash.next(" ");
        let mut s1 = mash.next(" ");
        let mut s2 = mash.next(" ");

        s0 -= mash.next(seed);
        if s0 < 0.0 {
            s0 += 1.0;
        }
        s1 -= mash.next(seed);
        if s1 < 0.0 {
            s1 += 1.0;
        }
        s2 -= mash.next(seed);
        if s2 < 0.0 {
            s2 += 1.0;
        }

        Self { c: 1, s0, s1, s2 }
    }

    // `next` mirrors the reference alea implementation's method name;
    // kept as-is for structural parity with the reference, not Iterator.
    #[allow(clippy::should_implement_trait)]
    pub fn next(&mut self) -> f64 {
        let t = 2_091_639.0 * self.s0 + self.c as f64 * SCALE;
        self.s0 = self.s1;
        self.s1 = self.s2;
        self.c = to_int32(t);
        self.s2 = t - self.c as f64;
        self.s2
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn alea_is_deterministic() {
        let mut a = Alea::new("1700000000000_1_1.3592519940588799");
        let mut b = Alea::new("1700000000000_1_1.3592519940588799");
        for _ in 0..100 {
            assert_eq!(a.next(), b.next());
        }
    }

    #[test]
    fn alea_values_in_unit_interval() {
        let mut a = Alea::new("test-seed");
        for _ in 0..1000 {
            let v = a.next();
            assert!((0.0..1.0).contains(&v), "value out of range: {v}");
        }
    }
}
