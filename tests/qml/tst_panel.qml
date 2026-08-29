import QtQuick
import QtTest
import "../../hydrogen/domain" as Domain
import "../../hydrogen/logic/Panel.js" as Panel

TestCase {
    id: testCase
    name: "BasicPanel"

    property QtObject lifecycle: QtObject {
        property string state: "running"
    }
    property Domain.SwayStore swayStore: Domain.SwayStore {}
    property Domain.OverlayStore overlayStore: Domain.OverlayStore {}
    property Domain.OverlayCoordinator coordinator: Domain.OverlayCoordinator {
        lifecycle: testCase.lifecycle
        overlayStore: testCase.overlayStore
        swayStore: testCase.swayStore
    }

    function init() {
        lifecycle.state = "running";
        overlayStore.panel = "none";
        overlayStore.output = "";
        overlayStore.generation = 0;
        swayStore.publishSnapshot([
            { name: "HEADLESS-1", width: 1280, height: 720, scale: 1, focused: true },
            { name: "HEADLESS-2", width: 1024, height: 768, scale: 1.25, focused: false }
        ], [], "HEADLESS-1", "test");
    }

    function test_layoutRespondsWithoutMinimumResolution() {
        const compact = Panel.layoutForWidth(320);
        const wide = Panel.layoutForWidth(1920);
        verify(compact.compact);
        verify(!wide.compact);
        verify(compact.sectionWidth < wide.sectionWidth);
        verify(compact.launcherSize > 0);
    }

    function test_clockHasStableTwentyFourHourShape() {
        compare(Panel.formatClock(new Date(2026, 7, 28, 7, 5)), "07:05");
    }

    function test_launcherPinsOutputAndDoesNotTeleportOnFocusChange() {
        const opened = coordinator.showLauncher("");
        verify(opened.ok);
        compare(overlayStore.output, "HEADLESS-1");

        swayStore.publishSnapshot([
            { name: "HEADLESS-1", width: 1280, height: 720, scale: 1, focused: false },
            { name: "HEADLESS-2", width: 1024, height: 768, scale: 1.25, focused: true }
        ], [], "HEADLESS-2", "test");
        coordinator.reconcileOutputs();
        compare(overlayStore.output, "HEADLESS-1");
    }

    function test_explicitOtherOutputRecreatesLogicalOverlay() {
        coordinator.showLauncher("");
        const firstGeneration = overlayStore.generation;
        const moved = coordinator.showLauncher("HEADLESS-2");
        verify(moved.ok);
        compare(overlayStore.output, "HEADLESS-2");
        compare(overlayStore.generation, firstGeneration + 1);
    }

    function test_hotplugClosesOverlayOnlyWhenItsOutputDisappears() {
        coordinator.showLauncher("HEADLESS-2");
        swayStore.publishSnapshot([
            { name: "HEADLESS-1", width: 1280, height: 720, scale: 1, focused: true }
        ], [], "HEADLESS-1", "test");
        coordinator.reconcileOutputs();
        verify(!overlayStore.open);
    }

    function test_openIsRejectedOutsideOperationalLifecycle() {
        lifecycle.state = "shutting_down";
        const result = coordinator.showLauncher("");
        verify(!result.ok);
        compare(result.code, "lifecycle_unavailable");
    }
}
