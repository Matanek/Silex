#!/usr/bin/env python3
"""Exercise release readiness independently of the repository's current version."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
script = Path(__file__).resolve().parents[2] / ".github/scripts/release-notes.py"
spec = importlib.util.spec_from_file_location("release_notes", script)
notes = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = notes
spec.loader.exec_module(notes)


class ReleaseNotesTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.paths = {locale: Path(self.directory.name) / f"{locale}.md" for locale in ("fr", "en")}
        for locale, path in self.paths.items():
            body = "\n\n".join(f"### {heading}\n\nA verified change." for heading in notes.REQUIRED_SECTIONS[locale])
            path.write_text(f"# Notes\n\n## [0.47.0] - 2026-09-24\n\n{body}\n", encoding="utf-8")
        self.override = patch.object(notes, "CHANGELOGS", self.paths)
        self.override.start()
        self.addCleanup(self.override.stop)

    def test_ready_bilingual_release(self):
        self.assertEqual(notes.validated_changelogs("0.47.0")["fr"][0].version, "0.47.0")

    def test_pending_notes_cannot_be_silently_omitted(self):
        path = self.paths["fr"]
        path.write_text("## [Unreleased]\n\nA missing change.\n\n" + path.read_text(), encoding="utf-8")
        # The reader can list published notes while development continues.
        self.assertEqual(len(notes.read_entries(path, "fr")), 1)
        with self.assertRaisesRegex(ValueError, "pending Unreleased"):
            notes.validated_changelogs("0.47.0")

    def test_translation_inventory_must_match(self):
        path = self.paths["en"]
        path.write_text(path.read_text().replace("2026-09-24", "2026-09-23"), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "inventories differ"):
            notes.validated_changelogs("0.47.0")

    def test_stale_version_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "newest release note"):
            notes.validated_changelogs("0.48.0")

    def test_empty_migration_section_is_rejected(self):
        path = self.paths["en"]
        source = path.read_text()
        path.write_text(source[:source.rfind("A verified change.")], encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "is empty"):
            notes.validated_changelogs("0.47.0")


if __name__ == "__main__":
    unittest.main()
