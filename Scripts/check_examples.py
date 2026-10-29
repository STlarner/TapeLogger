#!/usr/bin/env python3
"""Compile Swift fences in the README, source comments and DocC catalogs."""

import argparse
from pathlib import Path
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
IMPORTS = "\n".join(
    f"import {module}" for module in (
        "Foundation", "SwiftUI", "UIKit", "TapeLogger", "TapeLoggerUI",
        "TapeLoggerAdapters",
    )
) + "\n"


def examples():
    paths = [ROOT / "README.md"] + sorted((ROOT / "Sources").rglob("*.swift"))
    paths += sorted((ROOT / "Sources").rglob("*.docc/*.md"))
    for path in paths:
        text = path.read_text()
        if path.suffix == ".swift":
            text = "\n".join(
                re.sub(r"^\s*/// ?", "", line)
                for line in text.splitlines()
                if line.lstrip().startswith("///")
            )
        for index, code in enumerate(re.findall(
            r"```swift\n(.*?)```", text, re.DOTALL
        ), start=1):
            yield path, index, code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--documentation-build", type=Path,
        default=ROOT / ".build/documentation",
    )
    args = parser.parse_args()
    products = args.documentation_build.resolve() / (
        "derived-data/Build/Products/Debug-iphonesimulator"
    )
    if not (products / "TapeLoggerAdapters.swiftmodule").is_dir():
        raise SystemExit("Build documentation before checking iOS examples")
    sdk = subprocess.check_output(
        ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True
    ).strip()
    count = 0
    with tempfile.TemporaryDirectory(prefix="tapelogger-examples-") as temp:
        temp = Path(temp)
        for path, index, code in examples():
            print(f"Checking {path.relative_to(ROOT)} example {index}", flush=True)
            if code.lstrip().startswith(".package("):
                manifest = temp / "Package.swift"
                manifest.write_text(
                    "// swift-tools-version: 6.0\nimport PackageDescription\n"
                    'let package = Package(name: "Example", dependencies: [\n'
                    + code + "], targets: [])\n"
                )
                subprocess.run(
                    ["swift", "package", "--package-path", str(temp),
                     "dump-package"], check=True, stdout=subprocess.DEVNULL,
                )
            else:
                arguments = [
                    "xcrun", "swiftc", "-c", "-swift-version", "6",
                    "-D", "DEBUG", "-target", "arm64-apple-ios17.0-simulator",
                    "-sdk", sdk, "-I", str(products),
                    "-module-name", "DocumentationExample",
                    "-o", str(temp / "Example.o"), "-",
                ]
                if "@main" in code:
                    arguments.insert(2, "-parse-as-library")
                subprocess.run(
                    arguments, input=IMPORTS + code, text=True, check=True
                )
            count += 1
    if count == 0:
        raise SystemExit("No Swift examples found")
    print(f"Compiled {count} documentation examples for iOS in Swift 6")


if __name__ == "__main__":
    main()
