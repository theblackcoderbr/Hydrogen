import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import unittest


RUNNER = pathlib.Path(__file__).parents[2] / "hydrogen/providers/desktop/desktop_entry_runner.py"
RUNNER_SPEC = importlib.util.spec_from_file_location("desktop_entry_runner", RUNNER)
RUNNER_MODULE = importlib.util.module_from_spec(RUNNER_SPEC)
RUNNER_SPEC.loader.exec_module(RUNNER_MODULE)


class DesktopEntryRunnerTests(unittest.TestCase):
    def run_runner(self, payload, env=None):
        result = subprocess.run(
            [sys.executable, str(RUNNER), json.dumps(payload)],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )
        return result.returncode, json.loads(result.stdout)

    def test_structured_command_starts_without_shell_interpretation(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = pathlib.Path(directory) / "literal-marker"
            injected = pathlib.Path(directory) / "must-not-exist"
            literal = f"$(touch {injected})"
            code, response = self.run_runner({
                "command": [
                    sys.executable,
                    "-c",
                    "import pathlib,sys; pathlib.Path(sys.argv[1]).write_text(sys.argv[2])",
                    str(marker),
                    literal,
                ],
                "working_directory": directory,
                "terminal": False,
                "terminal_command": [],
            })
            self.assertEqual(code, 0)
            self.assertTrue(response["ok"])
            for _ in range(100):
                if marker.exists():
                    break
                time.sleep(0.01)
            self.assertTrue(marker.exists())
            self.assertEqual(marker.read_text(), literal)
            self.assertFalse(injected.exists())

    def test_configured_terminal_is_a_structured_prefix(self):
        commands = RUNNER_MODULE.candidate_commands({
            "command": ["application", "--flag"],
            "terminal": True,
            "terminal_command": ["terminal", "-e"],
        })
        self.assertEqual(commands, [["terminal", "-e", "application", "--flag"]])

    def test_missing_executable_and_terminal_are_actionable(self):
        code, response = self.run_runner({
            "command": ["hydrogen-command-that-does-not-exist"],
            "working_directory": "",
            "terminal": False,
            "terminal_command": [],
        })
        self.assertNotEqual(code, 0)
        self.assertEqual(response["code"], "executable_unavailable")

        env = dict(os.environ)
        env["PATH"] = ""
        code, response = self.run_runner({
            "command": ["true"],
            "working_directory": "",
            "terminal": True,
            "terminal_command": [],
        }, env=env)
        self.assertNotEqual(code, 0)
        self.assertEqual(response["code"], "terminal_unavailable")


if __name__ == "__main__":
    unittest.main()
