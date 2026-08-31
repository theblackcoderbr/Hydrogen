#!/usr/bin/env python3
"""Launcher system bridge: fd search, PATH discovery and structured commands."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlparse


AUTO_TERMINALS = (
    ("foot", "-e"),
    ("alacritty", "-e"),
    ("kitty", "--"),
    ("wezterm", "start", "--"),
    ("xterm", "-e"),
)


def emit(ok, code, **data):
    payload = {"ok": ok, "code": code}
    payload.update(data)
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), flush=True)


def local_path(value):
    if not isinstance(value, str) or not value:
        return ""
    parsed = urlparse(value)
    if parsed.scheme == "file":
        return unquote(parsed.path)
    if parsed.scheme:
        return ""
    return os.path.abspath(os.path.expanduser(value))


def existing_roots(values):
    roots = []
    seen = set()
    for value in values if isinstance(values, list) else []:
        path = local_path(value)
        if path and path not in seen and os.path.isdir(path):
            seen.add(path)
            roots.append(path)
    return roots


def search_files(payload):
    request_id = int(payload.get("request_id", 0))
    query = payload.get("query")
    if not isinstance(query, str) or len(query.strip()) < 3:
        emit(True, "success", request_id=request_id, files=[])
        return 0
    roots = existing_roots(payload.get("roots"))
    if not roots:
        emit(True, "success", request_id=request_id, files=[])
        return 0
    executable = shutil.which("fd")
    if not executable:
        emit(False, "fd_unavailable", request_id=request_id)
        return 1
    limit = max(1, min(20, int(payload.get("limit", 20))))
    command = [
        executable,
        "--type", "f",
        "--absolute-path",
        "--color", "never",
        "--print0",
        "--fixed-strings",
        "--max-results", str(limit),
        query.strip(),
    ] + roots
    try:
        completed = subprocess.run(
            command,
            shell=False,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired):
        emit(False, "file_search_failed", request_id=request_id)
        return 1
    if completed.returncode not in (0, 1):
        emit(False, "file_search_failed", request_id=request_id)
        return 1
    files = []
    for raw in completed.stdout.split(b"\0"):
        if not raw:
            continue
        path = os.path.abspath(os.fsdecode(raw))
        if not os.path.isfile(path):
            continue
        files.append({
            "path": path,
            "name": os.path.basename(path),
            "parent": os.path.dirname(path),
            "url": Path(path).as_uri(),
        })
    emit(True, "success", request_id=request_id, files=files[:limit])
    return 0


def validate_files(payload):
    paths = payload.get("paths")
    valid = []
    seen = set()
    for value in paths if isinstance(paths, list) else []:
        if isinstance(value, str) and value.startswith("/"):
            path = os.path.abspath(value)
            if path not in seen and os.path.isfile(path):
                seen.add(path)
                valid.append(path)
    emit(True, "success", paths=valid)
    return 0


def list_executables():
    names = set()
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        if not directory or not os.path.isdir(directory):
            continue
        try:
            entries = os.scandir(directory)
        except OSError:
            continue
        with entries:
            for entry in entries:
                try:
                    if entry.is_file() and os.access(entry.path, os.X_OK):
                        names.add(entry.name)
                except OSError:
                    continue
    emit(True, "success", executables=sorted(names))
    return 0


def candidate_commands(command, terminal, configured):
    if not terminal:
        return [command]
    if isinstance(configured, list) and configured and all(isinstance(value, str) and value for value in configured):
        return [configured + command]
    return [list(prefix) + command for prefix in AUTO_TERMINALS]


def run_command(payload):
    line = payload.get("command_line")
    if not isinstance(line, str) or not line.strip():
        emit(False, "command_invalid")
        return 2
    try:
        command = shlex.split(line, posix=True)
    except ValueError:
        emit(False, "command_invalid")
        return 2
    if not command:
        emit(False, "command_invalid")
        return 2
    working_directory = local_path(payload.get("working_directory")) or str(Path.home())
    if not os.path.isdir(working_directory):
        emit(False, "working_directory_unavailable")
        return 2
    terminal = bool(payload.get("terminal"))
    last_error = "command_start_failed"
    for candidate in candidate_commands(command, terminal, payload.get("terminal_command")):
        try:
            subprocess.Popen(
                candidate,
                shell=False,
                cwd=working_directory,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
                close_fds=True,
            )
            emit(True, "success")
            return 0
        except FileNotFoundError:
            last_error = "terminal_unavailable" if terminal else "executable_unavailable"
        except (OSError, ValueError):
            last_error = "command_start_failed"
            break
    emit(False, last_error)
    return 1


def main():
    if len(sys.argv) != 2:
        emit(False, "invalid_request")
        return 2
    try:
        payload = json.loads(sys.argv[1])
    except (TypeError, ValueError):
        emit(False, "invalid_request")
        return 2
    operation = payload.get("operation")
    if operation == "search_files":
        return search_files(payload)
    if operation == "validate_files":
        return validate_files(payload)
    if operation == "list_executables":
        return list_executables()
    if operation == "run_command":
        return run_command(payload)
    emit(False, "invalid_request")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
