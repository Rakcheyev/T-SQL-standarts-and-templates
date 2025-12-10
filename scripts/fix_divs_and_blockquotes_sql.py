#!/usr/bin/env python3
"""Fix two issues in lesson markdown files:

- Remove ```sql``` fenced blocks that wrap centered <div ...> headers.
- Convert consecutive blockquote SQL lines (lines starting with optional '>')
  into a single fenced ```sql``` code block.

Creates a .bak for each modified file.
"""
import re
from pathlib import Path


DIV_IN_CODE_RE = re.compile(r"```sql\s*(<div[^>]*?text-align:[^>]*?>.*?</div>)\s*```", re.S | re.I)

SQL_KEYWORDS = re.compile(r"\b(SELECT|INSERT|UPDATE|DELETE|CREATE|WITH|FROM|WHERE|GROUP\s+BY|ORDER\s+BY|JOIN|HAVING|UNION|VALUES|CAST|SUM|AVG|COUNT|MIN|MAX)\b", re.I)


def contains_div_in_code(text: str):
    return bool(DIV_IN_CODE_RE.search(text))


def remove_div_code_blocks(text: str) -> str:
    # Replace ```sql <div...>...</div> ``` with just <div...>...</div>
    return DIV_IN_CODE_RE.sub(lambda m: m.group(1), text)


def is_blockquote_sql_line(s: str):
    # Matches optional leading '>' and optional spaces, then content
    m = re.match(r"^\s*>\s*(.*\S.*)?$", s)
    if not m:
        return None
    inner = m.group(1) or ""
    # If inner is empty, consider as blank line inside blockquote
    # Heuristic: treat as SQL line if contains SQL keyword or punctuation
    if inner == "":
        return ""
    if SQL_KEYWORDS.search(inner) or re.search(r"[,();=*<>\\]", inner):
        return inner
    return None


def convert_blockquote_sequences(text: str) -> str:
    lines = text.splitlines()
    out = []
    i = 0
    n = len(lines)
    while i < n:
        res = is_blockquote_sql_line(lines[i])
        if res is None:
            out.append(lines[i])
            i += 1
            continue

        # Start collecting a sequence of blockquote lines that are SQL-ish
        sql_lines = []
        j = i
        saw_nonempty = False
        while j < n:
            r = is_blockquote_sql_line(lines[j])
            if r is None:
                break
            # r == "" means blank quoted line -> translate to blank line in SQL
            sql_lines.append(r)
            if r != "":
                saw_nonempty = True
            j += 1

        # Only convert if there is at least one non-empty SQL-like line
        if saw_nonempty:
            # trim leading/trailing empty strings
            while sql_lines and sql_lines[0] == "":
                sql_lines.pop(0)
            while sql_lines and sql_lines[-1] == "":
                sql_lines.pop()

            out.append("```sql")
            out.extend(sql_lines)
            out.append("```")
            i = j
        else:
            # all were empty quoted lines — keep original lines
            out.extend(lines[i:j])
            i = j

    return "\n".join(out) + ("\n" if text.endswith("\n") else "")


def normalize_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    orig = text

    # 1) Remove div-in-code fences
    text = remove_div_code_blocks(text)

    # 2) Convert blockquote SQL sequences into fenced blocks
    text = convert_blockquote_sequences(text)

    if text != orig:
        bak = path.with_suffix(path.suffix + ".fixbak")
        bak.write_text(orig, encoding="utf-8")
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main():
    repo_root = Path(__file__).resolve().parent.parent
    lessons = repo_root / "course" / "lessons"
    changed = False
    for p in sorted(lessons.glob("*.md")):
        print("Processing:", p.name)
        if normalize_file(p):
            print("  -> fixed", p.name)
            changed = True
    if not changed:
        print("No changes made.")


if __name__ == "__main__":
    main()
