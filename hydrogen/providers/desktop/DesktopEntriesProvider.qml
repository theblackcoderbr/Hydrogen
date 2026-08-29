import QtQml
import Quickshell
import Quickshell.Io
import "../../logic/Launcher.js" as Launcher

QtObject {
    id: root

    required property var store
    property string pendingDesktopEntry: ""

    signal launchAccepted(string desktopEntry)
    signal launchFailed(string desktopEntry, string code)

    function refresh() {
        const raw = [];
        for (let index = 0; index < DesktopEntries.applications.values.length; ++index) {
            const entry = DesktopEntries.applications.values[index];
            raw.push({
                id: entry.id,
                name: entry.name,
                genericName: entry.genericName,
                comment: entry.comment,
                icon: entry.icon,
                keywords: entry.keywords,
                command: entry.command,
                workingDirectory: entry.workingDirectory,
                runInTerminal: entry.runInTerminal,
                noDisplay: entry.noDisplay
            });
        }
        root.store.publishApplications(Launcher.normalizeCatalog(raw));
    }

    function launch(application, terminalCommand) {
        if (runner.running || !application || !application.executable)
            return false;
        root.pendingDesktopEntry = String(application.id);
        runner.command = [Quickshell.shellPath("providers/desktop/desktop_entry_runner.py"), JSON.stringify({
                command: application.command,
                working_directory: application.workingDirectory,
                terminal: application.runInTerminal,
                terminal_command: terminalCommand || []
            })];
        runner.running = true;
        return true;
    }

    Component.onCompleted: root.refresh()

    property Process runner: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                let result = null;
                try {
                    result = JSON.parse(text.trim());
                } catch (error) {
                    result = {
                        ok: false,
                        code: "desktop_entry_runner_failed"
                    };
                }
                if (result.ok)
                    root.launchAccepted(root.pendingDesktopEntry);
                else
                    root.launchFailed(root.pendingDesktopEntry, String(result.code || "desktop_entry_start_failed"));
                root.pendingDesktopEntry = "";
            }
        }
    }

    property Connections catalogConnection: Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.refresh();
        }
    }
}
