import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// volume OSD: bottom-center, click-through, shows on volume/mute change
PanelWindow {
    id: osd
    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property real vol: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false
    property bool shown: false
    property bool armed: false      // skip the burst of change signals while pipewire binds at startup

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    function poke() { if (!armed) return; shown = true; hide.restart() }
    Timer { id: hide; interval: 1200; onTriggered: osd.shown = false }
    Timer { interval: 1500; running: true; onTriggered: osd.armed = true }
    Connections {
        target: osd.audio
        function onVolumeChanged() { osd.poke() }
        function onMutedChanged() { osd.poke() }
    }

    anchors.bottom: true
    margins.bottom: 90
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clawd-osd"
    implicitWidth: 280
    implicitHeight: 44
    mask: Region {}
    visible: shown
    color: Theme.bg

    Rectangle { anchors.fill: parent; color: "transparent"; border.color: Theme.border; border.width: 1 }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12
        Label { text: osd.muted ? "muted" : "vol"; color: Theme.muted; Layout.preferredWidth: 40 }
        Meter {
            Layout.fillWidth: true
            value: osd.vol
            fill: osd.muted ? Theme.muted : Theme.accent
        }
        Label {
            text: Math.round(osd.vol * 100)
            color: osd.muted ? Theme.muted : Theme.text
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 28
        }
    }
}
