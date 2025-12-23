#!/usr/bin/env python3
import sys
import re
from pathlib import Path

def main() -> int:
    if len(sys.argv) != 3:
        print("usage: update_timezone.py <system.nix> <timezone>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    tz = sys.argv[2]
    try:
        text = path.read_text(encoding="utf-8")
    except Exception as e:
        print(f"error: unable to read {path}: {e}", file=sys.stderr)
        return 1

    pattern = re.compile(r'^(\s*time\.timeZone\s*=\s*")[^"]*(";\s*)$', re.M)
    new_text, n = pattern.subn(lambda m: m.group(1) + tz + m.group(2), text, count=1)

    if n == 0:
        print("warning: did not find a time.timeZone line to update", file=sys.stderr)
        return 0

    try:
        path.write_text(new_text, encoding="utf-8")
    except Exception as e:
        print(f"error: unable to write {path}: {e}", file=sys.stderr)
        return 1

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
