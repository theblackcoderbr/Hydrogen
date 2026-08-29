pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../../hydrogen/domain" as Domain
import "../../hydrogen/features/panel" as Panel

TestCase {
    id: testCase
    name: "WindowSurfaces"
    width: 640
    height: 480
    visible: true
    when: windowShown

    property Domain.WindowStore windowStore: Domain.WindowStore {}
    property Domain.OverlayStore overlayStore: Domain.OverlayStore {}
    property QtObject controller: QtObject {
        property var calls: []

        function focusWindow(id) {
            calls = calls.concat(["focus:" + id]);
            return true;
        }

        function closeWindow(id) {
            calls = calls.concat(["close:" + id]);
            return true;
        }
    }
    property QtObject coordinator: QtObject {
        property var calls: []

        function showWindowGroup(output, workspace, groupKey) {
            calls = calls.concat(["group:" + output + ":" + workspace + ":" + groupKey]);
            return true;
        }

        function close() {
            calls = calls.concat(["close"]);
            testCase.overlayStore.close();
        }
    }
    property Component contentComponent: Component {
        Panel.WindowMenuContent {
            width: 440
            height: contentHeight
            outputName: "A"
            availableWidth: 320
            opacityValue: 1
            overlayStore: testCase.overlayStore
            overlayCoordinator: testCase.coordinator
            windowStore: testCase.windowStore
            windowController: testCase.controller
            iconSources: ({})
            fallbackIconSource: ""
        }
    }

    function window(id, key, title, focused, urgent) {
        return {
            id: id,
            output: "A",
            workspace: "1",
            title: title,
            focused: Boolean(focused),
            urgent: Boolean(urgent),
            identity: {
                confident: !key.startsWith("unresolved:"),
                key: key,
                name: key,
                icon: "application-x-executable",
                desktopEntry: ""
            }
        };
    }

    function init() {
        controller.calls = [];
        coordinator.calls = [];
        overlayStore.panel = "none";
        overlayStore.output = "";
        overlayStore.context = ({});
        windowStore.windows = [];
        windowStore.orderByWorkspace = ({});
    }

    function test_groupMenuSupportsPointerKeyboardCloseAndUrgency() {
        windowStore.publish([window(10, "desktop:group", "Documento A", false, false), window(11, "desktop:group", "Documento B", false, true)]);
        overlayStore.show("window_group", "A", {
            workspace: "1",
            groupKey: "desktop:group"
        });

        const pointerContent = createTemporaryObject(contentComponent, testCase);
        verify(pointerContent !== null);
        compare(pointerContent.entries.length, 2);
        tryVerify(() => findChild(pointerContent, "windowEntry-1") !== null);
        const urgentEntry = findChild(pointerContent, "windowEntry-1");
        verify(urgentEntry !== null);
        compare(urgentEntry.border.color.toString(), "#ef7e87");
        mouseClick(urgentEntry);
        verify(controller.calls.includes("focus:11"));

        overlayStore.show("window_group", "A", {
            workspace: "1",
            groupKey: "desktop:group"
        });
        const keyboardContent = createTemporaryObject(contentComponent, testCase);
        verify(keyboardContent !== null);
        tryVerify(() => findChild(keyboardContent, "windowEntryFocus-0") !== null);
        const entryFocus = findChild(keyboardContent, "windowEntryFocus-0");
        verify(entryFocus !== null);
        entryFocus.forceActiveFocus();
        keyClick(Qt.Key_Delete);
        verify(controller.calls.includes("close:10"));

        tryVerify(() => findChild(keyboardContent, "windowClose-1") !== null);
        const closeButton = findChild(keyboardContent, "windowClose-1");
        verify(closeButton !== null);
        mouseClick(closeButton);
        verify(controller.calls.includes("close:11"));
    }

    function test_overflowShowsUnknownWindowTitleAndOpensGroups() {
        windowStore.publish([window(20, "desktop:first", "Primeira", true, false), window(21, "unresolved:21", "Título preservado", false, false), window(22, "desktop:group", "Janela A", false, false), window(23, "desktop:group", "Janela B", false, false)]);
        overlayStore.show("overflow", "A", {
            workspace: "1"
        });

        const content = createTemporaryObject(contentComponent, testCase);
        verify(content !== null);
        verify(content.entries.length > 0);
        const unresolved = content.entries.find(entry => entry.key === "unresolved:21");
        verify(unresolved !== undefined);
        compare(unresolved.displayName, "Título preservado");

        const groupIndex = content.entries.findIndex(entry => entry.key === "desktop:group");
        verify(groupIndex >= 0);
        tryVerify(() => findChild(content, "windowEntry-" + groupIndex) !== null);
        const groupEntry = findChild(content, "windowEntry-" + groupIndex);
        verify(groupEntry !== null);
        mouseClick(groupEntry);
        verify(coordinator.calls.some(call => call.endsWith(":desktop:group")));
    }
}
