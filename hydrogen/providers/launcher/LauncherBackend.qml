import QtQml
import QtCore
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property int latestSearchRequest: 0
    property var pendingSearch: null

    signal fileSearchCompleted(int requestId, var files)
    signal fileSearchFailed(int requestId, string code)
    signal fileValidationCompleted(var paths)
    signal executablesReady(var executables)
    signal commandAccepted
    signal commandFailed(string code)

    function helper(payload) {
        return [Quickshell.shellPath("providers/launcher/launcher_backend.py"), JSON.stringify(payload)];
    }

    function searchRoots() {
        const types = [
            StandardPaths.DesktopLocation,
            StandardPaths.DocumentsLocation,
            StandardPaths.DownloadLocation,
            StandardPaths.MusicLocation,
            StandardPaths.MoviesLocation,
            StandardPaths.PicturesLocation,
            StandardPaths.PublicShareLocation,
            StandardPaths.TemplatesLocation
        ];
        const roots = [];
        types.forEach(type => StandardPaths.standardLocations(type).forEach(location => {
            const value = String(location);
            if (value !== "" && roots.indexOf(value) < 0)
                roots.push(value);
        }));
        return roots;
    }

    function searchFiles(query, requestId, limit) {
        root.latestSearchRequest = Number(requestId);
        root.pendingSearch = { query: String(query), requestId: Number(requestId), limit: Number(limit) };
        if (searchProcess.running)
            searchProcess.running = false;
        else
            root.startPendingSearch();
    }

    function cancelFileSearch(requestId) {
        root.latestSearchRequest = Number(requestId);
        root.pendingSearch = null;
        if (searchProcess.running)
            searchProcess.running = false;
    }

    function startPendingSearch() {
        if (searchProcess.running || !root.pendingSearch)
            return;
        const request = root.pendingSearch;
        root.pendingSearch = null;
        searchProcess.command = root.helper({
            operation: "search_files",
            request_id: request.requestId,
            query: request.query,
            roots: root.searchRoots(),
            limit: request.limit
        });
        searchProcess.running = true;
    }

    function validateFiles(paths) {
        if (validationProcess.running)
            validationProcess.running = false;
        validationProcess.command = root.helper({ operation: "validate_files", paths: paths || [] });
        validationRestart.restart();
    }

    function refreshExecutables() {
        if (!executableProcess.running) {
            executableProcess.command = root.helper({ operation: "list_executables" });
            executableProcess.running = true;
        }
    }

    function runCommand(commandLine, terminal, terminalCommand) {
        if (commandProcess.running)
            return false;
        commandProcess.command = root.helper({
            operation: "run_command",
            command_line: String(commandLine),
            terminal: Boolean(terminal),
            terminal_command: terminalCommand || [],
            working_directory: String(StandardPaths.writableLocation(StandardPaths.HomeLocation))
        });
        commandProcess.running = true;
        return true;
    }

    function openFile(url) {
        return Qt.openUrlExternally(String(url));
    }

    Component.onCompleted: root.refreshExecutables()

    property Process searchProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                let response = null;
                try {
                    response = JSON.parse(text.trim());
                } catch (error) {
                    return;
                }
                const requestId = Number(response.request_id || 0);
                if (requestId !== root.latestSearchRequest)
                    return;
                if (response.ok)
                    root.fileSearchCompleted(requestId, response.files || []);
                else
                    root.fileSearchFailed(requestId, String(response.code || "file_search_failed"));
            }
        }
        onExited: searchRestart.restart()
    }

    property Timer searchRestart: Timer {
        interval: 0
        repeat: false
        onTriggered: root.startPendingSearch()
    }

    property Process validationProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text.trim());
                    if (response.ok)
                        root.fileValidationCompleted(response.paths || []);
                } catch (error) {
                    root.fileValidationCompleted([]);
                }
            }
        }
    }

    property Timer validationRestart: Timer {
        interval: 0
        repeat: false
        onTriggered: validationProcess.running = true
    }

    property Process executableProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text.trim());
                    root.executablesReady(response.ok ? response.executables || [] : []);
                } catch (error) {
                    root.executablesReady([]);
                }
            }
        }
    }

    property Process commandProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text.trim());
                    if (response.ok)
                        root.commandAccepted();
                    else
                        root.commandFailed(String(response.code || "command_start_failed"));
                } catch (error) {
                    root.commandFailed("command_start_failed");
                }
            }
        }
    }
}
