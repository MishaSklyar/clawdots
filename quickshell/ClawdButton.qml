import QtQuick
import Quickshell.Hyprland

// the bar's Clawd: blinks, glances around, hops on workspace switch, runs when the cpu is busy
Rectangle {
    id: b
    readonly property bool opened: UI.open === "launcher"
    readonly property bool busy: Stats.cpu > 60
    implicitWidth: 40
    color: opened ? Theme.surface : (ma.containsMouse ? Theme.surface : "transparent")
    Component.onCompleted: UI.buttons["launcher"] = b

    Clawd {
        id: sprite
        unit: 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((b.height - height) / 2) + hopOffset
        property real hopOffset: 0
        frame: b.busy ? runFrame : 0
        property int runFrame: 1

        SequentialAnimation {
            id: hop
            NumberAnimation { target: sprite; property: "hopOffset"; to: -6; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: sprite; property: "hopOffset"; to: 0; duration: 260; easing.type: Easing.OutBounce }
        }
    }

    Timer {     // legs while busy
        interval: 140; repeat: true; running: b.busy
        onTriggered: sprite.runFrame = sprite.runFrame === 1 ? 2 : 1
    }
    Timer {     // blink every few seconds
        id: blinker
        interval: 2500 + Math.random() * 3000; repeat: true; running: true
        onTriggered: { sprite.blink = true; unblink.start(); interval = 2500 + Math.random() * 3000 }
    }
    Timer { id: unblink; interval: 120; onTriggered: sprite.blink = false }
    Timer {     // glance left / right now and then
        interval: 7000; repeat: true; running: true
        onTriggered: { sprite.look = [-1, 1][Math.floor(Math.random() * 2)]; unlook.restart() }
    }
    Timer { id: unlook; interval: 900; onTriggered: sprite.look = 0 }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { hop.restart() }
    }

    Rectangle {      // accent underline while open
        visible: b.opened
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
        color: Theme.accent
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: UI.toggle("launcher", b)
        onEntered: { sprite.look = 0; hop.restart() }
    }
}
