import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import unittest


BACKEND = pathlib.Path(__file__).parents[2] / "hydrogen/providers/launcher/launcher_backend.py"


class LauncherBackendTests(unittest.TestCase):
    def run_backend(self, payload, env=None):
        completed = subprocess.run(
            [sys.executable, str(BACKEND), json.dumps(payload)],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )
        return completed.returncode, json.loads(completed.stdout)

    def test_fd_search_ignores_hidden_and_returns_escaped_file_url(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            special = root / "ação special # final.txt"
            hidden = root / ".special-hidden.txt"
            matching_directory = root / "special-directory"
            special.write_text("visible")
            hidden.write_text("hidden")
            matching_directory.mkdir()
            code, response = self.run_backend({
                "operation": "search_files",
                "request_id": 7,
                "query": "special",
                "roots": [root.as_uri(), (root / "missing").as_uri()],
                "limit": 20,
            })
            self.assertEqual(code, 0)
            self.assertTrue(response["ok"])
            self.assertEqual(response["request_id"], 7)
            self.assertEqual([item["path"] for item in response["files"]], [str(special)])
            self.assertEqual(response["files"][0]["url"], special.as_uri())

    def test_command_arguments_and_operators_are_never_shell_interpreted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            marker = root / "arguments.json"
            injected = root / "must-not-exist"
            line = (
                f"{shlex_quote(sys.executable)} -c "
                f"\"import json,pathlib,sys;pathlib.Path(sys.argv[1]).write_text(json.dumps(sys.argv[2:]))\" "
                f"{shlex_quote(str(marker))} 'two words' '|' '$HOME' '*.txt' '$(touch {injected})'"
            )
            code, response = self.run_backend({
                "operation": "run_command",
                "command_line": line,
                "terminal": False,
                "terminal_command": [],
                "working_directory": root.as_uri(),
            })
            self.assertEqual(code, 0)
            self.assertTrue(response["ok"])
            for _ in range(100):
                if marker.exists():
                    break
                time.sleep(0.01)
            self.assertEqual(json.loads(marker.read_text()), ["two words", "|", "$HOME", "*.txt", f"$(touch {injected})"])
            self.assertFalse(injected.exists())

    def test_private_data_is_not_returned_in_failures_and_path_scan_is_names_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            executable = root / "hydrogen-test-command"
            executable.write_text("#!/bin/sh\nexit 0\n")
            executable.chmod(0o755)
            environment = dict(os.environ)
            environment["PATH"] = str(root)
            code, response = self.run_backend({ "operation": "list_executables" }, env=environment)
            self.assertEqual(code, 0)
            self.assertEqual(response["executables"], ["hydrogen-test-command"])
            self.assertNotIn(str(root), json.dumps(response))

            code, response = self.run_backend({
                "operation": "run_command",
                "command_line": "unterminated 'private-value",
                "terminal": False,
            })
            self.assertNotEqual(code, 0)
            self.assertEqual(response, {"ok": False, "code": "command_invalid"})

            code, response = self.run_backend({
                "operation": "run_command",
                "command_line": "hydrogen-private-command-that-does-not-exist secret-value",
                "terminal": False,
            })
            self.assertNotEqual(code, 0)
            self.assertEqual(response, {"ok": False, "code": "executable_unavailable"})
            self.assertNotIn("secret-value", json.dumps(response))

    def test_command_defaults_to_home_and_honors_configured_terminal(self):
        with tempfile.TemporaryDirectory() as directory:
            home = pathlib.Path(directory)
            cwd_marker = home / "cwd.txt"
            environment = dict(os.environ)
            environment["HOME"] = str(home)
            line = (
                f"{shlex_quote(sys.executable)} -c "
                f"{shlex_quote('import os,pathlib,sys;pathlib.Path(sys.argv[1]).write_text(os.getcwd())')} "
                f"{shlex_quote(str(cwd_marker))}"
            )
            code, response = self.run_backend({
                "operation": "run_command",
                "command_line": line,
                "terminal": False,
            }, env=environment)
            self.assertEqual(code, 0)
            self.assertTrue(response["ok"])
            wait_for_file(cwd_marker)
            self.assertEqual(cwd_marker.read_text(), str(home))

            terminal_marker = home / "terminal.json"
            terminal_script = "import json,pathlib,sys;pathlib.Path(sys.argv[1]).write_text(json.dumps(sys.argv[2:]))"
            code, response = self.run_backend({
                "operation": "run_command",
                "command_line": "printf 'two words'",
                "terminal": True,
                "terminal_command": [sys.executable, "-c", terminal_script, str(terminal_marker)],
                "working_directory": home.as_uri(),
            }, env=environment)
            self.assertEqual(code, 0)
            self.assertTrue(response["ok"])
            wait_for_file(terminal_marker)
            self.assertEqual(json.loads(terminal_marker.read_text()), ["printf", "two words"])

    def test_validation_keeps_only_existing_absolute_files(self):
        with tempfile.TemporaryDirectory() as directory:
            existing = pathlib.Path(directory) / "existing"
            existing.write_text("ok")
            code, response = self.run_backend({
                "operation": "validate_files",
                "paths": [str(existing), str(existing), str(existing) + "-missing", "relative"],
            })
            self.assertEqual(code, 0)
            self.assertEqual(response["paths"], [str(existing)])


def shlex_quote(value):
    import shlex
    return shlex.quote(value)


def wait_for_file(path):
    for _ in range(100):
        if path.exists():
            return
        time.sleep(0.01)
    raise AssertionError(f"timed out waiting for {path.name}")


if __name__ == "__main__":
    unittest.main()
