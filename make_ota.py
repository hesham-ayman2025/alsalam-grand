#!/usr/bin/env python3
"""Build and whole-file-sign three recovery zips for the Al Salam Home APK.

  AlSalam_00_NOOP_TEST.zip      - prints diagnostics, writes nothing
  AlSalam_01_INSTALL_HOME.zip   - adds the APK to /system/priv-app, renames Philips launcher
  AlSalam_02_ROLLBACK.zip       - restores Philips launcher, removes the APK

Signing matches AOSP signapk "-w": detached PKCS#7 (SHA1withRSA, no signed
attributes) in the zip comment + 6 byte footer. The signed bytes are the zip
without the 2-byte EOCD comment-length field and the comment itself.
"""
import argparse, hashlib, os, struct, subprocess, sys, tempfile, zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE.parent / "ota" / "update-binary.sh"
MESSAGE = b"signed by AlSalam ota builder\x00"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build_zip(mode: str, apk: bytes | None) -> bytes:
    script = SCRIPT.read_text()
    script = script.replace("@MODE@", mode).replace("@APK_SHA256@", sha256(apk) if apk else "none")
    import io
    buf = io.BytesIO()
    fixed = (2009, 1, 1, 0, 0, 0)  # reproducible builds
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        zi = zipfile.ZipInfo("META-INF/com/google/android/update-binary", fixed)
        zi.external_attr = 0o755 << 16
        zi.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(zi, script.encode())
        zi = zipfile.ZipInfo("META-INF/com/google/android/updater-script", fixed)
        zi.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(zi, b"# intentionally empty: update-binary is a shell script\n")
        if apk is not None:
            zi = zipfile.ZipInfo("payload/AlSalamGrandHome.apk", fixed)
            zi.compress_type = zipfile.ZIP_STORED
            z.writestr(zi, apk)
    data = buf.getvalue()
    assert data[-22:-18] == b"PK\x05\x06" and data[-2:] == b"\x00\x00", "unexpected EOCD"
    return data


def pkcs7_sign(signed: bytes, key_pem: Path, cert_pem: Path) -> bytes:
    with tempfile.TemporaryDirectory() as d:
        inp = Path(d, "in.bin"); inp.write_bytes(signed)
        out = Path(d, "sig.der")
        subprocess.run(["openssl", "smime", "-sign", "-binary", "-noattr", "-md", "sha1",
                        "-outform", "DER", "-signer", str(cert_pem), "-inkey", str(key_pem),
                        "-in", str(inp), "-out", str(out)], check=True)
        return out.read_bytes()


def sign_whole_file(zip_bytes: bytes, key_pem: Path, cert_pem: Path) -> bytes:
    body = zip_bytes[:-2]                       # everything except EOCD comment length
    sig = pkcs7_sign(body, key_pem, cert_pem)
    signature_start = len(sig) + 6
    comment_size = len(MESSAGE) + len(sig) + 6
    if comment_size > 0xFFFF:
        raise SystemExit("signature block too large")
    footer = struct.pack("<HBBH", signature_start, 0xFF, 0xFF, comment_size)
    return body + struct.pack("<H", comment_size) + MESSAGE + sig + footer


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apk", required=True, type=Path)
    ap.add_argument("--out-dir", required=True, type=Path)
    ap.add_argument("--key", required=True, type=Path, help="private key, PEM")
    ap.add_argument("--cert", required=True, type=Path, help="certificate, PEM")
    a = ap.parse_args()
    apk = a.apk.read_bytes()
    a.out_dir.mkdir(parents=True, exist_ok=True)
    jobs = [("noop", None, "AlSalam_00_NOOP_TEST.zip"),
            ("install", apk, "AlSalam_01_INSTALL_HOME.zip"),
            ("rollback", None, "AlSalam_02_ROLLBACK.zip")]
    for mode, payload, name in jobs:
        signed = sign_whole_file(build_zip(mode, payload), a.key, a.cert)
        (a.out_dir / name).write_bytes(signed)
        print(f"{name}  {len(signed)} bytes  sha256={sha256(signed)}")


if __name__ == "__main__":
    main()
