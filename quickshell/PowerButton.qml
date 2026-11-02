import QtQuick
import Quickshell

// first click arms ("sure?"), second click within 2.5s runs it
Rectangle {
    id: pb
    property string label
    property var cmd: []
    property bool armed: false
    color: armed ? Theme.accent : (ma.containsMouse ? Theme.surface : "transparent")
    border.color: armed ? Theme.accent : Theme.border
    border.width: 1

    Label {
        anchors.centerIn: parent
        text: pb.armed ? "sure?" : pb.label
        color: pb.armed ? Theme.black : Theme.text
    }
    Timer { id: t; interval: 2500; onTriggered: pb.armed = false }
    Connections {
        target: UI
        function onOpenChanged() { pb.armed = false }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (pb.armed) {
                UI.open = ""
                Quickshell.execDetached(pb.cmd)
            } else {
                pb.armed = true
                t.restart()
            }
        }
    }
}
