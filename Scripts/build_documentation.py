#!/usr/bin/env python3
"""Build and validate iOS DocC archives, then stage a GitHub Pages site."""

import argparse
import html
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

from check_documentation import check


ROOT = Path(__file__).resolve().parents[1]
MODULES = ("TapeLogger", "TapeLoggerUI", "TapeLoggerAdapters")


def run(*arguments):
    print("+ " + shlex.join(str(value) for value in arguments), flush=True)
    subprocess.run([str(value) for value in arguments], cwd=ROOT, check=True)


def redirect(path, destination):
    escaped = html.escape(destination, quote=True)
    path.write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8">'
        '<title>TapeLogger API</title>'
        f'<meta http-equiv="refresh" content="0;url={escaped}">'
        f'<a href="{escaped}">TapeLogger API documentation</a></html>\n'
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output", type=Path, default=ROOT / ".build/documentation"
    )
    parser.add_argument("--hosting-base-path", default="TapeLogger/api")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    derived = output / "derived-data"
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
    ).strip()
    flags = shlex.join([
        "--warnings-as-errors", "--experimental-documentation-coverage",
        "--checkout-path", str(ROOT), "--source-service", "github",
        "--source-service-base-url",
        f"https://github.com/STlarner/TapeLogger/blob/{commit}",
    ])
    # UI docbuild includes core; adapters includes UIKit on this destination.
    for scheme in ("TapeLoggerUI", "TapeLoggerAdapters"):
        run(
            "xcodebuild", "-quiet", "docbuild", "-scheme", scheme,
            "-configuration", "Debug", "-destination",
            "generic/platform=iOS Simulator", "-derivedDataPath", derived,
            "CODE_SIGNING_ALLOWED=NO", "DOCC_EXTRACT_EXTENSION_SYMBOLS=YES",
            f"DOCC_HOSTING_BASE_PATH={args.hosting_base_path}",
            f"OTHER_DOCC_FLAGS={flags}",
        )
    check(derived, ROOT / "Sources")
    products = derived / "Build/Products/Debug-iphonesimulator"
    archives = [products / f"{module}.doccarchive" for module in MODULES]
    for archive in archives:
        if not archive.is_dir():
            raise SystemExit(f"Missing documentation archive: {archive}")
    # DocC merge requires an empty destination. Stage fresh artifacts on every
    # run so removed symbols cannot survive as stale pages from an older build.
    marker = ".tapelogger-generated"
    names = ("TapeLogger.doccarchive", "site")
    for name in names:
        destination = output / name
        if destination.exists() and (
            destination.is_symlink() or not (destination / marker).is_file()
        ):
            raise SystemExit(
                f"Refusing to replace unrecognized output: {destination}. "
                "Choose a fresh --output directory."
            )
    with tempfile.TemporaryDirectory(prefix="docc-stage-", dir=output) as temp:
        staging = Path(temp)
        merged = staging / "TapeLogger.doccarchive"
        run(
            "xcrun", "docc", "merge", *archives, "--output-path", merged,
            "--synthesized-landing-page-name", "TapeLogger · main",
        )
        site = staging / "site"
        site.mkdir()
        api = site / "api"
        run(
            "xcrun", "docc", "process-archive", "transform-for-static-hosting",
            merged, "--output-path", api,
            "--hosting-base-path", args.hosting_base_path,
        )
        if not (api / "documentation/index.html").is_file():
            raise SystemExit("Merged documentation landing page was not generated")
        for module in MODULES:
            if not (api / "documentation" / module.lower() / "index.html").is_file():
                raise SystemExit(f"Missing static module page: {module}")
        redirect(site / "index.html", "api/")
        redirect(api / "index.html", "documentation/")
        (site / ".nojekyll").touch()
        (site / "build.json").write_text(
            '{"ref":"main","commit":"' + commit + '"}\n'
        )
        for name in names:
            (staging / name / marker).touch()
            destination = output / name
            if destination.exists():
                destination.rename(staging / f"previous-{name}")
            (staging / name).rename(destination)
    print(f"Documentation site: {output / 'site'}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
