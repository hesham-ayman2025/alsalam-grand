#!/usr/bin/env python3
"""Mirror of the AOSP recovery whole-file verifier (minzip/verifier) layout checks,
plus an independent OpenSSL signature verification against a given certificate.
Usage: verify_ota.py CERT.pem ZIP [ZIP...]
"""
import subprocess, sys, tempfile, zipfile
from pathlib import Path

FOOTER = 6
EOCD = 22


def verify(cert: Path, path: Path) -> None:
    d = path.read_bytes()
    n = len(d)
    f = d[-FOOTER:]
    assert f[2] == 0xFF and f[3] == 0xFF, "footer magic"
    sig_start = f[0] | (f[1] << 8)
    comment = f[4] | (f[5] << 8)
    assert sig_start >= FOOTER and sig_start <= comment <= n, "footer sizes"
    eocd_size = comment + EOCD
    e = d[n - eocd_size:]
    assert e[:4] == b"PK\x05\x06", "EOCD magic"
    assert (e[20] | (e[21] << 8)) == comment, "EOCD comment length"
    sig = d[n - sig_start: n - FOOTER]
    signed_len = n - comment - 2
    signed = d[:signed_len]
    with tempfile.TemporaryDirectory() as t:
        Path(t, "sig").write_bytes(sig); Path(t, "data").write_bytes(signed)
        r = subprocess.run(["openssl", "smime", "-verify", "-binary", "-inform", "DER",
                            "-in", f"{t}/sig", "-content", f"{t}/data", "-noverify",
                            "-certfile", str(cert), "-out", "/dev/null"],
                           capture_output=True, text=True)
        assert r.returncode == 0, "openssl verify failed: " + r.stderr
        # signer certificate embedded in the block must be the expected one
        r2 = subprocess.run(["openssl", "pkcs7", "-inform", "DER", "-in", f"{t}/sig", "-print_certs"],
                            capture_output=True, text=True)
        exp = Path(cert).read_text().strip()
        assert exp.split("-----BEGIN CERTIFICATE-----")[1] in r2.stdout, "embedded cert differs"
    # the zip itself must still be a valid archive (python ignores the comment)
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        assert "META-INF/com/google/android/update-binary" in z.namelist()
    print(f"OK  {path.name}  signed_len={signed_len} sig={len(sig)}B comment={comment}")


if __name__ == "__main__":
    cert = Path(sys.argv[1])
    for z in sys.argv[2:]:
        verify(cert, Path(z))
