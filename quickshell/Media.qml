import QtQuick
import Quickshell.Services.Mpris

// now playing: dancing bars + title. click play/pause, right-click next, middle previous, scroll skips.
Rectangle {
    id: m
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.playbackState === MprisPlaybackState.Playing) || players[0] || null
    readonly property bool playing: !!player && player.playbackState === MprisPlaybackState.Playing
    readonly property string title: player ? [player.trackTitle, player.trackArtist].filter(s => s).join(" - ") : ""

    visible: !!player && title !== ""
    implicitWidth: visible ? row.implicitWidth + 24 : 0
    color: ma.containsMouse ? Theme.surface : "transparent"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Row {        // equalizer
            anchors.verticalCenter: parent.verticalCenter
            height: 12
            spacing: 2
            Repeater {
                model: [430, 310, 520]
                delegate: Rectangle {
                    id: eq
                    required property int modelData
                    anchors.bottom: parent.bottom
                    width: 3
                    height: 3
                    color: m.playing ? Theme.accent : Theme.muted
                    SequentialAnimation on height {
                        running: m.playing
                        loops: Animation.Infinite
                        NumberAnimation { to: 12; duration: modelData / 2; easing.type: Easing.OutQuad }
                        NumberAnimation { to: 3; duration: modelData / 2; easing.type: Easing.InQuad }
                        onRunningChanged: if (!running) eq.height = 3
                    }
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 260)
            elide: Text.ElideRight
            text: m.title
            color: ma.containsMouse ? Theme.text : Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.fs
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => {
            if (!m.player) return
            if (e.button === Qt.RightButton) m.player.next()
            else if (e.button === Qt.MiddleButton) m.player.previous()
            else m.player.togglePlaying()
        }
        onWheel: w => { if (m.player) (w.angleDelta.y > 0 ? m.player.previous() : m.player.next()) }
    }
}
