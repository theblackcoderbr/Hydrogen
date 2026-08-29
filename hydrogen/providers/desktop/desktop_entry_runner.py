#!/usr/bin/env python3
"""Start one normalized Desktop Entry command without invoking a shell."""

import json
import os
import subprocess
import sys


AUTO_TERMINALS = (
    ("foot", "-e"),
    ("alacritty", "-e"),
    ("kitty", "--"),
    ("wezterm", "start", "--"),
    ("xterm", "-e"),
)


def response(ok, code):
    print(json.dumps({"ok": ok, "code": code}, separators=(",", ":")), flush=True)


def candidate_commands(payload):
    command = payload.get("command")
    if not isinstance(command, list) or not command or not all(isinstance(value, str) and value for value in command):
        return []
    if not payload.get("terminal"):
        return [command]
    configured = payload.get("terminal_command")
    if isinstance(configured, list) and configured and all(isinstance(value, str) and value for value in configured):
        return [configured + command]
    return [list(prefix) + command for prefix in AUTO_TERMINALS]


def main():
    if len(sys.argv) != 2:
        response(False, "invalid_request")
        return 2
    try:
        payload = json.loads(sys.argv[1])
    except (TypeError, ValueError):
        response(False, "invalid_request")
        return 2
    commands = candidate_commands(payload)
    if not commands:
        response(False, "desktop_entry_inexecutable")
        return 2
    working_directory = payload.get("working_directory") or None
    if working_directory is not None and (not isinstance(working_directory, str) or not os.path.isdir(working_directory)):
        response(False, "working_directory_unavailable")
        return 2
    last_error = "desktop_entry_start_failed"
    for command in commands:
        try:
            subprocess.Popen(
                command,
                shell=False,
                cwd=working_directory,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
                close_fds=True,
            )
            response(True, "success")
            return 0
        except FileNotFoundError:
            last_error = "terminal_unavailable" if payload.get("terminal") else "executable_unavailable"
        except (OSError, ValueError):
            last_error = "desktop_entry_start_failed"
            break
    response(False, last_error)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
