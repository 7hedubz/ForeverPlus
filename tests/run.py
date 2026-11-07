#!/usr/bin/env python3
"""Run from any directory. Requires Python 3, LuaJIT and luac on PATH."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
for tool in ("luajit", "luac"):
    if not shutil.which(tool):
        sys.exit(f"Required tool not found: {tool}")
for source in sorted(ROOT.glob("*.lua")):
    subprocess.run(["luac", "-p", str(source)], check=True, cwd=ROOT)
    env = dict(os.environ, LUA_FILE=str(source))
    subprocess.run(
        ["luajit", "-e", 'assert(loadfile(os.getenv("LUA_FILE")))'],
        check=True, cwd=ROOT, env=env,
    )
    print(f"PARSE PASS {source.name}", flush=True)
for name in ("core", "comm", "ui", "history", "sync", "integration"):
    subprocess.run(["luajit", f"tests/{name}.lua"], check=True, cwd=ROOT)
print("All syntax and mocked-API regression suites passed.")
