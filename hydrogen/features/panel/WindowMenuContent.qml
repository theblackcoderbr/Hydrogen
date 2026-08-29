pragma ComponentBehavior: Bound

import QtQuick
import "../../logic/WindowNavigation.js" as Navigation

Item {
    id: root

    required property string outputName
    required property real availableWidth
    required property real opacityValue
    required property var overlayStore
    required property var overlayCoordinator
    required property var windowStore
    required property var windowController
    required property var iconSources
    required property string fallbackIconSource

    readonly property string workspaceName: String(overlayStore.context.workspace || "")
    readonly property var allGroups: windowStore.groups(outputName, workspaceName)
    readonly property var entries: overlayStore.panel === "window_group" ? windowStore.windowsForGroup(outputName, workspaceName, String(overlayStore.context.groupKey || "")) : Navigation.splitOverflow(allGroups, Math.max(1, Math.floor((availableWidth - 220) / 42))).overflow
    readonly property int contentHeight: Math.min(420, Math.max(72, entries.length * 48 + 24))

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#222a39"
        opacity: root.opacityValue
        border.color: "#53627a"

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 10
            clip: true
            spacing: 4
            model: root.entries
            delegate: Rectangle {
                id: entryButton
                required property var modelData
                required property int index
                readonly property string iconName: root.overlayStore.panel === "window_group" ? modelData.identity.icon : modelData.icon
                objectName: "windowEntry-" + index
                width: ListView.view.width
                height: 44
                radius: 7
                color: entryFocus.activeFocus || entryMouse.containsMouse ? "#3b4960" : "#2d374a"
                border.color: modelData.urgent ? "#ef7e87" : "transparent"

                FocusScope {
                    id: entryFocus
                    objectName: "windowEntryFocus-" + entryButton.index
                    anchors.fill: parent
                    activeFocusOnTab: true
                    Keys.onEnterPressed: root.activateEntry(entryButton.modelData)
                    Keys.onReturnPressed: root.activateEntry(entryButton.modelData)
                    Keys.onDeletePressed: {
                        if (root.overlayStore.panel === "window_group")
                            root.windowController.closeWindow(entryButton.modelData.id);
                    }
                    Keys.onEscapePressed: root.overlayCoordinator.close()
                }
                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    source: root.iconSources[entryButton.iconName] || root.fallbackIconSource
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 44
                    anchors.right: closeButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.overlayStore.panel === "window_group" ? entryButton.modelData.title : entryButton.modelData.displayName
                    color: "#f4f7fb"
                    font.pixelSize: 13
                }
                Rectangle {
                    id: closeButton
                    objectName: "windowClose-" + entryButton.index
                    visible: root.overlayStore.panel === "window_group"
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? 28 : 0
                    height: 28
                    radius: 6
                    color: closeMouse.containsMouse ? "#7d4650" : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: "#f4f7fb"
                        font.pixelSize: 18
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.windowController.closeWindow(entryButton.modelData.id)
                    }
                }
                MouseArea {
                    id: entryMouse
                    anchors.left: parent.left
                    anchors.right: closeButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activateEntry(entryButton.modelData)
                }
                Component.onCompleted: {
                    if (index === 0)
                        entryFocus.forceActiveFocus();
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.overlayCoordinator.close()
    }

    function activateEntry(entry) {
        if (root.overlayStore.panel === "window_group") {
            root.windowController.focusWindow(entry.id);
            root.overlayCoordinator.close();
        } else if (entry.windows.length === 1) {
            if (!entry.windows[0].focused)
                root.windowController.focusWindow(entry.windows[0].id);
            root.overlayCoordinator.close();
        } else {
            root.overlayCoordinator.showWindowGroup(root.outputName, root.workspaceName, entry.key);
        }
    }
}
