#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHANGELOGS = {
    "fr": ROOT / "CHANGELOG.fr.md",
    "en": ROOT / "CHANGELOG.md",
}
REQUIRED_SECTIONS = {
    "fr": ("Pourquoi mettre à jour ?", "Changements", "Impact et migration"),
    "en": ("Why upgrade?", "Changes", "Impact and migration"),
}
ENTRY = re.compile(
    r"^## \[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2})[ \t]*$",
    re.MULTILINE,
)


@dataclass(frozen=True)
class ReleaseNote:
    version: str
    date: str
    body: str


def read_entries(path: Path, locale: str) -> list[ReleaseNote]:
    source = path.read_text(encoding="utf-8")
    matches = list(ENTRY.finditer(source))
    if not matches:
        raise ValueError(f"{path.name} contains no release entry")

    entries: list[ReleaseNote] = []
    seen: set[str] = set()
    previous: tuple[int, int, int] | None = None
    for index, match in enumerate(matches):
        version, date = match.groups()
        if version in seen:
            raise ValueError(f"{path.name} repeats version {version}")
        seen.add(version)
        try:
            dt.date.fromisoformat(date)
        except ValueError as error:
            raise ValueError(f"{path.name} has an invalid date for {version}") from error

        semantic_version = tuple(int(part) for part in version.split("."))
        if previous is not None and semantic_version >= previous:
            raise ValueError(f"{path.name} entries must use descending semantic versions")
        previous = semantic_version

        end = matches[index + 1].start() if index + 1 < len(matches) else len(source)
        body = source[match.end():end].strip()
        validate_sections(path, locale, version, body)
        entries.append(ReleaseNote(version, date, body))

    return entries


def validate_sections(path: Path, locale: str, version: str, body: str) -> None:
    headings = list(re.finditer(r"^### (.+?)[ \t]*$", body, re.MULTILINE))
    actual = tuple(match.group(1) for match in headings)
    expected = REQUIRED_SECTIONS[locale]
    if actual != expected:
        raise ValueError(
            f"{path.name} {version} must contain exactly these sections: "
            + ", ".join(expected)
        )

    for index, heading in enumerate(headings):
        end = headings[index + 1].start() if index + 1 < len(headings) else len(body)
        content = body[heading.end():end].strip()
        if not content:
            raise ValueError(f"{path.name} {version} section '{heading.group(1)}' is empty")


def validated_changelogs(version: str) -> dict[str, list[ReleaseNote]]:
    entries = {
        locale: read_entries(path, locale)
        for locale, path in CHANGELOGS.items()
    }
    french_identity = [(entry.version, entry.date) for entry in entries["fr"]]
    english_identity = [(entry.version, entry.date) for entry in entries["en"]]
    if french_identity != english_identity:
        raise ValueError("French and English release inventories differ")
    if entries["fr"][0].version != version:
        raise ValueError(f"the newest release note must be {version}")
    return entries


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate and extract canonical Silex release notes")
    subparsers = parser.add_subparsers(dest="command", required=True)
    validate = subparsers.add_parser("validate")
    validate.add_argument("version")
    extract = subparsers.add_parser("extract")
    extract.add_argument("version")
    extract.add_argument("--locale", choices=tuple(CHANGELOGS), default="en")
    arguments = parser.parse_args()

    entries = validated_changelogs(arguments.version)
    if arguments.command == "extract":
        note = next(entry for entry in entries[arguments.locale] if entry.version == arguments.version)
        print(note.body)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        raise SystemExit(f"release notes: {error}") from error
