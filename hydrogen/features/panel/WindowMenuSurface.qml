pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

PanelWindow {
    id: root
    objectName: "windowMenuSurface"

    required property var modelData
    required property var configuration
    required property var overlayStore
    required property var overlayCoordinator
    required property var windowStore
    required property var windowController
    property real availableWidth: modelData.width

    readonly property var entries: content.entries
    readonly property int contentHeight: content.contentHeight

    screen: modelData
    color: "transparent"
    implicitHeight: contentHeight + configuration.effective.bar.height + 10
    exclusiveZone: 0
    focusable: true
    aboveWindows: true
    anchors {
        left: true
        right: true
        bottom: true
    }

    WindowMenuContent {
        id: content
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.configuration.effective.bar.height + 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(440, parent.width - 24)
        height: contentHeight
        outputName: root.modelData.name
        availableWidth: root.availableWidth
        opacityValue: root.configuration.effective.appearance.opacity
        overlayStore: root.overlayStore
        overlayCoordinator: root.overlayCoordinator
        windowStore: root.windowStore
        windowController: root.windowController
        iconSources: {
            const sources = {};
            content.entries.forEach(entry => {
                const name = root.overlayStore.panel === "window_group" ? entry.identity.icon : entry.icon;
                sources[name] = Quickshell.iconPath(name, "application-x-executable");
            });
            return sources;
        }
        fallbackIconSource: Quickshell.iconPath("application-x-executable")
    }
}
