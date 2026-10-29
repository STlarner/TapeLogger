#!/usr/bin/env python3
"""Require comments on source-declared public API in iOS symbol graphs."""

import argparse
import json
from pathlib import Path
from urllib.parse import unquote, urlparse


def check(graph_root, source_root):
    symbols = {}
    modules = set()
    for path in graph_root.glob("**/arm64-apple-ios-simulator/*.symbols.json"):
        graph = json.loads(path.read_text())
        module = graph["module"]["name"]
        if module not in {"TapeLogger", "TapeLoggerUI", "TapeLoggerAdapters"}:
            continue
        modules.add(module)
        for symbol in graph["symbols"]:
            identifier = symbol["identifier"]["precise"]
            if symbol.get("accessLevel") not in {"public", "open"}:
                continue
            # Compiler-synthesized conformances are not source-authored API.
            if "::SYNTHESIZED::" in identifier:
                continue
            location = symbol.get("location", {})
            uri = urlparse(location.get("uri", ""))
            if uri.scheme != "file":
                continue
            source = Path(unquote(uri.path)).resolve()
            if not source.is_relative_to(source_root):
                continue
            symbols[identifier] = (symbol, source)

    expected = {"TapeLogger", "TapeLoggerUI", "TapeLoggerAdapters"}
    if modules != expected:
        raise SystemExit(f"Missing iOS symbol graphs: {expected - modules}")
    if not symbols:
        raise SystemExit("No source-declared public API found")
    missing = []
    for symbol, source in symbols.values():
        comment = symbol.get("docComment", {}).get("lines", [])
        if not any(line.get("text", "").strip() for line in comment):
            line = symbol["location"]["position"]["line"] + 1
            title = ".".join(symbol["pathComponents"])
            missing.append(f"{source}:{line}: undocumented public API: {title}")
    for message in sorted(missing):
        print(message)
    print(f"Documented public API: {len(symbols) - len(missing)}/{len(symbols)}")
    if missing:
        raise SystemExit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("graph_root", type=Path)
    args = parser.parse_args()
    check(args.graph_root, Path(__file__).resolve().parents[1] / "Sources")
