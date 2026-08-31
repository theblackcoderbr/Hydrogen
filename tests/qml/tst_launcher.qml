pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../../hydrogen/core" as Core
import "../../hydrogen/domain" as Domain
import "../../hydrogen/features/panel" as Panel

TestCase {
    id: testCase
    name: "ApplicationLauncher"
    width: 640
    height: 480
    visible: true
    when: windowShown

    property QtObject lifecycle: QtObject {
        property string state: "running"
    }
    property QtObject configuration: QtObject {
        signal published
        property var effective: ({
                terminal: {
                    command: []
                },
                launcher: {
                    result_limit: 20,
                    history_limit: 100,
                    history_days: 30
                }
            })
    }
    property Domain.LauncherStore store: Domain.LauncherStore {}
    property bool lastHistoryImmediate: false
    property Core.ErrorRegistry errors: Core.ErrorRegistry {}
    property QtObject logger: QtObject {
        property int calls: 0
        function emit(level, category, code, message, fields) {
            calls += 1;
            return true;
        }
    }
    property QtObject overlay: QtObject {
        property int closeCalls: 0
        function close() {
            closeCalls += 1;
        }
    }
    property QtObject foundationController: QtObject {
        property int reloadCalls: 0
        function requestConfigReload() {
            reloadCalls += 1;
            return { ok: true, code: "success", message: "ok" };
        }
    }
    property QtObject persistence: QtObject {
        property bool doNotDisturb: false
        property int flushCalls: 0
        function setDoNotDisturb(value) {
            doNotDisturb = Boolean(value);
        }
        function flushNow() {
            flushCalls += 1;
        }
    }
    property QtObject backend: QtObject {
        property var searchCalls: []
        property var commandCalls: []
        property string openedUrl: ""
        property bool acceptOpen: true
        signal fileSearchCompleted(int requestId, var files)
        signal fileSearchFailed(int requestId, string code)
        signal fileValidationCompleted(var paths)
        signal executablesReady(var executables)
        signal commandAccepted
        signal commandFailed(string code)
        function searchFiles(query, requestId, limit) {
            searchCalls = searchCalls.concat([{ query, requestId, limit }]);
        }
        function cancelFileSearch(requestId) {}
        function validateFiles(paths) {
            fileValidationCompleted(paths);
        }
        function runCommand(commandLine, terminal, terminalCommand) {
            commandCalls = commandCalls.concat([{ commandLine, terminal, terminalCommand }]);
            return true;
        }
        function openFile(url) {
            openedUrl = String(url);
            return acceptOpen;
        }
    }
    property QtObject provider: QtObject {
        property var calls: []
        property bool acceptRequest: true
        signal launchAccepted(string desktopEntry)
        signal launchFailed(string desktopEntry, string code)
        function launch(application, terminalCommand) {
            calls = calls.concat([
                {
                    id: application.id,
                    terminal: terminalCommand
                }
            ]);
            return acceptRequest;
        }
    }
    property Domain.LauncherController controller: Domain.LauncherController {
        lifecycle: testCase.lifecycle
        configuration: testCase.configuration
        launcherStore: testCase.store
        provider: testCase.provider
        launcherBackend: testCase.backend
        overlayCoordinator: testCase.overlay
        foundationController: testCase.foundationController
        persistence: testCase.persistence
        errors: testCase.errors
        logger: testCase.logger
    }
    property Connections historyConnections: Connections {
        target: testCase.store
        function onHistoryMutated(immediate) {
            testCase.lastHistoryImmediate = immediate;
        }
    }
    property Component contentComponent: Component {
        Panel.LauncherContent {
            width: 560
            height: 380
            launcherStore: testCase.store
            launcherController: testCase.controller
            overlayCoordinator: testCase.overlay
            iconSources: ({})
            fallbackIconSource: ""
            opacityValue: 1
        }
    }

    function application(id, name, executable) {
        return {
            kind: "application",
            id: id,
            name: name,
            genericName: "",
            comment: "",
            icon: "application-x-executable",
            keywords: [],
            command: executable ? [id] : [],
            workingDirectory: "",
            runInTerminal: false,
            executable: executable
        };
    }

    function init() {
        lifecycle.state = "running";
        store.applications = [application("editor", "Éditeur", true), application("broken", "Quebrado", false)];
        store.history = [];
        store.query = "";
        store.launching = false;
        store.clearFailure();
        provider.calls = [];
        provider.acceptRequest = true;
        overlay.closeCalls = 0;
        errors.entries = [];
        logger.calls = 0;
        backend.searchCalls = [];
        backend.commandCalls = [];
        backend.openedUrl = "";
        backend.acceptOpen = true;
        foundationController.reloadCalls = 0;
        persistence.flushCalls = 0;
        persistence.doNotDisturb = false;
        lastHistoryImmediate = false;
    }

    function test_acceptanceRecordsUsageAndClosesOnlyAfterProviderConfirmation() {
        controller.setQuery("editeur");
        compare(store.results.length, 1);
        verify(controller.launch(store.results[0]));
        compare(store.launching, true);
        compare(overlay.closeCalls, 0);
        provider.launchAccepted("editor");
        compare(store.launching, false);
        compare(store.history[0].desktop_entry, "editor");
        compare(store.history[0].use_count, 1);
        compare(overlay.closeCalls, 1);
    }

    function test_inexecutableAndProviderFailuresRemainVisibleAndActionable() {
        controller.setQuery("quebrado");
        verify(!controller.launch(store.results[0]));
        compare(store.failureCode, "desktop_entry_inexecutable");
        compare(overlay.closeCalls, 0);
        compare(errors.actionableCount, 1);
        compare(logger.calls, 1);

        controller.setQuery("editeur");
        verify(controller.launch(store.results[0]));
        provider.launchFailed("editor", "executable_unavailable");
        compare(store.failureCode, "executable_unavailable");
        compare(overlay.closeCalls, 0);
    }

    function test_contentSupportsKeyboardSearchAndPointerActivation() {
        const content = createTemporaryObject(contentComponent, testCase);
        verify(content !== null);
        const search = findChild(content, "launcherSearch");
        verify(search !== null);
        search.forceActiveFocus();
        search.text = "editeur";
        tryCompare(store, "query", "editeur");
        tryVerify(() => findChild(content, "launcherResult-0") !== null);
        keyClick(Qt.Key_Return);
        compare(provider.calls.length, 1);

        store.launching = false;
        controller.setQuery("quebrado");
        tryVerify(() => findChild(content, "launcherResult-0") !== null);
        const result = findChild(content, "launcherResult-0");
        mouseClick(result);
        compare(store.failureCode, "desktop_entry_inexecutable");
    }

    function test_staleFileResponsesNeverReplaceCurrentResults() {
        controller.setQuery("ab");
        compare(backend.searchCalls.length, 0);
        controller.setQuery("slow-query");
        const oldRequest = backend.searchCalls[0].requestId;
        controller.setQuery("fast-query");
        const currentRequest = backend.searchCalls[1].requestId;
        backend.fileSearchCompleted(oldRequest, [{ path: "/tmp/old", name: "old", url: "file:///tmp/old" }]);
        compare(store.fileResults.length, 0);
        backend.fileSearchCompleted(currentRequest, [{ path: "/tmp/new", name: "new", url: "file:///tmp/new" }]);
        compare(store.fileResults[0].path, "/tmp/new");

        controller.setQuery("failing-query");
        const failedRequest = backend.searchCalls[2].requestId;
        backend.fileSearchFailed(oldRequest, "fd_unavailable");
        compare(store.failureCode, "");
        backend.fileSearchFailed(failedRequest, "fd_unavailable");
        compare(store.failureCode, "fd_unavailable");
        compare(store.fileSearching, false);
    }

    function test_fileAndCommandAcceptanceRespectHistoryAndPrivacy() {
        const file = { kind: "file", path: "/tmp/special # file.txt", url: "file:///tmp/special%20%23%20file.txt" };
        verify(controller.activate(file));
        compare(backend.openedUrl, file.url);
        compare(store.history[0].kind, "file");

        overlay.closeCalls = 0;
        const privateCommand = { kind: "command", commandLine: "echo private", terminal: false, private: true };
        verify(controller.activate(privateCommand));
        backend.commandAccepted();
        compare(store.history.length, 1);
        compare(overlay.closeCalls, 1);

        const terminalCommand = { kind: "command", commandLine: "printf value", terminal: true, private: false };
        verify(controller.activate(terminalCommand));
        backend.commandAccepted();
        const storedCommand = store.history.find(item => item.kind === "command");
        verify(storedCommand !== undefined);
        compare(storedCommand.terminal, true);
    }

    function test_fileAndCommandFailuresStayOpenAndAreActionable() {
        backend.acceptOpen = false;
        const file = { kind: "file", path: "/tmp/rejected.txt", url: "file:///tmp/rejected.txt" };
        verify(!controller.activate(file));
        compare(store.history.length, 0);
        compare(store.failureCode, "file_open_failed");
        compare(overlay.closeCalls, 0);

        const command = { kind: "command", commandLine: "missing-command", terminal: false, private: false };
        verify(controller.activate(command));
        compare(store.launching, true);
        backend.commandFailed("executable_unavailable");
        compare(store.launching, false);
        compare(store.failureCode, "executable_unavailable");
        compare(store.history.length, 0);
        compare(overlay.closeCalls, 0);
        verify(errors.actionableCount >= 2);
    }

    function test_internalActionsReloadToggleAndClearImmediately() {
        controller.refreshActions();
        verify(controller.runAction(Object.assign({ actionId: "reload_config" }, store.actions.find(action => action.id === "reload_config"))));
        compare(foundationController.reloadCalls, 1);

        lifecycle.state = "running";
        verify(controller.runAction(Object.assign({ actionId: "toggle_dnd" }, store.actions.find(action => action.id === "toggle_dnd"))));
        compare(persistence.doNotDisturb, true);

        store.history = [{ kind: "command", command: "true", terminal: false, use_count: 1, last_used_at: new Date().toISOString() }];
        verify(controller.runAction(Object.assign({ actionId: "clear_history" }, store.actions.find(action => action.id === "clear_history"))));
        compare(store.history.length, 0);
        compare(lastHistoryImmediate, true);

        const logout = Object.assign({ actionId: "logout" }, store.actions.find(action => action.id === "logout"));
        verify(!controller.runAction(logout));
        compare(store.failureCode, "session_confirmation_unavailable");
    }
}
