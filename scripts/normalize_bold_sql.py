#!/usr/bin/env python3
"""Normalize bold-wrapped SQL lines into fenced ```sql``` blocks.

This script scans markdown files in `course/lessons` and replaces
consecutive lines that are fully wrapped with **...** and look like SQL
with a proper ```sql fenced code block. For safety, a .bak copy of each
file is created before modification.
"""
import re
from pathlib import Path


SQL_KEYWORDS = re.compile(r"\b(SELECT|INSERT|UPDATE|DELETE|CREATE|WITH|FROM|WHERE|GROUP\s+BY|ORDER\s+BY|JOIN|HAVING|UNION|VALUES)\b", re.I)


def is_bold_sql_line(line: str):
    # Matches optional leading blockquote '>' and optional spaces, then **...** and nothing else
    m = re.match(r"^\s*(>\s*)?\*\*(.*?)\*\*\s*$", line)
    if not m:
        return None
    inner = m.group(2)
    # Ignore HTML div headers or other HTML tags wrapped in **...**
    if '<div' in inner.lower() or '</div>' in inner.lower():
        return None
    # Heuristic: treat as SQL if contains SQL keyword or common SQL punctuation
    if SQL_KEYWORDS.search(inner) or re.search(r"[,();=*<>]", inner):
        return inner
    return None


def normalize_file(path: Path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    out_lines = []
    i = 0
    n = len(lines)
    in_fence = False
    changed = False

    while i < n:
        line = lines[i]
        # Toggle fenced code blocks to avoid modifying inside them
        if re.match(r"^\s*```", line):
            in_fence = not in_fence
            out_lines.append(line)
            i += 1
            continue

        if not in_fence:
            m = is_bold_sql_line(line)
            if m is not None:
                # collect consecutive bold-SQL lines
                sql_lines = [m]
                j = i + 1
                while j < n:
                    nxt = is_bold_sql_line(lines[j])
                    if nxt is None:
                        break
                    sql_lines.append(nxt)
                    j += 1

                # replace with fenced block
                out_lines.append("```sql")
                out_lines.extend(sql_lines)
                out_lines.append("```")
                changed = True
                i = j
                continue

        out_lines.append(line)
        i += 1

    if changed:
        bak = path.with_suffix(path.suffix + ".bak")
        bak.write_text(text, encoding="utf-8")
        path.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
    return changed


def main():
    repo_root = Path(__file__).resolve().parent.parent
    lessons = repo_root / "course" / "lessons"
    if not lessons.is_dir():
        print("Lessons directory not found:", lessons)
        return 1

    md_files = sorted(lessons.glob("*.md"))
    any_changed = False
    for p in md_files:
        print("Processing:", p)
        if normalize_file(p):
            print("  -> normalized", p.name)
            any_changed = True

    if not any_changed:
        print("No changes made.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
