#!/usr/bin/env python3

import sys
from pathlib import Path

CWD = Path(__file__).parent
TEST_FILE = CWD / "test_processor_send.txt"


with TEST_FILE.open("w", encoding="utf-8") as f:
    while line := sys.stdin.readline():
        f.write(line)

        if "False" in line:
            break
