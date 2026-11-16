"""Optional MATLAB static validation; requires Python package ``miss_hit``.

This does not execute MATLAB/R, load research data, or certify algorithms.
Run from any working directory: python tests/validate_static.py
"""
from __future__ import annotations

import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="cssp_static_") as directory:
        result_file = Path(directory) / "lint.json"
        command = [sys.executable, "-m", "miss_hit.mh_lint",
                   "--input-encoding=utf-8", "--brief", "--json",
                   str(result_file), str(root)]
        completed = subprocess.run(command, capture_output=True, text=True)
        findings = (json.loads(result_file.read_text()) if result_file.exists()
                    else {"parser_not_available": completed.stderr})
    files = sorted(root.rglob("*.m"))
    declaration = re.compile(
        r"(?m)^\s*function\s+(?:\[[^\]]*\]\s*=\s*|\w+\s*=\s*)?(\w+)")
    definitions, calls, mismatches = {}, set(), []
    for path in files:
        source = path.read_text(encoding="utf-8-sig")
        names = declaration.findall(source)
        if names:
            if names[0] != path.stem:
                mismatches.append({"file": str(path.relative_to(root)), "function": names[0]})
            for name in names:
                definitions[name] = str(path.relative_to(root))
        calls.update(re.findall(r"\b(CSSP_[A-Za-z0-9_]+)\s*\(", source))
    unresolved = sorted(calls - set(definitions))
    tool_version = subprocess.run(
        [sys.executable, "-m", "miss_hit.mh_lint", "--version"],
        capture_output=True, text=True).stdout.strip()
    report = {
        "pass": completed.returncode == 0 and not findings and not mismatches and not unresolved,
        "scope": "MATLAB_static_parsing_and_lexical_symbol_presence_only",
        "matlab_executed": False,
        "r_executed": False,
        "r_parser_executed": False,
        "scientific_experiments_executed": False,
        "tool": tool_version,
        "checked_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "matlab_file_count": len(files),
        "parser_exit_code": completed.returncode,
        "findings": findings,
        "primary_function_filename_mismatches": mismatches,
        "unresolved_named_CSSP_calls": unresolved,
        "source_snapshot": [
            {"file": str(path.relative_to(root)),
             "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            for path in files],
    }
    output = Path(__file__).with_name("static_parser_report.json")
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(completed.stdout.strip())
    print(json.dumps({key: value for key, value in report.items() if key != "source_snapshot"}, indent=2))
    if not report["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
