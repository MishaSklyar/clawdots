import QtQuick

Rectangle {
    property real value: 0        // 0..1
    property color fill: Theme.accent
    implicitHeight: 8
    color: Theme.surface
    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, parent.value))
        height: parent.height
        color: parent.fill
    }
}
