import QtQuick
import Quickshell

PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    color: "transparent"
    implicitHeight: 1
    focusable: false
    exclusiveZone: 0

    anchors {
        left: true
        right: true
        bottom: true
    }

    signal surfaceReady
    signal surfaceRemoved

    Component.onCompleted: root.surfaceReady()
    Component.onDestruction: root.surfaceRemoved()
}
