import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

ColumnLayout {
    id: p
    spacing: 10
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property real vol: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    PwObjectTracker { objects: Pipewire.nodes.values }

    RowLayout {
        Layout.fillWidth: true
        Section { title: "volume" }
        Label {
            text: p.muted ? "muted" : Math.round(p.vol * 100) + "%"
            color: p.muted ? Theme.muted : Theme.accent
            font.pixelSize: 22
            font.bold: true
        }
    }

    // slider
    Item {
        id: s
        Layout.fillWidth: true
        Layout.preferredHeight: 20
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            color: Theme.surface
            Rectangle { width: parent.width * Math.min(1, p.vol); height: parent.height; color: p.muted ? Theme.muted : Theme.accent }
        }
        Rectangle {
            x: Math.min(1, p.vol) * (s.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 20
            color: Theme.text
        }
        MouseArea {
            anchors.fill: parent
            function setVol(mx) { if (p.audio) p.audio.volume = Math.max(0, Math.min(1, mx / width)) }
            onPressed: m => setVol(m.x)
            onPositionChanged: m => { if (pressed) setVol(m.x) }
            onWheel: w => { if (p.audio) p.audio.volume = Math.max(0, Math.min(1, p.vol + (w.angleDelta.y > 0 ? 0.03 : -0.03))) }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        color: p.muted ? Theme.accent : (mm.containsMouse ? Theme.surface : "transparent")
        border.color: p.muted ? Theme.accent : Theme.border
        border.width: 1
        Label { anchors.centerIn: parent; text: p.muted ? "unmute" : "mute"; color: p.muted ? Theme.black : Theme.text }
        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; onClicked: if (p.audio) p.audio.muted = !p.audio.muted }
    }

    Section { title: "output" }
    Repeater {
        model: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
        delegate: Rectangle {
            required property var modelData
            readonly property bool current: p.sink && modelData.id === p.sink.id
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            color: current ? Theme.accent : (om.containsMouse ? Theme.surface : "transparent")
            Label {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: modelData.description || modelData.nickname || modelData.name
                color: parent.current ? Theme.black : Theme.text
            }
            MouseArea { id: om; anchors.fill: parent; hoverEnabled: true; onClicked: Pipewire.preferredDefaultAudioSink = modelData }
        }
    }
}
