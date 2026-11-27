#!/usr/bin/env python3
"""Stdlib-only unit tests for ``project-configs-salt.py``.

Run with::

    python3 scripts/test_project_configs_salt.py
"""

from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("project-configs-salt.py")
_spec = importlib.util.spec_from_file_location("project_configs_salt", SCRIPT)
assert _spec is not None and _spec.loader is not None
pcs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pcs)


class IgnoreBoundaryGateTests(unittest.TestCase):
    def test_exact_match_passes(self) -> None:
        expected = ["/--professional/Rutube__/AutoHub/_configs/Main.yml"]
        effective = ["/--professional/Rutube__/AutoHub/_configs/Main.yml"]
        self.assertEqual(pcs.check_ignore_boundary(expected, effective), [])

    def test_missing_pattern_fails_closed(self) -> None:
        expected = ["/a/one", "/a/two"]
        effective = ["/a/one"]
        self.assertEqual(pcs.check_ignore_boundary(expected, effective), ["a/two"])

    def test_leading_slash_is_normalised(self) -> None:
        self.assertEqual(pcs.check_ignore_boundary(["a/b"], ["/a/b"]), [])

    def test_comments_and_blank_lines_ignored(self) -> None:
        expected = ["/a"]
        effective = ["", "# comment", "/a"]
        self.assertEqual(pcs.check_ignore_boundary(expected, effective), [])

    def test_no_source_fails_closed(self) -> None:
        with self.assertRaises(pcs.ConfigError) as ctx:
            pcs.verify_ignore_boundary(["/a"], effective_file=None, effective_cmd=None)
        self.assertEqual(ctx.exception.code, pcs.PROJECT_CONFIG_IGNORE_MISSING)

    def test_file_source_is_read(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ignores.txt"
            path.write_text("# comment\n/a/b\n", encoding="utf-8")
            self.assertEqual(
                pcs.verify_ignore_boundary(["/a/b"], effective_file=str(path), effective_cmd=None),
                ["/a/b"],
            )

    def test_write_links_refuses_without_boundary(self) -> None:
        payload = {
            "projects_root": "/tmp/projects",
            "generation_root": "/tmp/generation",
            "syncthing_root": "/tmp/projects",
        }
        with self.assertRaises(pcs.ConfigError) as ctx:
            pcs.write_project_links(payload, [], boundary_verified=False, dry_run=False)
        self.assertEqual(ctx.exception.code, pcs.PROJECT_CONFIG_IGNORE_MISSING)


class MaterialisationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.projects = self.root / "Projects"
        self.generation = self.root / "generation"
        (self.projects / "Suite" / "_configs" / "Nix").mkdir(parents=True)
        (self.projects / "Suite" / "_configs" / "Nix" / "flake.nix").write_text(
            "{}\n", encoding="utf-8"
        )
        (self.projects / "Suite" / "_scripts").mkdir()
        (self.projects / "Suite" / "_scripts" / "run.sh").write_text(
            "#!/bin/sh\necho ok\n", encoding="utf-8"
        )
        (self.projects / "Suite" / "_configs" / "Main.yml").write_text(
            "key: value\n", encoding="utf-8"
        )
        self.payload = {
            "schema_version": 1,
            "syncthing_root": str(self.projects),
            "projects_root": str(self.projects),
            "generation_root": str(self.generation),
            "manifest_path": str(self.root / "state" / "manifest.json"),
            "ignore_patterns": [
                "/Suite/_configs/Main.yml",
                "/Suite/_configs/Nix",
                "/Suite/_scripts",
                "/Suite/.envrc",
            ],
            "entries": [
                {
                    "logical": "Suite/_configs/Main.yml",
                    "kind": "file",
                    "source": str(self.projects / "Suite" / "_configs" / "Main.yml"),
                },
                {
                    "logical": "Suite/_configs/Nix",
                    "kind": "dir",
                    "source": str(self.projects / "Suite" / "_configs" / "Nix"),
                },
                {
                    "logical": "Suite/_scripts",
                    "kind": "dir",
                    "source": str(self.projects / "Suite" / "_scripts"),
                },
                {
                    "logical": "Suite/.envrc",
                    "kind": "text",
                    "text": "echo envrc\n",
                },
            ],
        }

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_materialises_real_dereferenced_files(self) -> None:
        entries = pcs.materialise(self.payload, dry_run=False)
        self.assertEqual(len(entries), 4)

        generation = self.generation / "Projects"
        self.assertEqual(
            (generation / "Suite" / ".envrc").read_text(encoding="utf-8"),
            "echo envrc\n",
        )
        self.assertEqual(
            (generation / "Suite" / "_configs" / "Main.yml").read_text(encoding="utf-8"),
            "key: value\n",
        )
        # No symlinks anywhere in the generated subtree.
        for dirpath, dirnames, filenames in os.walk(self.generation):
            for name in dirnames + filenames:
                self.assertFalse(os.path.islink(os.path.join(dirpath, name)))

        # Directory hashes are deterministic.
        self.assertEqual(
            pcs.sha256_tree(str(generation / "Suite" / "_scripts")),
            pcs.sha256_tree(str(generation / "Suite" / "_scripts")),
        )

    def test_manifest_check_and_stale_detection(self) -> None:
        entries = pcs.materialise(self.payload, dry_run=False)
        manifest = pcs.build_manifest(
            self.payload,
            entries,
            ignore_patterns=self.payload["ignore_patterns"],
            ignore_boundary_verified=True,
            project_links=[],
        )
        pcs.write_manifest(self.payload["manifest_path"], manifest, dry_run=False)
        pcs.check_manifest(self.payload["manifest_path"], require_ignore=False, payload=self.payload)

        victim = self.generation / "Projects" / "Suite" / "_configs" / "Main.yml"
        victim.write_text("tampered\n", encoding="utf-8")
        with self.assertRaises(pcs.ConfigError) as ctx:
            pcs.check_manifest(self.payload["manifest_path"], require_ignore=False, payload=self.payload)
        self.assertEqual(ctx.exception.code, pcs.PROJECT_CONFIG_STALE)

    def test_dangling_source_symlink_fails(self) -> None:
        link = self.projects / "Suite" / "_configs" / "Main.yml"
        link.unlink()
        os.symlink("/nonexistent/target.yml", link)
        with self.assertRaises(pcs.ConfigError) as ctx:
            pcs.materialise(self.payload, dry_run=False)
        self.assertEqual(ctx.exception.code, pcs.PROJECT_CONFIG_LINK_MISSING)

    def test_prunes_stale_generated_paths(self) -> None:
        pcs.materialise(self.payload, dry_run=False)
        stale = self.generation / "Projects" / "Suite" / "obsolete.yml"
        stale.write_text("old\n", encoding="utf-8")
        pcs.materialise(self.payload, dry_run=False)
        self.assertFalse(stale.exists())

    def test_replaces_regular_file_project_path(self) -> None:
        # Replace one generated path with a real file, as if it were synced source.
        project_path = self.projects / "Suite" / "_configs" / "Main.yml"
        project_path.write_text("real source\n", encoding="utf-8")
        pcs.materialise(self.payload, dry_run=False)
        written = pcs.write_project_links(
            self.payload, self.payload["entries"], boundary_verified=True, dry_run=False
        )
        self.assertTrue(project_path.is_symlink())
        self.assertEqual(
            Path(os.readlink(project_path)),
            self.generation / "Projects" / "Suite" / "_configs" / "Main.yml",
        )
        entry = next(item for item in written if item["logical"] == "Suite/_configs/Main.yml")
        self.assertEqual(entry["kind"], "file")
        self.assertEqual(len(entry["sha256"]), 64)

    def test_replaces_identical_directory_project_path(self) -> None:
        project_dir = self.projects / "Suite" / "_configs" / "Nix"
        pcs.materialise(self.payload, dry_run=False)
        pcs.write_project_links(
            self.payload, self.payload["entries"], boundary_verified=True, dry_run=False
        )
        self.assertTrue(project_dir.is_symlink())
        self.assertEqual(
            Path(os.readlink(project_dir)),
            self.generation / "Projects" / "Suite" / "_configs" / "Nix",
        )

    def test_refuses_differing_directory_and_changes_nothing(self) -> None:
        project_dir = self.projects / "Suite" / "_configs" / "Nix"
        main_file = self.projects / "Suite" / "_configs" / "Main.yml"
        pcs.materialise(self.payload, dry_run=False)
        (project_dir / "extra.txt").write_text("already-synced drift\n", encoding="utf-8")

        with self.assertRaises(pcs.ConfigError) as ctx:
            pcs.write_project_links(
                self.payload, self.payload["entries"], boundary_verified=True, dry_run=False
            )
        self.assertEqual(ctx.exception.code, pcs.PROJECT_CONFIG_STALE)
        # Nothing in the covered set was replaced: the run aborted before writing.
        self.assertFalse(project_dir.is_symlink())
        self.assertTrue(project_dir.is_dir())
        self.assertFalse(main_file.is_symlink())
        self.assertFalse((self.projects / "Suite" / ".envrc").exists())

    def test_force_replace_overrides_differing_directory(self) -> None:
        project_dir = self.projects / "Suite" / "_configs" / "Nix"
        pcs.materialise(self.payload, dry_run=False)
        (project_dir / "extra.txt").write_text("already-synced drift\n", encoding="utf-8")

        pcs.write_project_links(
            self.payload,
            self.payload["entries"],
            boundary_verified=True,
            dry_run=False,
            force_replace=True,
        )
        self.assertTrue(project_dir.is_symlink())

    def test_second_write_run_is_idempotent(self) -> None:
        pcs.materialise(self.payload, dry_run=False)
        pcs.write_project_links(
            self.payload, self.payload["entries"], boundary_verified=True, dry_run=False
        )
        before = {
            logical: os.readlink(project_path)
            for logical, project_path, _target in pcs.project_link_paths(
                self.payload, self.payload["entries"]
            )
        }
        written = pcs.write_project_links(
            self.payload, self.payload["entries"], boundary_verified=True, dry_run=False
        )
        after = {
            logical: os.readlink(project_path)
            for logical, project_path, _target in pcs.project_link_paths(
                self.payload, self.payload["entries"]
            )
        }
        self.assertEqual(before, after)
        self.assertEqual(len(written), len(self.payload["entries"]))

    def test_check_reports_link_drift_without_writing(self) -> None:
        entries = pcs.materialise(self.payload, dry_run=False)
        manifest = pcs.build_manifest(
            self.payload,
            entries,
            ignore_patterns=self.payload["ignore_patterns"],
            ignore_boundary_verified=True,
            project_links=[],
        )
        pcs.write_manifest(self.payload["manifest_path"], manifest, dry_run=False)
        payload_path = self.root / "payload.json"
        payload_path.write_text(json.dumps(self.payload), encoding="utf-8")
        main_file = self.projects / "Suite" / "_configs" / "Main.yml"

        code = pcs.main(["--input", str(payload_path), "--check"])

        self.assertEqual(code, 1)
        self.assertFalse(main_file.is_symlink())
        self.assertFalse((self.projects / "Suite" / ".envrc").exists())

        pcs.write_project_links(
            self.payload, self.payload["entries"], boundary_verified=True, dry_run=False
        )
        links = pcs.write_project_links(
            self.payload, self.payload["entries"], boundary_verified=True, dry_run=False
        )
        manifest = pcs.build_manifest(
            self.payload,
            entries,
            ignore_patterns=self.payload["ignore_patterns"],
            ignore_boundary_verified=True,
            project_links=links,
        )
        pcs.write_manifest(self.payload["manifest_path"], manifest, dry_run=False)
        self.assertEqual(pcs.main(["--input", str(payload_path), "--check"]), 0)

    def test_write_links_gate_runs_before_any_replacement(self) -> None:
        main_file = self.projects / "Suite" / "_configs" / "Main.yml"
        payload_path = self.root / "payload.json"
        payload_path.write_text(json.dumps(self.payload), encoding="utf-8")
        ignores = self.root / "ignores.txt"
        ignores.write_text("# no generated patterns yet\n", encoding="utf-8")

        code = pcs.main(
            [
                "--input",
                str(payload_path),
                "--write-links",
                "--effective-ignore-file",
                str(ignores),
            ]
        )

        self.assertEqual(code, 1)
        self.assertFalse(main_file.is_symlink())
        self.assertFalse((self.projects / "Suite" / ".envrc").exists())
        self.assertFalse((self.generation / "Projects").exists())


class DiscoveryTests(unittest.TestCase):
    def test_absolute_relative_and_neutral_links(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Projects"
            (root / "Suite").mkdir(parents=True)
            os.symlink("/nix/store/abc-home-manager-files/x", root / "Suite" / "abs-link")
            os.symlink("Main.yml", root / "Suite" / "rel-link")
            os.symlink("/shared/archive/x", root / "Suite" / "neutral-link")
            gitdir = root / "Suite" / "AutoHub.git" / ".git" / "info"
            gitdir.mkdir(parents=True)
            os.symlink("/nix/store/abc-home-manager-files/exclude", gitdir / "exclude")
            (root / "Suite" / "AutoHub.git" / "regular").write_text("x", encoding="utf-8")

            patterns = pcs.discover_ignore_patterns(str(root))
            self.assertEqual(
                patterns,
                [
                    "/Suite/AutoHub.git/.git/info/exclude",
                    "/Suite/abs-link",
                ],
            )

    def test_host_state_patterns_are_classified(self) -> None:
        self.assertTrue(pcs.is_host_state_pattern("/Suite/.direnv/flake-profile"))
        self.assertTrue(pcs.is_host_state_pattern("/Suite/nix-shell-env/bin"))
        self.assertFalse(pcs.is_host_state_pattern("/Suite/_scripts"))

    def test_skips_top_level_artifact_roots(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Projects"
            (root / ".artifact").mkdir(parents=True)
            os.symlink("/nix/store/x", root / ".artifact" / "link")
            (root / "ai-").mkdir()
            os.symlink("/nix/store/y", root / "ai-" / "link")
            self.assertEqual(pcs.discover_ignore_patterns(str(root)), [])


class PayloadValidationTests(unittest.TestCase):
    def test_unsafe_logical_path_rejected(self) -> None:
        with self.assertRaises(pcs.ConfigError):
            pcs.sanitize_relative("../escape", "test")

    def test_absolute_logical_path_rejected(self) -> None:
        with self.assertRaises(pcs.ConfigError):
            pcs.sanitize_relative("/abs", "test")


if __name__ == "__main__":
    unittest.main(verbosity=2)
