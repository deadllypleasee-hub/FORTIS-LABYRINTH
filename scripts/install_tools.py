#!/usr/bin/env python3
"""Install pinned official Linux x86_64 tools, verifying downloaded archive hashes."""
from pathlib import Path
import hashlib
import platform
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOOLS = {
    "lune": (
        "https://github.com/lune-org/lune/releases/download/v0.10.4/lune-0.10.4-linux-x86_64.zip",
        "ffba0bd404ae078c9543ef5ac12479938a741aab255768a11a08517ae963b288",
    ),
    "rojo": (
        "https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-linux-x86_64.zip",
        "a9542a713036897fdbd0173e7a105ea409658333133c949025fcb6f1a7ca909d",
    ),
    "stylua": (
        "https://github.com/JohnnyMorganz/StyLua/releases/download/v2.1.0/stylua-linux-x86_64.zip",
        "66a8e8d68003848d23bd7dfca95e3d0e7b96bd19658879b1f8b39d992f3be331",
    ),
}


def main():
    if platform.system() != "Linux" or platform.machine() not in {"x86_64", "amd64"}:
        raise SystemExit("Use rokit install on this platform; this CI installer targets Linux x86_64.")
    downloads = ROOT / "tools/downloads"
    binaries = ROOT / "tools/bin"
    downloads.mkdir(parents=True, exist_ok=True)
    binaries.mkdir(parents=True, exist_ok=True)
    for name, (url, digest) in TOOLS.items():
        archive = downloads / f"{name}.zip"
        if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
            request = urllib.request.Request(url, headers={"User-Agent": "FORTIS-LABYRINTH-CI"})
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = response.read(32 * 1024 * 1024 + 1)
            if len(payload) > 32 * 1024 * 1024 or hashlib.sha256(payload).hexdigest() != digest:
                raise SystemExit(f"Archive verification failed: {name}")
            archive.write_bytes(payload)
        with zipfile.ZipFile(archive) as package:
            entry = next(item for item in package.namelist() if Path(item).name == name)
            executable = binaries / name
            executable.write_bytes(package.read(entry))
            executable.chmod(0o755)
        print(f"Verified and installed {name}")


if __name__ == "__main__":
    main()
