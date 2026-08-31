pragma ComponentBehavior: Bound

import QtQuick

FocusScope {
    id: root

    required property var launcherStore
    required property var launcherController
    required property var overlayCoordinator
    required property var iconSources
    required property string fallbackIconSource
    required property real opacityValue

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#222a39"
        opacity: root.opacityValue
        border.color: "#53627a"
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        Text {
            text: root.launcherStore.query.indexOf(">") === 0 ? "Comandos e ações" : "Aplicativos e arquivos"
            color: "#f4f7fb"
            font.pixelSize: 21
            font.weight: Font.DemiBold
        }

        Rectangle {
            width: parent.width
            height: 42
            radius: 8
            color: searchInput.activeFocus ? "#35445d" : "#2d374a"
            border.color: searchInput.activeFocus ? "#91b4e8" : "transparent"

            TextInput {
                id: searchInput
                objectName: "launcherSearch"
                focus: true
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 13
                verticalAlignment: TextInput.AlignVCenter
                color: "#f4f7fb"
                selectionColor: "#526f9f"
                font.pixelSize: 14
                clip: true
                enabled: !root.launcherStore.launching
                onTextChanged: root.launcherController.setQuery(text)
                Keys.onEscapePressed: root.overlayCoordinator.close()
                Keys.onDownPressed: results.incrementCurrentIndex()
                Keys.onUpPressed: results.decrementCurrentIndex()
                Keys.onEnterPressed: root.activateCurrent()
                Keys.onReturnPressed: root.activateCurrent()
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text.length === 0
                text: "Pesquisar aplicativos e arquivos ou usar >"
                color: "#aeb9ca"
                font.pixelSize: 14
            }
        }

        Text {
            visible: root.launcherStore.failureMessage !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.launcherStore.failureMessage
            color: "#ef9aa1"
            font.pixelSize: 12
        }

        Item {
            width: parent.width
            height: Math.max(1, parent.height - 96 - (root.launcherStore.failureMessage !== "" ? 36 : 0))

            Text {
                anchors.centerIn: parent
                visible: root.launcherStore.results.length === 0
                width: Math.min(parent.width, 420)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.launcherStore.fileSearching ? "Pesquisando arquivos…" : root.launcherStore.query === "" ? "Nenhum item usado recentemente." : "Nenhum resultado encontrado."
                color: "#aeb9ca"
                font.pixelSize: 14
            }

            ListView {
                id: results
                objectName: "launcherResults"
                anchors.fill: parent
                clip: true
                spacing: 4
                model: root.launcherStore.results
                currentIndex: count > 0 ? 0 : -1
                delegate: Rectangle {
                    id: resultButton
                    required property var modelData
                    required property int index
                    objectName: "launcherResult-" + index
                    width: ListView.view.width
                    height: 52
                    radius: 8
                    color: ListView.isCurrentItem || resultMouse.containsMouse ? "#3b4960" : "#2d374a"
                    opacity: root.launcherStore.launching || resultButton.modelData.available === false ? 0.55 : 1

                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        source: root.iconSources[resultButton.modelData.icon] || root.fallbackIconSource
                        fillMode: Image.PreserveAspectFit
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 50
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: resultButton.modelData.name
                            color: "#f4f7fb"
                            font.pixelSize: 14
                        }
                        Text {
                            width: parent.width
                            visible: resultButton.modelData.genericName !== ""
                            elide: Text.ElideRight
                            text: resultButton.modelData.genericName
                            color: "#aeb9ca"
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: resultMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.launcherStore.launching
                        onClicked: {
                            results.currentIndex = resultButton.index;
                            root.launcherController.activate(resultButton.modelData);
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.overlayCoordinator.close()
    }

    function activateCurrent() {
        if (!root.launcherStore.launching && results.currentIndex >= 0)
            root.launcherController.activate(root.launcherStore.results[results.currentIndex]);
    }

    function focusSearch() {
        searchInput.forceActiveFocus();
    }
}
