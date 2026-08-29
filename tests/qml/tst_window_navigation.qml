import QtQuick
import QtTest
import "../../hydrogen/domain" as Domain

TestCase {
    id: testCase
    name: "WindowNavigation"

    property Domain.WindowStore store: Domain.WindowStore {}
    property QtObject lifecycle: QtObject {
        property string state: "running"
    }
    property QtObject provider: QtObject {
        property var commands: []
        function dispatch(command) {
            commands = commands.concat([command]);
            return true;
        }
    }
    property Domain.WindowNavigationController controller: Domain.WindowNavigationController {
        lifecycle: testCase.lifecycle
        swayProvider: testCase.provider
    }

    function window(id, key, focused) {
        return {
            id: id,
            output: "A",
            workspace: "1",
            focused: Boolean(focused),
            urgent: false,
            identity: {
                key: key,
                name: key,
                icon: "application-x-executable",
                desktopEntry: ""
            }
        };
    }

    function init() {
        store.windows = [];
        store.orderByWorkspace = ({});
        store.generation = 0;
        provider.commands = [];
        lifecycle.state = "running";
    }

    function test_stableOrderSurvivesFocusAndReopenReturnsAtEnd() {
        store.publish([window(1, "a", true), window(2, "b", false)]);
        compare(store.groups("A", "1").map(group => group.key), ["a", "b"]);
        store.publish([window(1, "a", false), window(2, "b", true)]);
        compare(store.groups("A", "1").map(group => group.key), ["a", "b"]);
        store.publish([window(2, "b", true)]);
        store.publish([window(2, "b", false), window(3, "a", true)]);
        compare(store.groups("A", "1").map(group => group.key), ["b", "a"]);
    }

    function test_controllerBuildsOnlyStructuredNumericCommands() {
        verify(controller.focusWindow(42));
        verify(controller.closeWindow(42));
        verify(controller.focusWorkspace(3));
        verify(controller.moveFocusedToWorkspace(4, 3));
        compare(provider.commands, ["[con_id=42] focus", "[con_id=42] kill", "workspace number 3", "move container to workspace number 4"]);
        verify(!controller.focusWindow("1; exit"));
        compare(provider.commands.length, 4);
    }

    function test_activeWindowActivationCanBeSkippedByView() {
        const active = window(1, "a", true);
        store.publish([active]);
        verify(store.groups("A", "1")[0].focused);
    }

    function test_shutdownRejectsNavigationMutations() {
        lifecycle.state = "shutting_down";
        verify(!controller.focusWorkspace(2));
        verify(!controller.closeWindow(1));
        compare(provider.commands.length, 0);
    }
}
