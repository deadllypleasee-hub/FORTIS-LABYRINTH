#!/usr/bin/env python3
"""Package reviewed source and the three Rojo builds for an Android owner."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
BUILDS = [DIST / f"FORTIS-{name}.rbxlx" for name in ("Preview", "Hub", "Dungeon")]


def main():
    for file in BUILDS:
        if not file.is_file():
            raise SystemExit(f"Missing build: {file.name}; run rojo build first")
    sums = "".join(
        f"{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}\n"
        for file in BUILDS
    )
    (DIST / "SHA256SUMS.txt").write_text(sums)
    files = []
    for path in ROOT.rglob("*"):
        relative = path.relative_to(ROOT)
        if any(part in {".git", "tools", "dist", "__pycache__"} for part in relative.parts):
            continue
        if path.is_file():
            files.append(path)
    archive = DIST / "FORTIS-LABYRINTH-stage1.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as package:
        for path in sorted(files):
            package.write(path, str(Path("FORTIS-LABYRINTH") / path.relative_to(ROOT)))
        for path in BUILDS + [DIST / "SHA256SUMS.txt"]:
            package.write(path, str(Path("FORTIS-LABYRINTH/builds") / path.name))
    print(f"Packaged {len(files)} source files + 3 Places: {archive.name} ({archive.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
