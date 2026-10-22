#!/usr/bin/env python3
"""Validate local documentation links and bilingual executable examples."""

from __future__ import annotations

import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parent.parent
ROOT_PAIRS = [
    ("README.md", "README.zh-CN.md"),
    ("CONTRIBUTING.md", "CONTRIBUTING.zh-CN.md"),
    ("CHANGELOG.md", "CHANGELOG.zh-CN.md"),
]
EXECUTABLE_FENCES = {"bash", "sh", "shell", "swift", "text"}
FENCE_PATTERN = re.compile(r"^```([^\n]*)\n(.*?)^```[ \t]*$", re.MULTILINE | re.DOTALL)
MARKDOWN_LINK_PATTERN = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
HTML_LINK_PATTERN = re.compile(
    r"<(?:a|img)\b[^>]*\b(?:href|src)=[\"']([^\"']+)[\"']", re.IGNORECASE
)
HEADING_PATTERN = re.compile(r"^#{1,6}\s+(.+?)\s*$", re.MULTILINE)


def markdown_files() -> list[Path]:
    root_names = (
        "README.md",
        "README.zh-CN.md",
        "CONTRIBUTING.md",
        "CONTRIBUTING.zh-CN.md",
        "CHANGELOG.md",
        "CHANGELOG.zh-CN.md",
    )
    roots = [ROOT / name for name in root_names]
    english_guides = sorted((ROOT / "docs").glob("*.md"))
    chinese_guides = sorted((ROOT / "docs/zh-CN").glob("*.md"))
    return roots + english_guides + chinese_guides


def bilingual_pairs() -> list[tuple[str, str]]:
    english_guides = {path.name for path in (ROOT / "docs").glob("*.md")}
    chinese_guides = {path.name for path in (ROOT / "docs/zh-CN").glob("*.md")}
    guide_names = sorted(english_guides | chinese_guides)
    return ROOT_PAIRS + [(f"docs/{name}", f"docs/zh-CN/{name}") for name in guide_names]


def without_fences(text: str) -> str:
    return FENCE_PATTERN.sub(lambda match: "\n" * match.group(0).count("\n"), text)


def github_slug(value: str) -> str:
    value = re.sub(r"<[^>]+>", "", value).strip().casefold()
    value = re.sub(r"[`*_~]", "", value)
    result: list[str] = []
    for character in value:
        category = unicodedata.category(character)
        if character in {"-", "_"} or category[0] in {"L", "N"}:
            result.append(character)
        elif character.isspace():
            result.append("-")
    return re.sub(r"-+", "-", "".join(result)).strip("-")


def heading_anchors(text: str) -> set[str]:
    anchors: set[str] = set()
    counts: dict[str, int] = {}
    for match in HEADING_PATTERN.finditer(without_fences(text)):
        base = github_slug(match.group(1))
        count = counts.get(base, 0)
        counts[base] = count + 1
        anchors.add(base if count == 0 else f"{base}-{count}")
    return anchors


def local_targets(path: Path, text: str) -> list[tuple[int, str]]:
    content = without_fences(text)
    matches = list(MARKDOWN_LINK_PATTERN.finditer(content)) + list(HTML_LINK_PATTERN.finditer(content))
    targets = ((content.count("\n", 0, match.start()) + 1, match.group(1)) for match in matches)
    return sorted(targets, key=lambda item: item[0])


def split_target(raw_target: str) -> tuple[str, str]:
    target = raw_target.strip()
    if target.startswith("<") and ">" in target:
        target = target[1 : target.index(">")]
    else:
        target = target.split(maxsplit=1)[0]
    path, separator, fragment = target.partition("#")
    return unquote(path), unquote(fragment) if separator else ""


def executable_blocks(text: str) -> list[tuple[str, str]]:
    blocks: list[tuple[str, str]] = []
    for match in FENCE_PATTERN.finditer(text):
        language = match.group(1).strip().split(maxsplit=1)[0].casefold()
        if language in EXECUTABLE_FENCES:
            blocks.append((language, match.group(2).rstrip()))
    return blocks


def main() -> int:
    errors: list[str] = []
    files = markdown_files()
    pairs = bilingual_pairs()
    contents = {path: path.read_text(encoding="utf-8") for path in files}
    anchors = {path: heading_anchors(text) for path, text in contents.items()}

    for path, text in contents.items():
        for line, raw_target in local_targets(path, text):
            if raw_target.startswith(("http://", "https://", "mailto:")):
                continue
            target_path, fragment = split_target(raw_target)
            destination = (path.parent / target_path).resolve() if target_path else path
            label = f"{path.relative_to(ROOT)}:{line}"
            if not destination.is_relative_to(ROOT):
                errors.append(f"{label}: local target leaves the repository: {raw_target}")
                continue
            if not destination.exists():
                errors.append(f"{label}: missing local target {raw_target}")
                continue
            if fragment and destination.suffix.casefold() == ".md":
                destination_anchors = anchors.get(destination)
                if destination_anchors is None:
                    destination_anchors = heading_anchors(destination.read_text(encoding="utf-8"))
                if github_slug(fragment) not in destination_anchors:
                    errors.append(f"{label}: missing heading #{fragment} in {destination.relative_to(ROOT)}")

    for english_name, chinese_name in pairs:
        english = ROOT / english_name
        chinese = ROOT / chinese_name
        if not english.exists() or not chinese.exists():
            errors.append(f"missing bilingual pair: {english_name} <-> {chinese_name}")
            continue
        english_links = {
            (english.parent / split_target(target)[0]).resolve()
            for _, target in local_targets(english, contents[english])
            if not target.startswith(("http://", "https://", "mailto:"))
        }
        chinese_links = {
            (chinese.parent / split_target(target)[0]).resolve()
            for _, target in local_targets(chinese, contents[chinese])
            if not target.startswith(("http://", "https://", "mailto:"))
        }
        if chinese.resolve() not in english_links or english.resolve() not in chinese_links:
            errors.append(f"language switch is not reciprocal: {english_name} <-> {chinese_name}")
        if executable_blocks(contents[english]) != executable_blocks(contents[chinese]):
            errors.append(f"executable code fences differ: {english_name} <-> {chinese_name}")

    if errors:
        print("Documentation validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"Documentation validation passed: {len(files)} files, {len(pairs)} bilingual pairs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
