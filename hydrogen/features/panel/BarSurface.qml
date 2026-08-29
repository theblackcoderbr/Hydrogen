pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../logic/Panel.js" as Panel
import "../../logic/WindowNavigation.js" as Navigation

PanelWindow {
    id: root

    required property var modelData
    required property var configuration
    required property var overlayCoordinator
    required property var swayStore
    required property var windowStore
    required property var windowController

    readonly property var layout: Panel.layoutForWidth(root.screen ? root.screen.width : 0)
    readonly property var currentWorkspace: root.swayStore.workspaces.find(workspace => workspace.output === root.modelData.name && (workspace.focused || workspace.active)) || null
    readonly property var workspaceItems: Navigation.visibleWorkspaces(root.swayStore.workspaces, root.windowStore.windows, root.modelData.name)
    readonly property var appGroups: root.currentWorkspace ? root.windowStore.groups(root.modelData.name, root.currentWorkspace.name) : []
    readonly property int groupCapacity: Math.max(1, Math.min(10, Math.floor(centerSection.width / 42)))
    readonly property var groupSplit: Navigation.splitOverflow(root.appGroups, root.groupCapacity)
    property string clockText: Panel.formatClock(new Date())

    screen: modelData
    color: "transparent"
    implicitHeight: configuration.effective.bar.height
    exclusiveZone: implicitHeight
    focusable: false
    aboveWindows: true

    anchors {
        left: true
        right: true
        bottom: true
    }

    signal surfaceReady
    signal surfaceRemoved

    Rectangle {
        anchors.fill: parent
        color: "#1c2230"
        opacity: root.configuration.effective.appearance.opacity
    }

    Row {
        id: leftSection
        anchors.left: parent.left
        anchors.leftMargin: root.layout.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        spacing: 5

        Rectangle {
            id: launcherButton
            anchors.verticalCenter: parent.verticalCenter
            width: root.layout.launcherSize
            height: width
            radius: 8
            color: launcherMouse.containsMouse || launcherFocus.activeFocus ? "#52647f" : "#344156"

            FocusScope {
                id: launcherFocus
                anchors.fill: parent
                activeFocusOnTab: true
                Keys.onEnterPressed: root.overlayCoordinator.toggleLauncher("")
                Keys.onReturnPressed: root.overlayCoordinator.toggleLauncher("")
                Keys.onSpacePressed: root.overlayCoordinator.toggleLauncher("")
            }
            Text {
                anchors.centerIn: parent
                text: "H"
                color: "#f4f7fb"
                font.bold: true
                font.pixelSize: 16
            }
            MouseArea {
                id: launcherMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.overlayCoordinator.toggleLauncher("")
            }
        }

        Repeater {
            model: root.workspaceItems
            delegate: Rectangle {
                id: workspaceButton
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                radius: 7
                color: modelData.urgent ? (modelData.focused || modelData.active ? "#a85b63" : "#713f4a") : (modelData.focused || modelData.active ? "#526f9f" : "#303c50")
                border.color: workspaceFocus.activeFocus ? "#b9d3ff" : "transparent"

                FocusScope {
                    id: workspaceFocus
                    anchors.fill: parent
                    activeFocusOnTab: true
                    Keys.onEnterPressed: root.windowController.focusWorkspace(workspaceButton.modelData.number)
                    Keys.onReturnPressed: root.windowController.focusWorkspace(workspaceButton.modelData.number)
                }
                Text {
                    anchors.centerIn: parent
                    text: workspaceButton.modelData.number
                    color: "#f4f7fb"
                    font.pixelSize: 13
                    font.bold: workspaceButton.modelData.focused || workspaceButton.modelData.active
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton)
                            root.windowController.moveFocusedToWorkspace(workspaceButton.modelData.number, root.currentWorkspace ? root.currentWorkspace.number : -1);
                        else
                            root.windowController.focusWorkspace(workspaceButton.modelData.number);
                    }
                }
            }
        }

        WheelHandler {
            onWheel: event => {
                if (root.workspaceItems.length < 2 || !root.currentWorkspace)
                    return;
                let index = root.workspaceItems.findIndex(workspace => workspace.number === root.currentWorkspace.number);
                const direction = event.angleDelta.y < 0 ? 1 : -1;
                index = (index + direction + root.workspaceItems.length) % root.workspaceItems.length;
                root.windowController.focusWorkspace(root.workspaceItems[index].number);
            }
        }
    }

    Row {
        id: centerSection
        anchors.left: leftSection.right
        anchors.leftMargin: 10
        anchors.right: rightSection.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        spacing: 4

        Repeater {
            model: root.groupSplit.visible
            delegate: Rectangle {
                id: groupButton
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 34
                radius: 8
                color: modelData.focused ? "#526f9f" : (groupMouse.containsMouse || groupFocus.activeFocus ? "#46546b" : "#303a4d")
                border.color: modelData.urgent ? "#ef7e87" : "transparent"
                border.width: modelData.urgent ? 2 : 0

                FocusScope {
                    id: groupFocus
                    anchors.fill: parent
                    activeFocusOnTab: true
                    Keys.onEnterPressed: root.activateGroup(groupButton.modelData)
                    Keys.onReturnPressed: root.activateGroup(groupButton.modelData)
                    Keys.onDeletePressed: {
                        if (groupButton.modelData.windows.length === 1)
                            root.windowController.closeWindow(groupButton.modelData.windows[0].id);
                    }
                }
                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: Quickshell.iconPath(groupButton.modelData.icon, "application-x-executable")
                    fillMode: Image.PreserveAspectFit
                }
                Rectangle {
                    visible: groupButton.modelData.windows.length > 1
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 16
                    height: 16
                    radius: 8
                    color: "#d9e6fa"
                    Text {
                        anchors.centerIn: parent
                        text: groupButton.modelData.windows.length
                        color: "#1c2230"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
                MouseArea {
                    id: groupMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activateGroup(groupButton.modelData)
                }
            }
        }

        Rectangle {
            visible: root.groupSplit.overflow.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? 38 : 0
            height: 34
            radius: 8
            color: overflowMouse.containsMouse || overflowFocus.activeFocus ? "#46546b" : "#303a4d"
            FocusScope {
                id: overflowFocus
                anchors.fill: parent
                activeFocusOnTab: parent.visible
                Keys.onEnterPressed: root.openOverflow()
                Keys.onReturnPressed: root.openOverflow()
            }
            Text {
                anchors.centerIn: parent
                text: "⋯"
                color: "#f4f7fb"
                font.pixelSize: 20
            }
            MouseArea {
                id: overflowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openOverflow()
            }
        }
    }

    Item {
        id: rightSection
        anchors.right: parent.right
        anchors.rightMargin: root.layout.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        width: root.layout.compact ? 62 : 82
        height: parent.height
        Text {
            anchors.centerIn: parent
            text: root.clockText
            color: "#f4f7fb"
            font.pixelSize: root.layout.compact ? 14 : 15
            font.weight: Font.DemiBold
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.clockText = Panel.formatClock(new Date())
    }

    function activateGroup(group) {
        if (group.windows.length === 1) {
            if (!group.windows[0].focused)
                root.windowController.focusWindow(group.windows[0].id);
        } else if (root.currentWorkspace) {
            root.overlayCoordinator.showWindowGroup(root.modelData.name, root.currentWorkspace.name, group.key);
        }
    }

    function openOverflow() {
        if (root.currentWorkspace)
            root.overlayCoordinator.showOverflow(root.modelData.name, root.currentWorkspace.name);
    }

    Component.onCompleted: root.surfaceReady()
    Component.onDestruction: root.surfaceRemoved()
}
