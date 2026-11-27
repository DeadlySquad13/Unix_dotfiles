#!/usr/bin/env python3
"""Stdlib-only unit tests for ``stignore-syncthing-e2e.py``.

No config discovery, no network: every case drives the pure comparison
functions or the offline payload loader.

Run with::

    python3 scripts/test_stignore_syncthing_e2e.py
"""

from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("stignore-syncthing-e2e.py")
_spec = importlib.util.spec_from_file_location("stignore_e2e", SCRIPT)
assert _spec is not None and _spec.loader is not None
e2e = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(e2e)


def expanded_for(patterns) -> list[str]:
    forms: list[str] = []
    for pattern in patterns:
        forms.extend(e2e.expected_expanded(pattern))
    return forms


def codes(report) -> list[str]:
    return [entry["code"] for entry in report.errors]


class CompareTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)

    def test_exact_match_anchored_and_unanchored_passes(self) -> None:
        patterns = ["node_modules", "/.artifact"]
        report = e2e.compare(
            patterns,
            patterns,
            expanded_for(patterns),
            str(self.root),
        )
        self.assertTrue(report.ok)
        self.assertEqual(report.errors, [])
        self.assertEqual(report.warnings, [])
        self.assertEqual(report.counts["file_patterns"], 2)

    def test_file_line_missing_from_api(self) -> None:
        patterns = ["node_modules", "/.artifact"]
        report = e2e.compare(
            patterns,
            ["node_modules"],
            expanded_for(patterns),
            str(self.root),
        )
        self.assertFalse(report.ok)
        self.assertIn("MISSING_FROM_API", codes(report))

    def test_api_extra_is_warning_by_default(self) -> None:
        patterns = ["node_modules"]
        report = e2e.compare(
            patterns,
            ["node_modules", "extra"],
            expanded_for(["node_modules", "extra"]),
            str(self.root),
        )
        self.assertTrue(report.ok)
        self.assertEqual(report.errors, [])
        self.assertIn("EXTRA_IN_API", [w["code"] for w in report.warnings])

    def test_api_extra_is_error_with_strict(self) -> None:
        patterns = ["node_modules"]
        report = e2e.compare(
            patterns,
            ["node_modules", "extra"],
            expanded_for(["node_modules", "extra"]),
            str(self.root),
            strict=True,
        )
        self.assertFalse(report.ok)
        self.assertIn("EXTRA_IN_API", codes(report))

    def test_missing_dir_expansion(self) -> None:
        report = e2e.compare(
            ["/.artifact"],
            ["/.artifact"],
            ["(?i)/.artifact"],
            str(self.root),
        )
        self.assertFalse(report.ok)
        self.assertEqual(codes(report).count("MISSING_EXPANDED"), 1)
        self.assertIn("(?i)/.artifact/**", report.errors[0]["message"])

    def test_unanchored_requires_all_four_expansions(self) -> None:
        report = e2e.compare(
            ["node_modules"],
            ["node_modules"],
            ["(?i)node_modules"],
            str(self.root),
        )
        self.assertEqual(codes(report).count("MISSING_EXPANDED"), 3)
        missing = {entry["message"] for entry in report.errors}
        self.assertTrue(any("(?i)**/node_modules'" in m for m in missing))
        self.assertTrue(any("(?i)node_modules/**" in m for m in missing))
        self.assertTrue(any("(?i)**/node_modules/**" in m for m in missing))

    def test_uppercase_pattern_matches_lowercase_forms(self) -> None:
        patterns = ["Node_Modules", "/.Artifact"]
        report = e2e.compare(
            patterns,
            patterns,
            expanded_for(patterns),
            str(self.root),
        )
        self.assertTrue(report.ok)
        self.assertEqual(report.errors, [])

    def test_comments_and_blank_lines_are_ignored(self) -> None:
        target = self.root / ".stignore"
        target.write_text(
            "// a comment\n\n  node_modules  \n"
            "// another\n  /.artifact\n",
            encoding="utf-8",
        )
        self.assertEqual(
            e2e.load_stignore(target), ["node_modules", "/.artifact"]
        )


class AliasTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.projects = self.root / "Projects"
        (self.projects / "auto-hub" / "_scripts").mkdir(parents=True)
        alias_root = self.projects / "--professional" / "Rutube__"
        alias_root.mkdir(parents=True)
        os.symlink("../../auto-hub", alias_root / "AutoHub")
        self.logical = "/--professional/Rutube__/AutoHub/_scripts"
        self.real = "/auto-hub/_scripts"

    def test_alias_without_real_variant_errors(self) -> None:
        report = e2e.compare(
            [self.logical],
            [self.logical],
            expanded_for([self.logical]),
            str(self.projects),
        )
        self.assertFalse(report.ok)
        self.assertIn("MISSING_REAL_VARIANT", codes(report))
        message = report.errors[0]["message"]
        self.assertIn(self.logical, message)
        self.assertIn(self.real, message)

    def test_alias_with_real_variant_passes(self) -> None:
        ignore = [self.logical, self.real]
        expanded = expanded_for([self.logical, self.real])
        report = e2e.compare(
            ignore,
            ignore,
            expanded,
            str(self.projects),
        )
        self.assertTrue(report.ok)
        self.assertEqual(report.errors, [])

    def test_alias_absent_requires_no_real_variant(self) -> None:
        pattern = "/plain/_scripts"
        (self.projects / "plain" / "_scripts").mkdir(parents=True)
        report = e2e.compare(
            [pattern],
            [pattern],
            expanded_for([pattern]),
            str(self.projects),
        )
        self.assertTrue(report.ok)
        self.assertEqual(report.errors, [])

    def test_real_variant_helper(self) -> None:
        self.assertEqual(
            e2e.real_variant(self.logical, str(self.projects)),
            self.real,
        )
        self.assertIsNone(
            e2e.real_variant("/auto-hub/_scripts", str(self.projects))
        )


class HostConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)

    def write_config(self, address, tls="false") -> Path:
        path = self.root / "config.xml"
        path.write_text(
            "<configuration><gui apikey=\"secret\" "
            f"address=\"{address}\" tls=\"{tls}\" /></configuration>",
            encoding="utf-8",
        )
        return path

    def test_parse_config_tcp_tls(self) -> None:
        path = self.write_config("127.0.0.1:8384", tls="true")
        config = e2e.parse_config(path)
        self.assertEqual(config["api_key"], "secret")
        self.assertEqual(config["address"], "127.0.0.1:8384")
        self.assertTrue(config["tls"])
        endpoint = e2e._endpoint(config)
        self.assertEqual(endpoint["base"], "https://127.0.0.1:8384")
        self.assertIsNone(endpoint["socket"])
        self.assertTrue(endpoint["tls"])

    def test_endpoint_wildcard_maps_to_loopback(self) -> None:
        endpoint = e2e._endpoint(
            {"address": "0.0.0.0:8384", "tls": False}
        )
        self.assertEqual(endpoint["base"], "http://127.0.0.1:8384")

    def test_endpoint_unix_socket(self) -> None:
        endpoint = e2e._endpoint(
            {"address": "unix:///run/syncthing.sock", "tls": True}
        )
        self.assertIsNone(endpoint["base"])
        self.assertEqual(endpoint["socket"], "/run/syncthing.sock")
        self.assertFalse(endpoint["tls"])

    def test_parse_paths_output_same_line(self) -> None:
        text = "Configuration file: /home/u/.config/syncthing/config.xml\n"
        self.assertEqual(
            e2e._parse_paths_output(text),
            "/home/u/.config/syncthing/config.xml",
        )

    def test_parse_paths_output_next_line(self) -> None:
        text = (
            "Configuration file:\n"
            "\t/home/u/.local/state/syncthing/config.xml\n"
            "Data directory:\n"
            "\t/home/u/.local/state/syncthing\n"
        )
        self.assertEqual(
            e2e._parse_paths_output(text),
            "/home/u/.local/state/syncthing/config.xml",
        )


class PayloadTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)

    def test_payload_file_round_trip(self) -> None:
        patterns = ["node_modules", "/.artifact"]
        payload = {
            "ignores": {
                "ignore": patterns,
                "expanded": expanded_for(patterns),
            },
            "folders": [{"id": "xtnmf-9ntus", "path": str(self.root)}],
        }
        fixture = self.root / "payload.json"
        fixture.write_text(json.dumps(payload), encoding="utf-8")

        loaded = e2e.load_payload(fixture)
        folder = e2e.folder_path_from(loaded["folders"], "xtnmf-9ntus")
        self.assertEqual(folder, str(self.root))

        ignores = loaded["ignores"]
        report = e2e.compare(
            patterns,
            ignores["ignore"],
            ignores["expanded"],
            folder,
        )
        self.assertTrue(report.ok)

    def test_raw_ignores_object_shape(self) -> None:
        payload = {
            "ignore": ["node_modules"],
            "expanded": expanded_for(["node_modules"]),
        }
        fixture = self.root / "raw.json"
        fixture.write_text(json.dumps(payload), encoding="utf-8")
        loaded = e2e.load_payload(fixture)
        self.assertEqual(loaded["folders"], [])
        self.assertEqual(loaded["ignores"]["ignore"], ["node_modules"])


if __name__ == "__main__":
    unittest.main()
