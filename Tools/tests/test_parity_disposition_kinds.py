"""Every kind the ratchet can REQUIRE must be a kind a disposition may declare.

`_required_v3_exemptions` builds its kind strings from the set names, and
`_validate_dispositions` accepts a fixed vocabulary. If those drift apart, the
requirement becomes unsatisfiable: the required kind is rejected by validation,
and the accepted kind never matches the requirement, so the debt can neither be
waived nor cleared and `--refresh-derived` refuses forever.

That happened with `unpaired_properties`, which a naive `name[:-1]` stems to
`unpaired-propertie`. Every other set survives the strip, which is why no test
caught it until a one-sided property first appeared.
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import parity_ledger
import parity_ratchet


class DispositionKindVocabularyTests(unittest.TestCase):
    EMPTY = {
        "unpaired_files": [], "unpaired_functions": [], "unpaired_properties": [],
        "unpaired_constants": [], "function_pairs": [], "property_pairs": [],
        "constant_pairs": [],
    }

    def _required_kinds(self) -> set[str]:
        current = dict(self.EMPTY)
        identity = "swift" + chr(0) + "X.swift::a/1#1"
        for name in ("unpaired_files", "unpaired_functions",
                     "unpaired_properties", "unpaired_constants"):
            current[name] = [identity]
        required = parity_ratchet._required_v3_exemptions(
            self.EMPTY, current, set(), set()
        )
        return {kind for kind, _ in required}

    def test_every_required_add_kind_is_declarable(self) -> None:
        identity = "swift" + chr(0) + "X.swift::a/1#1"
        for kind in sorted(self._required_kinds()):
            doc = {
                "schema_version": 1,
                "dispositions": [{
                    "type": "platform_specific",
                    "kind": kind,
                    "identity": identity,
                    "identity_sha256": parity_ledger._canonical_sha256(identity),
                    "platform": "swift",
                    "rationale": "Declared one-sided on purpose for this vocabulary test.",
                }],
            }
            with self.subTest(kind=kind):
                parity_ratchet._validate_dispositions(doc, "test")

    def test_property_kind_is_singular(self) -> None:
        self.assertIn("add-unpaired-property", self._required_kinds())
        self.assertNotIn("add-unpaired-propertie", self._required_kinds())

    def test_out_of_scope_twin_requires_excluded_swift_path(self) -> None:
        identity = "kotlin\0android/app/src/main/java/com/noop/data/WhoopRepository.kt::hrUnionFingerprint/3#1"
        item = {
            "type": "out_of_scope_twin",
            "kind": "add-unpaired-function",
            "identity": identity,
            "identity_sha256": parity_ledger._canonical_sha256(identity),
            "platform": "kotlin",
            "rationale": "The Swift role twin lives in the excluded app layer.",
            "twin_path": "Strand/Data/Repository.swift",
        }
        parity_ratchet._validate_dispositions(
            {"schema_version": 1, "dispositions": [item]}, "test",
            Path(__file__).resolve().parents[2],
        )
        for bad_path in ("Packages/WhoopStore/Sources/Repository.swift",
                         "Strand/../Data/Repository.swift", "Strand/Data/Missing.swift"):
            with self.subTest(path=bad_path), self.assertRaises(parity_ratchet.RatchetError):
                parity_ratchet._validate_dispositions(
                    {"schema_version": 1, "dispositions": [{**item, "twin_path": bad_path}]},
                    "test", Path(__file__).resolve().parents[2],
                )

    def test_only_same_authority_can_be_reclassified(self) -> None:
        old = {"type": "platform_specific", "kind": "add-unpaired-function",
               "identity": "kotlin\0X.kt::f/1#1", "identity_sha256": "hash",
               "platform": "kotlin", "rationale": "Original rationale"}
        current = {**old, "type": "out_of_scope_twin", "twin_path": "Strand/Data/X.swift"}
        self.assertTrue(parity_ratchet._is_out_of_scope_reclassification(old, current))
        self.assertFalse(parity_ratchet._is_out_of_scope_reclassification(
            old, {**current, "identity": "kotlin\0X.kt::g/1#1"}))
        self.assertFalse(parity_ratchet._is_out_of_scope_reclassification(
            old, {**current, "type": "experimental"}))


if __name__ == "__main__":
    unittest.main()
