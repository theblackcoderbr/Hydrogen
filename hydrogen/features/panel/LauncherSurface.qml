pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var modelData
    required property var configuration
    required property var overlayCoordinator
    required property var launcherStore
    required property var launcherController

    readonly property int panelWidth: Math.min(620, Math.max(280, screen ? screen.width - 24 : 280))
    readonly property int panelHeight: Math.min(420, Math.max(220, screen ? screen.height - configuration.effective.bar.height - 32 : 220))

    screen: modelData
    color: "transparent"
    implicitHeight: panelHeight + configuration.effective.bar.height + 10
    exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    aboveWindows: true

    anchors {
        left: true
        right: true
        bottom: true
    }

    LauncherContent {
        id: content
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.configuration.effective.bar.height + 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.panelWidth
        height: root.panelHeight
        launcherStore: root.launcherStore
        launcherController: root.launcherController
        overlayCoordinator: root.overlayCoordinator
        opacityValue: root.configuration.effective.appearance.opacity
        iconSources: {
            const sources = {};
            root.launcherStore.results.forEach(entry => sources[entry.icon] = Quickshell.iconPath(entry.icon, "application-x-executable"));
            return sources;
        }
        fallbackIconSource: Quickshell.iconPath("application-x-executable")
    }

    Component.onCompleted: {
        root.launcherController.setQuery("");
        Qt.callLater(content.focusSearch);
    }
}
