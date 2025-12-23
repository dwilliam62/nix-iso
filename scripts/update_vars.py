#!/usr/bin/env python3
import sys
import re
import pathlib

def main() -> int:
    if len(sys.argv) != 9:
        print(
            "usage: update_vars.py <variables.nix> <gitUsername> <gitEmail> <hostName> <gpuProfile> <keyboardLayout> <keyboardVariant> <consoleKeyMap>",
            file=sys.stderr,
        )
        return 2

    file_path = pathlib.Path(sys.argv[1])
    values = sys.argv[2:]
    keys = [
        "gitUsername",
        "gitEmail",
        "hostName",
        "gpuProfile",
        "keyboardLayout",
        "keyboardVariant",
        "consoleKeyMap",
    ]

    try:
        text = file_path.read_text(encoding="utf-8")
    except Exception as e:
        print(f"error: unable to read {file_path}: {e}", file=sys.stderr)
        return 1

    for key, val in zip(keys, values):
        # Replace lines of the form:   key = "...";
        # Works whether the line is top-level or inside a block
        pattern = re.compile(rf'^(\s*{re.escape(key)}\s*=\s*")[^"]*(";\s*)$', re.M)
        text = pattern.sub(lambda m, v=val: m.group(1) + v + m.group(2), text)

    try:
        file_path.write_text(text, encoding="utf-8")
    except Exception as e:
        print(f"error: unable to write {file_path}: {e}", file=sys.stderr)
        return 1

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
