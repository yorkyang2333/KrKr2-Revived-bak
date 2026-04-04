//! krkr2-fft: Real Discrete FFT for KrKr2 engine.
//!
//! This is a direct port of the Ooura FFT implementation from `RealFFT_Default.cpp`.
//! The original code is from: http://momonga.t.u-tokyo.ac.jp/~ooura/fft-j.html
//!
//! We port the algorithm directly to Rust (rather than using rustfft) to ensure
//! bit-exact compatibility with the original C implementation, since the
//! PhaseVocoderDSP depends on the exact numerical behavior.

// ============================================================================
// Public FFI entry point
// ============================================================================

/// Real Discrete Fourier Transform.
///
/// Signature matches the original C function exactly:
/// `void rdft(int n, int isgn, float *a, int *ip, float *w);`
///
/// # Safety
/// - `a` must point to at least `n` floats
/// - `ip` must point to at least `2 + (1 << (log2(n/2) - 1))` ints
/// - `w` must point to at least `n/2` floats
#[no_mangle]
pub unsafe extern "C" fn rdft(n: i32, isgn: i32, a: *mut f32, ip: *mut i32, w: *mut f32) {
    let a = unsafe { std::slice::from_raw_parts_mut(a, n as usize) };
    let ip_len = 2 + (n as usize); // conservative upper bound
    let ip = unsafe { std::slice::from_raw_parts_mut(ip, ip_len) };
    let w_len = n as usize; // conservative upper bound
    let w = unsafe { std::slice::from_raw_parts_mut(w, w_len) };

    rdft_impl(n, isgn, a, ip, w);
}

fn rdft_impl(n: i32, isgn: i32, a: &mut [f32], ip: &mut [i32], w: &mut [f32]) {
    let nu = n as usize;

    let nw = ip[0] as usize;
    if nu > nw << 2 {
        let new_nw = nu >> 2;
        makewt(new_nw, ip, w);
    }
    let nw = ip[0] as usize;

    let nc = ip[1] as usize;
    if nu > nc << 2 {
        let new_nc = nu >> 2;
        makect(new_nc, ip, &mut w[nw..]);
    }
    let nc = ip[1] as usize;

    if isgn >= 0 {
        if nu > 4 {
            bitrv2(nu, &mut ip[2..], a);
            cftfsub(nu, a, w);
            rftfsub(nu, a, nc, &w[nw..]);
        } else if nu == 4 {
            cftfsub(nu, a, w);
        }
        let xi = a[0] - a[1];
        a[0] += a[1];
        a[1] = xi;
    } else {
        a[1] = 0.5 * (a[0] - a[1]);
        a[0] -= a[1];
        if nu > 4 {
            rftbsub(nu, a, nc, &w[nw..]);
            bitrv2(nu, &mut ip[2..], a);
            cftbsub(nu, a, w);
        } else if nu == 4 {
            cftfsub(nu, a, w);
        }
    }
}

fn makewt(nw: usize, ip: &mut [i32], w: &mut [f32]) {
    ip[0] = nw as i32;
    ip[1] = 1;
    if nw > 2 {
        let nwh = nw >> 1;
        let delta = (1.0f64).atan() / nwh as f64;
        w[0] = 1.0;
        w[1] = 0.0;
        w[nwh] = (delta * nwh as f64).cos() as f32;
        w[nwh + 1] = w[nwh];
        if nwh > 2 {
            for j in (2..nwh).step_by(2) {
                let x = (delta * j as f64).cos() as f32;
                let y = (delta * j as f64).sin() as f32;
                w[j] = x;
                w[j + 1] = y;
                w[nw - j] = y;
                w[nw - j + 1] = x;
            }
            bitrv2(nw, ip, w);
        }
    }
}

fn makect(nc: usize, ip: &mut [i32], c: &mut [f32]) {
    ip[1] = nc as i32;
    if nc > 1 {
        let nch = nc >> 1;
        let delta = (1.0f64).atan() / nch as f64;
        c[0] = (delta * nch as f64).cos() as f32;
        c[nch] = 0.5 * c[0];
        for j in 1..nch {
            c[j] = 0.5 * (delta * j as f64).cos() as f32;
            c[nc - j] = 0.5 * (delta * j as f64).sin() as f32;
        }
    }
}

// ============================================================================
// Internal FFT routines (direct port from C)
// ============================================================================

fn cft1st(n: usize, a: &mut [f32], w: &[f32]) {
    let mut x0r = a[0] + a[2];
    let mut x0i = a[1] + a[3];
    let x1r = a[0] - a[2];
    let x1i = a[1] - a[3];
    let x2r = a[4] + a[6];
    let x2i = a[5] + a[7];
    let x3r = a[4] - a[6];
    let x3i = a[5] - a[7];
    a[0] = x0r + x2r;
    a[1] = x0i + x2i;
    a[4] = x0r - x2r;
    a[5] = x0i - x2i;
    a[2] = x1r - x3i;
    a[3] = x1i + x3r;
    a[6] = x1r + x3i;
    a[7] = x1i - x3r;

    let wk1r = w[2];
    x0r = a[8] + a[10];
    x0i = a[9] + a[11];
    let x1r = a[8] - a[10];
    let x1i = a[9] - a[11];
    let x2r = a[12] + a[14];
    let x2i = a[13] + a[15];
    let x3r = a[12] - a[14];
    let x3i = a[13] - a[15];
    a[8] = x0r + x2r;
    a[9] = x0i + x2i;
    a[12] = x2i - x0i;
    a[13] = x0r - x2r;
    x0r = x1r - x3i;
    x0i = x1i + x3r;
    a[10] = wk1r * (x0r - x0i);
    a[11] = wk1r * (x0r + x0i);
    x0r = x3i + x1r;
    x0i = x3r - x1i;
    a[14] = wk1r * (x0i - x0r);
    a[15] = wk1r * (x0i + x0r);

    let mut k1: usize = 0;
    let mut j = 16;
    while j < n {
        k1 += 2;
        let k2 = 2 * k1;
        let wk2r = w[k1];
        let wk2i = w[k1 + 1];
        let wk1r = w[k2];
        let wk1i = w[k2 + 1];
        let wk3r = wk1r - 2.0 * wk2i * wk1i;
        let wk3i = 2.0 * wk2i * wk1r - wk1i;

        let mut x0r = a[j] + a[j + 2];
        let mut x0i = a[j + 1] + a[j + 3];
        let x1r = a[j] - a[j + 2];
        let x1i = a[j + 1] - a[j + 3];
        let x2r = a[j + 4] + a[j + 6];
        let x2i = a[j + 5] + a[j + 7];
        let x3r = a[j + 4] - a[j + 6];
        let x3i = a[j + 5] - a[j + 7];
        a[j] = x0r + x2r;
        a[j + 1] = x0i + x2i;
        x0r -= x2r;
        x0i -= x2i;
        a[j + 4] = wk2r * x0r - wk2i * x0i;
        a[j + 5] = wk2r * x0i + wk2i * x0r;
        x0r = x1r - x3i;
        x0i = x1i + x3r;
        a[j + 2] = wk1r * x0r - wk1i * x0i;
        a[j + 3] = wk1r * x0i + wk1i * x0r;
        x0r = x1r + x3i;
        x0i = x1i - x3r;
        a[j + 6] = wk3r * x0r - wk3i * x0i;
        a[j + 7] = wk3r * x0i + wk3i * x0r;

        let wk1r = w[k2 + 2];
        let wk1i = w[k2 + 3];
        let wk3r = wk1r - 2.0 * wk2r * wk1i;
        let wk3i = 2.0 * wk2r * wk1r - wk1i;

        x0r = a[j + 8] + a[j + 10];
        x0i = a[j + 9] + a[j + 11];
        let x1r = a[j + 8] - a[j + 10];
        let x1i = a[j + 9] - a[j + 11];
        let x2r = a[j + 12] + a[j + 14];
        let x2i = a[j + 13] + a[j + 15];
        let x3r = a[j + 12] - a[j + 14];
        let x3i = a[j + 13] - a[j + 15];
        a[j + 8] = x0r + x2r;
        a[j + 9] = x0i + x2i;
        x0r -= x2r;
        x0i -= x2i;
        a[j + 12] = -wk2i * x0r - wk2r * x0i;
        a[j + 13] = -wk2i * x0i + wk2r * x0r;
        x0r = x1r - x3i;
        x0i = x1i + x3r;
        a[j + 10] = wk1r * x0r - wk1i * x0i;
        a[j + 11] = wk1r * x0i + wk1i * x0r;
        x0r = x1r + x3i;
        x0i = x1i - x3r;
        a[j + 14] = wk3r * x0r - wk3i * x0i;
        a[j + 15] = wk3r * x0i + wk3i * x0r;

        j += 16;
    }
}

fn cftmdl(n: usize, l: usize, a: &mut [f32], w: &[f32]) {
    let m = l << 2;

    for j in (0..l).step_by(2) {
        let j1 = j + l;
        let j2 = j1 + l;
        let j3 = j2 + l;
        let x0r = a[j] + a[j1];
        let x0i = a[j + 1] + a[j1 + 1];
        let x1r = a[j] - a[j1];
        let x1i = a[j + 1] - a[j1 + 1];
        let x2r = a[j2] + a[j3];
        let x2i = a[j2 + 1] + a[j3 + 1];
        let x3r = a[j2] - a[j3];
        let x3i = a[j2 + 1] - a[j3 + 1];
        a[j] = x0r + x2r;
        a[j + 1] = x0i + x2i;
        a[j2] = x0r - x2r;
        a[j2 + 1] = x0i - x2i;
        a[j1] = x1r - x3i;
        a[j1 + 1] = x1i + x3r;
        a[j3] = x1r + x3i;
        a[j3 + 1] = x1i - x3r;
    }

    let wk1r = w[2];
    for j in (m..l + m).step_by(2) {
        let j1 = j + l;
        let j2 = j1 + l;
        let j3 = j2 + l;
        let x0r = a[j] + a[j1];
        let x0i = a[j + 1] + a[j1 + 1];
        let x1r = a[j] - a[j1];
        let x1i = a[j + 1] - a[j1 + 1];
        let x2r = a[j2] + a[j3];
        let x2i = a[j2 + 1] + a[j3 + 1];
        let x3r = a[j2] - a[j3];
        let x3i = a[j2 + 1] - a[j3 + 1];
        a[j] = x0r + x2r;
        a[j + 1] = x0i + x2i;
        a[j2] = x2i - x0i;
        a[j2 + 1] = x0r - x2r;
        let mut x0r = x1r - x3i;
        let mut x0i = x1i + x3r;
        a[j1] = wk1r * (x0r - x0i);
        a[j1 + 1] = wk1r * (x0r + x0i);
        x0r = x3i + x1r;
        x0i = x3r - x1i;
        a[j3] = wk1r * (x0i - x0r);
        a[j3 + 1] = wk1r * (x0i + x0r);
    }

    let mut k1: usize = 0;
    let m2 = 2 * m;
    let mut k = m2;
    while k < n {
        k1 += 2;
        let k2 = 2 * k1;
        let wk2r = w[k1];
        let wk2i = w[k1 + 1];
        let mut wk1r = w[k2];
        let mut wk1i = w[k2 + 1];
        let mut wk3r = wk1r - 2.0 * wk2i * wk1i;
        let mut wk3i = 2.0 * wk2i * wk1r - wk1i;

        for j in (k..l + k).step_by(2) {
            let j1 = j + l;
            let j2 = j1 + l;
            let j3 = j2 + l;
            let mut x0r = a[j] + a[j1];
            let mut x0i = a[j + 1] + a[j1 + 1];
            let x1r = a[j] - a[j1];
            let x1i = a[j + 1] - a[j1 + 1];
            let x2r = a[j2] + a[j3];
            let x2i = a[j2 + 1] + a[j3 + 1];
            let x3r = a[j2] - a[j3];
            let x3i = a[j2 + 1] - a[j3 + 1];
            a[j] = x0r + x2r;
            a[j + 1] = x0i + x2i;
            x0r -= x2r;
            x0i -= x2i;
            a[j2] = wk2r * x0r - wk2i * x0i;
            a[j2 + 1] = wk2r * x0i + wk2i * x0r;
            x0r = x1r - x3i;
            x0i = x1i + x3r;
            a[j1] = wk1r * x0r - wk1i * x0i;
            a[j1 + 1] = wk1r * x0i + wk1i * x0r;
            x0r = x1r + x3i;
            x0i = x1i - x3r;
            a[j3] = wk3r * x0r - wk3i * x0i;
            a[j3 + 1] = wk3r * x0i + wk3i * x0r;
        }

        wk1r = w[k2 + 2];
        wk1i = w[k2 + 3];
        wk3r = wk1r - 2.0 * wk2r * wk1i;
        wk3i = 2.0 * wk2r * wk1r - wk1i;

        for j in (k + m..l + (k + m)).step_by(2) {
            let j1 = j + l;
            let j2 = j1 + l;
            let j3 = j2 + l;
            let mut x0r = a[j] + a[j1];
            let mut x0i = a[j + 1] + a[j1 + 1];
            let x1r = a[j] - a[j1];
            let x1i = a[j + 1] - a[j1 + 1];
            let x2r = a[j2] + a[j3];
            let x2i = a[j2 + 1] + a[j3 + 1];
            let x3r = a[j2] - a[j3];
            let x3i = a[j2 + 1] - a[j3 + 1];
            a[j] = x0r + x2r;
            a[j + 1] = x0i + x2i;
            x0r -= x2r;
            x0i -= x2i;
            a[j2] = -wk2i * x0r - wk2r * x0i;
            a[j2 + 1] = -wk2i * x0i + wk2r * x0r;
            x0r = x1r - x3i;
            x0i = x1i + x3r;
            a[j1] = wk1r * x0r - wk1i * x0i;
            a[j1 + 1] = wk1r * x0i + wk1i * x0r;
            x0r = x1r + x3i;
            x0i = x1i - x3r;
            a[j3] = wk3r * x0r - wk3i * x0i;
            a[j3 + 1] = wk3r * x0i + wk3i * x0r;
        }

        k += m2;
    }
}

fn bitrv2(n: usize, ip: &mut [i32], a: &mut [f32]) {
    ip[0] = 0;
    let mut l = n;
    let mut m: usize = 1;
    while (m << 3) < l {
        l >>= 1;
        for j in 0..m {
            ip[m + j] = ip[j] + l as i32;
        }
        m <<= 1;
    }
    let m2 = 2 * m;
    if (m << 3) == l {
        for k in 0..m {
            for j in 0..k {
                let j1 = 2 * j + ip[k] as usize;
                let k1 = 2 * k + ip[j] as usize;
                a.swap(j1, k1);
                a.swap(j1 + 1, k1 + 1);

                let j1b = j1 + m2;
                let k1b = k1 + 2 * m2;
                a.swap(j1b, k1b);
                a.swap(j1b + 1, k1b + 1);

                let j1c = j1b + m2;
                let k1c = k1b - m2;
                a.swap(j1c, k1c);
                a.swap(j1c + 1, k1c + 1);

                let j1d = j1c + m2;
                let k1d = k1c + 2 * m2;
                a.swap(j1d, k1d);
                a.swap(j1d + 1, k1d + 1);
            }
            let j1 = 2 * k + m2 + ip[k] as usize;
            let k1 = j1 + m2;
            a.swap(j1, k1);
            a.swap(j1 + 1, k1 + 1);
        }
    } else {
        for k in 1..m {
            for j in 0..k {
                let j1 = 2 * j + ip[k] as usize;
                let k1 = 2 * k + ip[j] as usize;
                a.swap(j1, k1);
                a.swap(j1 + 1, k1 + 1);

                let j1b = j1 + m2;
                let k1b = k1 + m2;
                a.swap(j1b, k1b);
                a.swap(j1b + 1, k1b + 1);
            }
        }
    }
}

fn rftfsub(n: usize, a: &mut [f32], nc: usize, c: &[f32]) {
    let m = n >> 1;
    let ks = 2 * nc / m;
    let mut kk: usize = 0;
    let mut j = 2;
    while j < m {
        let k = n - j;
        kk += ks;
        let wkr = 0.5 - c[nc - kk];
        let wki = c[kk];
        let xr = a[j] - a[k];
        let xi = a[j + 1] + a[k + 1];
        let yr = wkr * xr - wki * xi;
        let yi = wkr * xi + wki * xr;
        a[j] -= yr;
        a[j + 1] -= yi;
        a[k] += yr;
        a[k + 1] -= yi;
        j += 2;
    }
}

fn cftfsub(n: usize, a: &mut [f32], w: &[f32]) {
    let mut l: usize = 2;
    if n > 8 {
        cft1st(n, a, w);
        l = 8;
        while (l << 2) < n {
            cftmdl(n, l, a, w);
            l <<= 2;
        }
    }
    if (l << 2) == n {
        for j in (0..l).step_by(2) {
            let j1 = j + l;
            let j2 = j1 + l;
            let j3 = j2 + l;
            let x0r = a[j] + a[j1];
            let x0i = a[j + 1] + a[j1 + 1];
            let x1r = a[j] - a[j1];
            let x1i = a[j + 1] - a[j1 + 1];
            let x2r = a[j2] + a[j3];
            let x2i = a[j2 + 1] + a[j3 + 1];
            let x3r = a[j2] - a[j3];
            let x3i = a[j2 + 1] - a[j3 + 1];
            a[j] = x0r + x2r;
            a[j + 1] = x0i + x2i;
            a[j2] = x0r - x2r;
            a[j2 + 1] = x0i - x2i;
            a[j1] = x1r - x3i;
            a[j1 + 1] = x1i + x3r;
            a[j3] = x1r + x3i;
            a[j3 + 1] = x1i - x3r;
        }
    } else {
        for j in (0..l).step_by(2) {
            let j1 = j + l;
            let x0r = a[j] - a[j1];
            let x0i = a[j + 1] - a[j1 + 1];
            a[j] += a[j1];
            a[j + 1] += a[j1 + 1];
            a[j1] = x0r;
            a[j1 + 1] = x0i;
        }
    }
}

fn cftbsub(n: usize, a: &mut [f32], w: &[f32]) {
    let mut l: usize = 2;
    if n > 8 {
        cft1st(n, a, w);
        l = 8;
        while (l << 2) < n {
            cftmdl(n, l, a, w);
            l <<= 2;
        }
    }
    if (l << 2) == n {
        for j in (0..l).step_by(2) {
            let j1 = j + l;
            let j2 = j1 + l;
            let j3 = j2 + l;
            let x0r = a[j] + a[j1];
            let x0i = -a[j + 1] - a[j1 + 1];
            let x1r = a[j] - a[j1];
            let x1i = -a[j + 1] + a[j1 + 1];
            let x2r = a[j2] + a[j3];
            let x2i = a[j2 + 1] + a[j3 + 1];
            let x3r = a[j2] - a[j3];
            let x3i = a[j2 + 1] - a[j3 + 1];
            a[j] = x0r + x2r;
            a[j + 1] = x0i - x2i;
            a[j2] = x0r - x2r;
            a[j2 + 1] = x0i + x2i;
            a[j1] = x1r - x3i;
            a[j1 + 1] = x1i - x3r;
            a[j3] = x1r + x3i;
            a[j3 + 1] = x1i + x3r;
        }
    } else {
        for j in (0..l).step_by(2) {
            let j1 = j + l;
            let x0r = a[j] - a[j1];
            let x0i = -a[j + 1] + a[j1 + 1];
            a[j] += a[j1];
            a[j + 1] = -a[j + 1] - a[j1 + 1];
            a[j1] = x0r;
            a[j1 + 1] = x0i;
        }
    }
}

fn rftbsub(n: usize, a: &mut [f32], nc: usize, c: &[f32]) {
    a[1] = -a[1];
    let m = n >> 1;
    let ks = 2 * nc / m;
    let mut kk: usize = 0;
    let mut j = 2;
    while j < m {
        let k = n - j;
        kk += ks;
        let wkr = 0.5 - c[nc - kk];
        let wki = c[kk];
        let xr = a[j] - a[k];
        let xi = a[j + 1] + a[k + 1];
        let yr = wkr * xr + wki * xi;
        let yi = wkr * xi - wki * xr;
        a[j] -= yr;
        a[j + 1] = yi - a[j + 1];
        a[k] += yr;
        a[k + 1] = yi - a[k + 1];
        j += 2;
    }
    a[m + 1] = -a[m + 1];
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rdft_forward_inverse_roundtrip() {
        let n = 16;
        let mut a = vec![0.0f32; n];
        let mut ip = vec![0i32; n];
        let mut w = vec![0.0f32; n];

        // Initialize with known signal
        for i in 0..n {
            a[i] = (i as f32) * 0.1;
        }
        let original = a.clone();

        // Forward transform
        rdft_impl(n as i32, 1, &mut a, &mut ip, &mut w);

        // Inverse transform
        rdft_impl(n as i32, -1, &mut a, &mut ip, &mut w);

        // Scale by 2/n (as per Ooura convention)
        let scale = 2.0 / n as f32;
        for x in a.iter_mut() {
            *x *= scale;
        }

        // Compare with original
        for i in 0..n {
            assert!(
                (a[i] - original[i]).abs() < 1e-5,
                "Mismatch at index {}: {} vs {}",
                i,
                a[i],
                original[i]
            );
        }
    }

    #[test]
    fn test_rdft_dc_signal() {
        let n = 8;
        let mut a = vec![1.0f32; n];
        let mut ip = vec![0i32; n];
        let mut w = vec![0.0f32; n];

        rdft_impl(n as i32, 1, &mut a, &mut ip, &mut w);

        // DC component should be sum of all values = 8.0
        assert!((a[0] - 8.0).abs() < 1e-5);
        // Nyquist should be 0 for constant signal
        assert!(a[1].abs() < 1e-5);
        // All other frequency bins should be 0
        for i in 2..n {
            assert!(a[i].abs() < 1e-5, "Non-zero at index {}: {}", i, a[i]);
        }
    }
}
