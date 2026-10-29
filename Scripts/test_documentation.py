"""Regression checks for the public-documentation coverage gate."""

import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from check_documentation import check


class DocumentationCoverageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.sources = self.root / "Sources"
        self.sources.mkdir()
        self.source = self.sources / "Example.swift"
        self.source.write_text("public struct Example {}\n")
        self.graphs = self.root / "arm64-apple-ios-simulator"
        self.graphs.mkdir()
        self.symbol = {
            "identifier": {"precise": "s:Example"},
            "accessLevel": "public",
            "pathComponents": ["Example"],
            "location": {
                "uri": self.source.as_uri(), "position": {"line": 0},
            },
            "docComment": {"lines": [{"text": "A documented example."}]},
        }
        for module in ("TapeLogger", "TapeLoggerUI", "TapeLoggerAdapters"):
            self.write(module, [self.symbol] if module == "TapeLogger" else [])

    def write(self, module, symbols):
        (self.graphs / f"{module}.symbols.json").write_text(json.dumps({
            "module": {"name": module}, "symbols": symbols,
        }))

    def validate(self):
        with contextlib.redirect_stdout(io.StringIO()):
            check(self.root, self.sources)

    def test_documented_public_api_passes(self):
        self.validate()

    def test_missing_comment_fails(self):
        self.symbol.pop("docComment")
        self.write("TapeLogger", [self.symbol])
        with self.assertRaises(SystemExit):
            self.validate()

    def test_empty_comment_fails(self):
        self.symbol["docComment"]["lines"] = [{"text": " "}]
        self.write("TapeLogger", [self.symbol])
        with self.assertRaises(SystemExit):
            self.validate()

    def test_missing_module_fails_closed(self):
        (self.graphs / "TapeLoggerUI.symbols.json").unlink()
        with self.assertRaises(SystemExit):
            self.validate()

    def test_synthesized_and_imported_symbols_are_excluded(self):
        synthesized = dict(self.symbol)
        synthesized["identifier"] = {"precise": "s:Example::SYNTHESIZED::equal"}
        synthesized.pop("docComment")
        imported = dict(synthesized)
        imported["identifier"] = {"precise": "s:Imported"}
        imported["location"] = {
            "uri": (self.root / "Framework.swift").as_uri(),
            "position": {"line": 0},
        }
        self.write("TapeLogger", [self.symbol, synthesized, imported])
        self.validate()


if __name__ == "__main__":
    unittest.main()
