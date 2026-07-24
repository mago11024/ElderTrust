from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIREMENT_PATTERN = re.compile(
    r"\*\*(?P<id>(?:FR|NFR)-[A-Z]+-\d{3})(?:（(?P<priority>P[012])）)?\*\*"
)
ALLOWED_MILESTONES = {"M1.0", "M1.1", "M2", "M3", "M4", "M5", "M6", "M7"}


def parse_first_version_requirements(content: str) -> dict[str, str]:
    requirements: dict[str, str] = {}
    for match in REQUIREMENT_PATTERN.finditer(content):
        priority = match.group("priority") or "V1"
        if priority != "P2":
            requirements[match.group("id")] = priority
    return requirements


def parse_traceability_rows(content: str) -> list[dict[str, str]]:
    lines = [line for line in content.splitlines() if line.strip().startswith("|")]
    if len(lines) < 2:
        return []

    headers = [cell.strip() for cell in lines[0].strip().strip("|").split("|")]
    rows: list[dict[str, str]] = []
    for line in lines[2:]:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) == len(headers):
            rows.append(dict(zip(headers, cells, strict=True)))
    return rows


def validate(requirements_content: str, traceability_content: str) -> list[str]:
    requirements = parse_first_version_requirements(requirements_content)
    rows = parse_traceability_rows(traceability_content)
    errors: list[str] = []

    rows_by_id: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        requirement_id = row.get("需求 ID", "")
        if requirement_id:
            rows_by_id.setdefault(requirement_id, []).append(row)

    for requirement_id in rows_by_id.keys() - requirements.keys():
        errors.append(f"{requirement_id} is not a first-version requirement")

    for requirement_id, priority in requirements.items():
        matching_rows = rows_by_id.get(requirement_id, [])
        if len(matching_rows) != 1:
            errors.append(
                f"{requirement_id} must have exactly one primary delivery milestone"
            )
            continue
        row = matching_rows[0]
        if row.get("优先级") != priority:
            errors.append(f"{requirement_id} priority does not match requirements")
        if row.get("主要交付里程碑") not in ALLOWED_MILESTONES:
            errors.append(f"{requirement_id} has an invalid primary delivery milestone")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate first-version traceability.")
    parser.add_argument(
        "--requirements",
        type=Path,
        default=Path("docs/REQUIREMENTS.md"),
    )
    parser.add_argument(
        "--traceability",
        type=Path,
        default=Path("docs/REQUIREMENT_TRACEABILITY.md"),
    )
    arguments = parser.parse_args()

    requirements_content = arguments.requirements.read_text(encoding="utf-8")
    traceability_content = arguments.traceability.read_text(encoding="utf-8")
    errors = validate(requirements_content, traceability_content)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    requirement_count = len(parse_first_version_requirements(requirements_content))
    print("Traceability validation passed")
    print(f"First-version requirements: {requirement_count}")
    print("Unassigned P0/P1: 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
