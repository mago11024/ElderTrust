from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = REPO_ROOT / "scripts" / "check_traceability.py"


class TraceabilityValidatorTests(unittest.TestCase):
    def test_accepts_one_primary_milestone_for_each_first_version_requirement(self) -> None:
        requirements = """
- **FR-TEST-001（P0）** 必须交付。
- **FR-TEST-002（P1）** 完整答辩版交付。
- **FR-TEST-003（P2）** 后续再评估。
"""
        traceability = """
| 需求 ID | 优先级 | 主要交付里程碑 | 支撑里程碑 | 验收证据 |
| --- | --- | --- | --- | --- |
| FR-TEST-001 | P0 | M1.0 | M2 | 自动化测试 |
| FR-TEST-002 | P1 | M7 | M4 | 人工验收 |
"""

        result = self.run_validator(requirements, traceability)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Traceability validation passed", result.stdout)
        self.assertIn("Unassigned P0/P1: 0", result.stdout)

    def test_rejects_requirement_ids_that_are_not_in_requirements(self) -> None:
        requirements = "- **FR-TEST-001（P0）** 必须交付。"
        traceability = """
| 需求 ID | 优先级 | 主要交付里程碑 | 支撑里程碑 | 验收证据 |
| --- | --- | --- | --- | --- |
| FR-TEST-001 | P0 | M1.0 | — | 自动化测试 |
| FR-UNKNOWN-001 | P0 | M2 | — | 自动化测试 |
"""

        result = self.run_validator(requirements, traceability)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("FR-UNKNOWN-001 is not a first-version requirement", result.stderr)

    def test_rejects_unassigned_p0_or_p1_requirements(self) -> None:
        requirements = """
- **FR-TEST-001（P0）** 必须交付。
- **FR-TEST-002（P1）** 完整答辩版交付。
"""
        traceability = """
| 需求 ID | 优先级 | 主要交付里程碑 | 支撑里程碑 | 验收证据 |
| --- | --- | --- | --- | --- |
| FR-TEST-001 | P0 | M1.0 | — | 自动化测试 |
"""

        result = self.run_validator(requirements, traceability)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(
            "FR-TEST-002 must have exactly one primary delivery milestone",
            result.stderr,
        )

    def test_rejects_duplicate_primary_milestones(self) -> None:
        requirements = "- **FR-TEST-001（P0）** 必须交付。"
        traceability = """
| 需求 ID | 优先级 | 主要交付里程碑 | 支撑里程碑 | 验收证据 |
| --- | --- | --- | --- | --- |
| FR-TEST-001 | P0 | M1.0 | — | 自动化测试 |
| FR-TEST-001 | P0 | M2 | — | 自动化测试 |
"""

        result = self.run_validator(requirements, traceability)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(
            "FR-TEST-001 must have exactly one primary delivery milestone",
            result.stderr,
        )

    def test_rejects_invalid_milestones_and_priority_drift(self) -> None:
        requirements = "- **FR-TEST-001（P1）** 完整答辩版交付。"
        traceability = """
| 需求 ID | 优先级 | 主要交付里程碑 | 支撑里程碑 | 验收证据 |
| --- | --- | --- | --- | --- |
| FR-TEST-001 | P0 | M8 | — | 自动化测试 |
"""

        result = self.run_validator(requirements, traceability)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("FR-TEST-001 priority does not match requirements", result.stderr)
        self.assertIn(
            "FR-TEST-001 has an invalid primary delivery milestone",
            result.stderr,
        )

    def run_validator(
        self,
        requirements: str,
        traceability: str,
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            requirements_path = directory / "REQUIREMENTS.md"
            traceability_path = directory / "REQUIREMENT_TRACEABILITY.md"
            requirements_path.write_text(requirements, encoding="utf-8")
            traceability_path.write_text(traceability, encoding="utf-8")
            return subprocess.run(
                [
                    sys.executable,
                    str(VALIDATOR),
                    "--requirements",
                    str(requirements_path),
                    "--traceability",
                    str(traceability_path),
                ],
                capture_output=True,
                check=False,
                text=True,
                encoding="utf-8",
            )


if __name__ == "__main__":
    unittest.main()
