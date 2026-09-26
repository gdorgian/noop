#!/usr/bin/env python3
"""Validate the English source catalogs used by the Apple-only Aura build.

Aura currently ships its new iOS UI in English. Translation coverage for other
locales is not a release promise, but malformed source catalogs must still fail
CI instead of silently falling back or failing at runtime.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CATALOGS = (
    Path("Packages/StrandDesign/Sources/StrandDesign/Resources/Localizable.xcstrings"),
    Path("Strand/Resources/Localizable.xcstrings"),
)


def _string_units(node: object) -> list[dict]:
    if not isinstance(node, dict):
        return []
    units = [node["stringUnit"]] if isinstance(node.get("stringUnit"), dict) else []
    for value in node.values():
        if isinstance(value, dict):
            units.extend(_string_units(value))
    return units


def check_catalog(path: Path) -> list[str]:
    try:
        catalog = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [f"{path}: cannot read source catalog: {error}"]
    if not isinstance(catalog, dict) or catalog.get("sourceLanguage") != "en":
        return [f"{path}: sourceLanguage must be en"]
    strings = catalog.get("strings")
    if not isinstance(strings, dict) or not strings:
        return [f"{path}: strings must be a nonempty object"]

    errors: list[str] = []
    for key, entry in strings.items():
        if not isinstance(key, str) or not isinstance(entry, dict):
            errors.append(f"{path}: invalid source entry {key!r}")
            continue
        english = (entry.get("localizations") or {}).get("en")
        if english is None:
            continue  # The key itself is the English source in an XCString catalog.
        units = _string_units(english)
        if not units:
            errors.append(f"{path}: {key!r} has an empty English localization")
        elif key and any(not isinstance(unit.get("value"), str) or not unit["value"] for unit in units):
            errors.append(f"{path}: {key!r} has an empty English value")
    return errors


def main() -> int:
    errors = [error for relative in CATALOGS for error in check_catalog(ROOT / relative)]
    for error in errors:
        print(error)
    if errors:
        return 1
    print(f"OK: {len(CATALOGS)} English Apple source catalogs are readable and complete")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
