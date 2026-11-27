#!/usr/bin/env python3
"""Boundary tests for symlink-aware ignore expansion.

Covers :func:`project_configs_salt.expand_alias_patterns` and the gate paths
that must compare the expanded list while still failing closed when the real
location is not ignored.

Run with::

    python3 scripts/test_project_configs_salt_boundary.py
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("project-configs-salt.py")
_spec = importlib.util.spec_from_file_location("project_configs_salt_b", SCRIPT)
assert _spec is not None and _spec.loader is not None
pcs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pcs)

LOGICAL = "/--professional/Rutube__/AutoHub/_scripts"
REAL = "/auto-hub/_scripts"


class AliasFixture:
    """Temporary synced root with a real tree and an alias symlink."""

    def __init__(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name) / "Projects"
        self.real = self.root / "auto-hub"
        self.real.mkdir(parents=True)
        alias_root = self.root / "--professional" / "Rutube__"
        alias_root.mkdir(parents=True)
        os.symlink("../../auto-hub", alias_root / "AutoHub")

    def cleanup(self) -> None:
        self._tmp.cleanup()


class ExpansionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = AliasFixture()
        self.addCleanup(self.fixture.cleanup)

    def test_expands_logical_pattern_to_real_location(self) -> None:
        self.assertEqual(
            pcs.expand_alias_patterns(
                [LOGICAL], str(self.fixture.root)
            ),
            [LOGICAL, REAL],
        )

    def test_entry_symlink_is_not_resolved(self) -> None:
        os.symlink(
            "/nix/store/abc-home-manager-files/_scripts",
            self.fixture.real / "_scripts",
        )
        expanded = pcs.expand_alias_patterns(
            [LOGICAL], str(self.fixture.root)
        )
        self.assertEqual(expanded, [LOGICAL, REAL])
        self.assertFalse(any("/nix/store/" in p for p in expanded))

    def test_non_anchored_patterns_are_untouched(self) -> None:
        self.assertEqual(
            pcs.expand_alias_patterns(
                ["node_modules", "/.artifact"], str(self.fixture.root)
            ),
            ["node_modules", "/.artifact"],
        )


class FallbackTests(unittest.TestCase):
    def expand(self, root: str | None) -> tuple[list[str], str]:
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            expanded = pcs.expand_expected_patterns([LOGICAL], root)
        return expanded, stderr.getvalue()

    def test_missing_root_falls_back_with_diagnostic(self) -> None:
        expanded, diagnostic = self.expand(None)
        self.assertEqual(expanded, [LOGICAL])
        self.assertIn("logical patterns only", diagnostic)

    def test_nonexistent_root_falls_back_with_diagnostic(self) -> None:
        expanded, diagnostic = self.expand("/nonexistent/Projects")
        self.assertEqual(expanded, [LOGICAL])
        self.assertIn("does not exist", diagnostic)

    def test_existing_root_expands(self) -> None:
        fixture = AliasFixture()
        self.addCleanup(fixture.cleanup)
        expanded, diagnostic = self.expand(str(fixture.root))
        self.assertEqual(expanded, [LOGICAL, REAL])
        self.assertEqual(diagnostic, "")


class BoundaryGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = AliasFixture()
        self.addCleanup(self.fixture.cleanup)
        self.ignores = Path(self.fixture._tmp.name) / "ignores.txt"

    def gate(self, lines: list[str]) -> list[str]:
        self.ignores.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return pcs.verify_ignore_boundary(
            pcs.expand_expected_patterns(
                [LOGICAL], str(self.fixture.root)
            ),
            effective_file=str(self.ignores),
            effective_cmd=None,
        )

    def test_passes_when_both_variants_are_present(self) -> None:
        effective = self.gate([LOGICAL, REAL])
        self.assertIn(LOGICAL, effective)
        self.assertIn(REAL, effective)

    def test_fails_closed_when_real_variant_is_missing(self) -> None:
        with self.assertRaises(pcs.ConfigError) as ctx:
            self.gate([LOGICAL])
        self.assertEqual(
            ctx.exception.code, pcs.PROJECT_CONFIG_IGNORE_MISSING
        )
        self.assertIn(REAL.lstrip("/"), ctx.exception.message)

    def test_fails_closed_when_logical_variant_is_missing(self) -> None:
        with self.assertRaises(pcs.ConfigError) as ctx:
            self.gate([REAL])
        self.assertEqual(
            ctx.exception.code, pcs.PROJECT_CONFIG_IGNORE_MISSING
        )


class ManifestBoundaryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = AliasFixture()
        self.addCleanup(self.fixture.cleanup)
        self.generation = Path(self.fixture._tmp.name) / "generation"
        self.generation.mkdir()
        self.manifest_path = (
            Path(self.fixture._tmp.name) / "manifest.json"
        )
        os.symlink(
            "/nix/store/abc-home-manager-files/_scripts",
            self.fixture.real / "_scripts",
        )

    def write_manifest(self) -> None:
        manifest = {
            "schema_version": pcs.SCHEMA_VERSION,
            "generation_root": str(self.generation),
            "syncthing_root": str(self.fixture.root),
            "projects_root": str(self.fixture.root),
            "entries": [],
            "ignore_patterns": [LOGICAL],
            "project_links": [],
        }
        self.manifest_path.write_text(
            json.dumps(manifest), encoding="utf-8"
        )

    def test_discovered_real_path_is_covered_by_expansion(self) -> None:
        self.write_manifest()
        pcs.check_manifest(
            str(self.manifest_path),
            require_ignore=True,
            payload=None,
        )

    def test_unexpected_real_path_still_fails_closed(self) -> None:
        self.write_manifest()
        os.symlink(
            "/nix/store/abc-home-manager-files/extra",
            self.fixture.real / "extra",
        )
        with self.assertRaises(pcs.ConfigError) as ctx:
            pcs.check_manifest(
                str(self.manifest_path),
                require_ignore=True,
                payload=None,
            )
        self.assertEqual(
            ctx.exception.code, pcs.PROJECT_CONFIG_IGNORE_MISSING
        )
        self.assertIn("/auto-hub/extra", ctx.exception.message)


if __name__ == "__main__":
    unittest.main(verbosity=2)
