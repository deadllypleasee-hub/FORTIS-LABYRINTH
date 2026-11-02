#!/usr/bin/env python3
"""Check Rojo source mappings and, optionally, emitted Place structure."""
import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECTS = {"default": "Preview", "hub": "Hub", "dungeon": "Dungeon"}


def check_paths(node):
    assert isinstance(node, dict), "invalid project node"
    if "$path" in node:
        path = (ROOT / node["$path"]).resolve()
        assert path.is_relative_to(ROOT) and path.exists(), f"invalid Rojo path: {path}"
    for key, value in node.items():
        if not key.startswith("$") and isinstance(value, dict):
            check_paths(value)


def check_build(kind):
    path = ROOT / "dist" / f"FORTIS-{kind}.rbxlx"
    tree = ET.parse(path)
    items = list(tree.iter("Item"))
    classes = [item.attrib.get("class") for item in items]
    assert classes.count("Script") == 1, f"{kind}: server entrypoint missing/duplicated"
    assert classes.count("LocalScript") == 1, f"{kind}: client entrypoint missing/duplicated"
    assert classes.count("ModuleScript") >= 15, f"{kind}: missing runtime modules"
    values = [node.text for node in tree.iter("string") if node.attrib.get("name") == "Value"]
    assert kind in values, f"{kind}: wrong PlaceKind value"
    sources = [
        node.text or "" for node in tree.iter()
        if node.tag in {"string", "ProtectedString"} and node.attrib.get("name") == "Source"
    ]
    assert len(sources) >= 17 and all(source.strip() for source in sources), f"{kind}: empty source"
    print(f"Checked {path.name}: {len(items)} serialized Instances, {len(sources)} scripts/modules")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--built", action="store_true")
    args = parser.parse_args()
    for name, kind in PROJECTS.items():
        project = json.loads((ROOT / f"{name}.project.json").read_text())
        tree = project["tree"]
        assert tree["$className"] == "DataModel"
        check_paths(tree)
        assert tree["ReplicatedStorage"]["PlaceKind"]["$properties"]["Value"] == kind
        assert tree["ReplicatedStorage"]["Shared"]["$path"] == "src/shared"
        assert "Server" not in tree["ReplicatedStorage"], "server modules exposed to clients"
        assert tree["ServerScriptService"]["Server"]["$path"] == "src/server"
        assert tree["ServerScriptService"]["Hub"]["$path"] == "src/hub"
        assert tree["ServerScriptService"]["Dungeon"]["$path"] == "src/dungeon"
        assert tree["StarterPlayer"]["StarterPlayerScripts"]["Client"]["$path"] == "src/client"
        assert tree["Workspace"]["$properties"]["StreamingEnabled"] is True
        print(f"Checked {name}.project.json ({kind})")
        if args.built:
            check_build(kind)


if __name__ == "__main__":
    main()
