#!/usr/bin/env python3
"""Apply validated Place IDs to a build without source editing on a phone."""
import argparse
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def configure(source: str, hub: str, dungeon: str) -> str:
    hub, dungeon = hub.strip(), dungeon.strip()
    if not hub and not dungeon:
        return source
    ids = []
    for label, value in (("HUB", hub), ("Dungeon", dungeon)):
        if not re.fullmatch(r"[1-9][0-9]{0,15}", value) or int(value) > 9007199254740991:
            raise ValueError(f"{label}: provide a positive, exactly representable integer Place ID")
        ids.append(int(value))
    if ids[0] == ids[1]:
        raise ValueError("HUB and Dungeon must be different Places in one Experience")
    for field, value in zip(("HubPlaceId", "DungeonPlaceId"), ids):
        source, count = re.subn(
            rf"(\b{field}\s*=\s*)[0-9]+(?=\s*,)",
            lambda match: match[1] + str(value),
            source,
        )
        if count != 1:
            raise ValueError(f"Expected exactly one {field} configuration entry")
    return source


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hub", default=os.environ.get("FORTIS_HUB_PLACE_ID", ""))
    parser.add_argument("--dungeon", default=os.environ.get("FORTIS_DUNGEON_PLACE_ID", ""))
    args = parser.parse_args()
    path = ROOT / "src/shared/Config.luau"
    source = path.read_text(encoding="utf-8")
    try:
        updated = configure(source, args.hub, args.dungeon)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    if source != updated:
        path.write_text(updated, encoding="utf-8")
        print("Applied HUB and Dungeon IDs to this build's source.")
    else:
        print("Place configuration unchanged.")


if __name__ == "__main__":
    main()
