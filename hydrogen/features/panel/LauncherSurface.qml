import QtQuick
import Quickshell

PanelWindow {
    id: root

    required property var modelData
    required property var configuration
    required property var overlayCoordinator

    readonly property int panelWidth: Math.min(620, Math.max(280, screen ? screen.width - 24 : 280))
    readonly property int panelHeight: Math.min(420, Math.max(220, screen ? screen.height - configuration.effective.bar.height - 32 : 220))

    screen: modelData
    color: "transparent"
    implicitHeight: panelHeight + configuration.effective.bar.height + 10
    exclusiveZone: 0
    focusable: true
    aboveWindows: true

    anchors {
        left: true
        right: true
        bottom: true
    }
    Item {
        id: panel
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.configuration.effective.bar.height + 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.panelWidth
        height: root.panelHeight

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#222a39"
            opacity: root.configuration.effective.appearance.opacity
            border.color: "#53627a"
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            Text {
                text: "Aplicativos"
                color: "#f4f7fb"
                font.pixelSize: 21
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: parent.width
                height: 42
                radius: 8
                color: searchFocus.activeFocus ? "#35445d" : "#2d374a"
                border.color: searchFocus.activeFocus ? "#91b4e8" : "transparent"

                FocusScope {
                    id: searchFocus
                    anchors.fill: parent
                    activeFocusOnTab: true
                    Component.onCompleted: forceActiveFocus()
                    Keys.onEscapePressed: root.overlayCoordinator.close()
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Pesquisar aplicativos"
                    color: "#aeb9ca"
                    font.pixelSize: 14
                }
            }

            Item {
                width: parent.width
                height: Math.max(1, parent.height - 84)

                Text {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, 420)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "A pesquisa de aplicativos estará disponível no próximo marco."
                    color: "#aeb9ca"
                    font.pixelSize: 14
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.overlayCoordinator.close()
    }
}
