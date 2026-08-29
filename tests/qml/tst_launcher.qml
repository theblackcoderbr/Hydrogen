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
        overlayCoordinator: testCase.overlay
        errors: testCase.errors
        logger: testCase.logger
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
}
