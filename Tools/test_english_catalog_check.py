"""Regression tests for the English-only Apple source-catalog gate."""

import json
import tempfile
import unittest
from pathlib import Path

from english_catalog_check import check_catalog


class EnglishCatalogCheckTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "Localizable.xcstrings"

    def write(self, catalog: dict) -> None:
        self.path.write_text(json.dumps(catalog), encoding="utf-8")

    def test_english_key_can_be_its_own_source(self) -> None:
        self.write({"sourceLanguage": "en", "strings": {"Today": {}}})
        self.assertEqual([], check_catalog(self.path))

    def test_rejects_wrong_source_language(self) -> None:
        self.write({"sourceLanguage": "de", "strings": {"Today": {}}})
        self.assertIn("sourceLanguage must be en", check_catalog(self.path)[0])

    def test_rejects_empty_english_value_in_plural(self) -> None:
        self.write({"sourceLanguage": "en", "strings": {"%lld days": {
            "localizations": {"en": {"variations": {"plural": {
                "one": {"stringUnit": {"value": "%lld day"}},
                "other": {"stringUnit": {"value": ""}},
            }}}},
        }}})
        self.assertIn("empty English value", check_catalog(self.path)[0])

    def test_rejects_malformed_json(self) -> None:
        self.path.write_text("{", encoding="utf-8")
        self.assertIn("cannot read source catalog", check_catalog(self.path)[0])
