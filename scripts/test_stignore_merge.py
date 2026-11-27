#!/usr/bin/env python3
"""Stdlib-only unit tests for ``stignore-merge.py``.

Run with::

    python3 scripts/test_stignore_merge.py
"""

from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import os
import stat
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("stignore-merge.py")
_spec = importlib.util.spec_from_file_location("stignore_merge", SCRIPT)
assert _spec is not None and _spec.loader is not None
stignore = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(stignore)


class StignoreMergeTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.target = self.root / ".stignore"

    def run_merge(self, patterns, **kwargs):
        return stignore.merge(self.target, patterns, **kwargs)

    def run_cli(self, *argv):
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = stignore.main(list(argv))
        return code, stdout.getvalue()

    def test_creates_file_with_patterns(self) -> None:
        code = self.run_merge(["node_modules", "/.artifact"])
        self.assertEqual(code, 0)
        self.assertEqual(self.target.read_text(), "node_modules\n/.artifact\n")

    def test_creates_file_with_mode_0644(self) -> None:
        self.run_merge(["node_modules"])
        mode = stat.S_IMODE(os.stat(self.target).st_mode)
        self.assertEqual(mode, 0o644)

    def test_appends_missing_patterns(self) -> None:
        self.target.write_text("node_modules\n")
        self.run_merge(["node_modules", "/.artifact", ".local-artifacts"])
        self.assertEqual(
            self.target.read_text(),
            "node_modules\n/.artifact\n.local-artifacts\n",
        )

    def test_preserves_order_comments_and_blank_lines(self) -> None:
        original = "# host comment\n\nnode_modules\n# tail comment\n"
        self.target.write_text(original)
        self.run_merge(["new-pattern"])
        self.assertEqual(self.target.read_text(), original + "new-pattern\n")

    def test_no_duplicates(self) -> None:
        self.target.write_text("node_modules\n")
        self.run_merge(["node_modules", "node_modules", "other"])
        self.assertEqual(self.target.read_text(), "node_modules\nother\n")

    def test_idempotent_second_run(self) -> None:
        self.run_merge(["node_modules", "/.artifact"])
        first = self.target.read_text()
        self.run_merge(["node_modules", "/.artifact"])
        self.assertEqual(self.target.read_text(), first)

    def test_dry_run_writes_nothing(self) -> None:
        original = "node_modules\n"
        self.target.write_text(original)
        code, output = self.run_cli(
            "--file", str(self.target), "--pattern", "/.artifact", "--dry-run"
        )
        self.assertEqual(code, 0)
        self.assertEqual(self.target.read_text(), original)
        self.assertIn("WOULD APPEND /.artifact", output)

    def test_dry_run_on_absent_file_writes_nothing(self) -> None:
        code, _ = self.run_cli(
            "--file", str(self.target), "--pattern", "node_modules", "--dry-run"
        )
        self.assertEqual(code, 0)
        self.assertFalse(self.target.exists())

    def test_check_exit_zero_when_present(self) -> None:
        self.target.write_text("node_modules\n/.artifact\n")
        code, output = self.run_cli(
            "--file", str(self.target), "--pattern", "node_modules", "--check"
        )
        self.assertEqual(code, 0)
        self.assertEqual(output, "")

    def test_check_exit_one_when_missing(self) -> None:
        self.target.write_text("node_modules\n")
        code, output = self.run_cli(
            "--file", str(self.target), "--pattern", "node_modules",
            "--pattern", "/.artifact", "--check",
        )
        self.assertEqual(code, 1)
        self.assertIn("MISSING /.artifact", output)
        self.assertEqual(self.target.read_text(), "node_modules\n")

    def test_check_exit_one_when_file_absent(self) -> None:
        code, _ = self.run_cli(
            "--file", str(self.target), "--pattern", "node_modules", "--check"
        )
        self.assertEqual(code, 1)
        self.assertFalse(self.target.exists())

    def test_missing_parent_skips_with_zero(self) -> None:
        nested = self.root / "not-synced-yet" / ".stignore"
        code, output = self.run_cli(
            "--file", str(nested), "--pattern", "node_modules"
        )
        self.assertEqual(code, 0)
        self.assertIn("SKIP", output)
        self.assertFalse(nested.parent.exists())

    def test_atomic_replace_leaves_no_temp_file(self) -> None:
        self.target.write_text("node_modules\n")
        self.run_merge(["/.artifact"])
        self.assertEqual(
            sorted(entry.name for entry in self.root.iterdir()), [".stignore"]
        )

    def test_appends_newline_to_unterminated_file(self) -> None:
        self.target.write_text("node_modules")
        self.run_merge(["/.artifact"])
        self.assertEqual(self.target.read_text(), "node_modules\n/.artifact\n")

    def test_empty_file_is_treated_as_absent(self) -> None:
        self.target.write_text("")
        self.run_merge(["node_modules"])
        self.assertEqual(self.target.read_text(), "node_modules\n")

    # --- exact-line semantics -------------------------------------------------

    def test_parent_prefix_present_does_not_cover_deeper_pattern(self) -> None:
        # `foo/bar` must not be considered present just because `foo/bar/baz`
        # starts with it.
        self.target.write_text("foo/bar/baz\n")
        code = self.run_merge(["foo/bar"])
        self.assertEqual(code, 0)
        self.assertEqual(self.target.read_text(), "foo/bar/baz\nfoo/bar\n")

    def test_shorter_present_does_not_cover_longer_pattern(self) -> None:
        self.target.write_text("foo/bar\n")
        code = self.run_merge(["foo/bar/baz"])
        self.assertEqual(code, 0)
        self.assertEqual(self.target.read_text(), "foo/bar\nfoo/bar/baz\n")

    def test_duplicate_requested_pattern_appended_once(self) -> None:
        code = self.run_merge(["dup", "dup"])
        self.assertEqual(code, 0)
        self.assertEqual(self.target.read_text(), "dup\n")

    def test_pattern_with_space_roundtrips(self) -> None:
        code = self.run_merge(["dir with space"])
        self.assertEqual(code, 0)
        self.assertEqual(self.target.read_text(), "dir with space\n")
        check_code, output = self.run_cli(
            "--file", str(self.target), "--pattern", "dir with space", "--check"
        )
        self.assertEqual(check_code, 0)
        self.assertEqual(output, "")

    # --- line endings ---------------------------------------------------------

    def test_crlf_is_preserved_for_appended_lines(self) -> None:
        original = b"node_modules\r\n/.artifact\r\n"
        self.target.write_bytes(original)
        code = self.run_merge(["new-pattern"])
        self.assertEqual(code, 0)
        self.assertEqual(
            self.target.read_bytes(),
            original + b"new-pattern\r\n",
        )

    def test_crlf_unterminated_file_uses_crlf_separator(self) -> None:
        original = b"node_modules\r\n/.artifact"
        self.target.write_bytes(original)
        self.run_merge(["new-pattern"])
        self.assertEqual(
            self.target.read_bytes(),
            original + b"\r\nnew-pattern\r\n",
        )

    def test_lf_file_stays_lf(self) -> None:
        self.target.write_bytes(b"node_modules\n")
        self.run_merge(["new-pattern"])
        self.assertEqual(
            self.target.read_bytes(), b"node_modules\nnew-pattern\n"
        )

    # --- --check edge cases ---------------------------------------------------

    def test_check_on_missing_parent_exits_zero_with_skip(self) -> None:
        nested = self.root / "not-synced-yet" / ".stignore"
        code, output = self.run_cli(
            "--file", str(nested), "--pattern", "node_modules", "--check"
        )
        self.assertEqual(code, 0)
        self.assertIn("SKIP", output)
        self.assertNotIn("MISSING", output)
        self.assertFalse(nested.parent.exists())

    def test_check_does_not_modify_file(self) -> None:
        self.target.write_text("node_modules\n")
        before = hashlib.sha256(self.target.read_bytes()).hexdigest()
        code, output = self.run_cli(
            "--file", str(self.target), "--pattern", "/.artifact", "--check"
        )
        self.assertEqual(code, 1)
        self.assertIn("MISSING /.artifact", output)
        after = hashlib.sha256(self.target.read_bytes()).hexdigest()
        self.assertEqual(before, after)
        self.assertEqual(self.target.read_text(), "node_modules\n")

    # --- symlink alias expansion ---------------------------------------------

    def make_alias_fixture(self) -> Path:
        projects = self.root / "Projects"
        real = projects / "auto-hub"
        (real / "_configs").mkdir(parents=True)
        (real / "_configs" / "Main.yml").write_text(
            "key: value\n", encoding="utf-8"
        )
        alias_root = projects / "--professional" / "Rutube__"
        alias_root.mkdir(parents=True)
        os.symlink("../../auto-hub", alias_root / "AutoHub")
        return projects

    def test_expand_without_projects_root_is_unchanged(self) -> None:
        projects = self.make_alias_fixture()
        pattern = "/--professional/Rutube__/AutoHub/_configs/Main.yml"
        code, output = self.run_cli(
            "--file", str(self.target), "--pattern", pattern, "--dry-run"
        )
        self.assertEqual(code, 0)
        self.assertIn(f"WOULD APPEND {pattern}", output)
        self.assertNotIn("/auto-hub/", output)
        self.assertFalse(self.target.exists())
        self.assertTrue(projects.is_dir())

    def test_expand_real_dir_is_unchanged(self) -> None:
        projects = self.root / "Projects"
        (projects / "Suite" / "_configs").mkdir(parents=True)
        pattern = "/Suite/_configs/Main.yml"
        self.assertEqual(
            stignore.expand_alias_patterns([pattern], str(projects)),
            [pattern],
        )

    def test_expand_alias_adds_real_variant(self) -> None:
        projects = self.make_alias_fixture()
        logical = "/--professional/Rutube__/AutoHub/_configs/Main.yml"
        real = "/auto-hub/_configs/Main.yml"
        self.assertEqual(
            stignore.expand_alias_patterns([logical], str(projects)),
            [logical, real],
        )

    def test_expand_does_not_resolve_the_entry_itself(self) -> None:
        projects = self.make_alias_fixture()
        os.symlink(
            "/nix/store/abc-home-manager-files/_scripts",
            projects / "auto-hub" / "_scripts",
        )
        logical = "/--professional/Rutube__/AutoHub/_scripts"
        expanded = stignore.expand_alias_patterns([logical], str(projects))
        self.assertEqual(expanded, [logical, "/auto-hub/_scripts"])
        self.assertFalse(any("/nix/store/" in p for p in expanded))

    def test_expand_skips_target_outside_root(self) -> None:
        projects = self.root / "Projects"
        outside = self.root / "outside" / "hub"
        (outside / "_scripts").mkdir(parents=True)
        alias_root = projects / "--professional" / "Rutube__"
        alias_root.mkdir(parents=True)
        os.symlink("../../../outside/hub", alias_root / "AutoHub")
        logical = "/--professional/Rutube__/AutoHub/_scripts"
        self.assertEqual(
            stignore.expand_alias_patterns([logical], str(projects)),
            [logical],
        )

    def test_expand_resolves_nested_aliases(self) -> None:
        projects = self.root / "Projects"
        (projects / "auto-hub" / "_scripts").mkdir(parents=True)
        real_rutube = projects / "rutube-real"
        real_rutube.mkdir()
        os.symlink("../auto-hub", real_rutube / "AutoHub")
        professional = projects / "--professional"
        professional.mkdir()
        os.symlink("../rutube-real", professional / "Rutube__")
        logical = "/--professional/Rutube__/AutoHub/_scripts"
        self.assertEqual(
            stignore.expand_alias_patterns([logical], str(projects)),
            [logical, "/auto-hub/_scripts"],
        )

    def test_check_and_dry_run_use_expanded_list(self) -> None:
        projects = self.make_alias_fixture()
        logical = "/--professional/Rutube__/AutoHub/_configs/Main.yml"
        real = "/auto-hub/_configs/Main.yml"
        self.target.write_text(logical + "\n", encoding="utf-8")
        root = ["--projects-root", str(projects)]

        code, output = self.run_cli(
            "--file", str(self.target), "--pattern", logical, *root, "--check"
        )
        self.assertEqual(code, 1)
        self.assertIn(f"MISSING {real}", output)

        code, output = self.run_cli(
            "--file", str(self.target), "--pattern", logical, *root,
            "--dry-run",
        )
        self.assertEqual(code, 0)
        self.assertIn(f"WOULD APPEND {real}", output)
        self.assertEqual(self.target.read_text(), logical + "\n")

        self.target.write_text(logical + "\n" + real + "\n", encoding="utf-8")
        code, output = self.run_cli(
            "--file", str(self.target), "--pattern", logical, *root, "--check"
        )
        self.assertEqual(code, 0)
        self.assertEqual(output, "")


if __name__ == "__main__":
    unittest.main()
