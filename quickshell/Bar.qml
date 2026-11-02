import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

Scope {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    function volLabel() {
        const a = sink ? sink.audio : null
        if (!a) return "vol -"
        return a.muted ? "muted" : "vol " + Math.round(a.volume * 100) + "%"
    }

    function nudgeVol(delta) {
        const a = sink ? sink.audio : null
        if (a) a.volume = Math.max(0, Math.min(1, a.volume + (delta > 0 ? 0.03 : -0.03)))
    }

    // workspaces 1-5 always, plus any other that exists
    readonly property var wsIds: {
        const s = new Set([1, 2, 3, 4, 5])
        for (const w of Hyprland.workspaces.values) if (w.id > 0) s.add(w.id)
        return Array.from(s).sort((a, b) => a - b)
    }

    // keyboard layout: "en" / "ru"
    property string kb: ""
    function kbShort(name) { return name.slice(0, 2).toLowerCase() }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (ev.name === "activelayout") root.kb = root.kbShort(ev.data.split(",").pop()) }
    }
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const k = JSON.parse(text).keyboards.find(k => k.main) 
                    if (k) root.kb = root.kbShort(k.active_keymap)
                } catch (e) {}
            }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Launcher { id: menu }                                                   // clawd button: left, with power
    Launcher { id: spotlight; name: "spotlight"; centered: true; showPower: false }   // super+space: centered

    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        implicitHeight: 30
        color: Theme.bg

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }

        // left: clawd menu + workspaces
        ClawdButton {
            id: clawdBtn
            anchors.left: parent.left
            anchors.leftMargin: 4
            height: parent.height - 1
        }
        MouseArea {      // wheel over workspaces: next / previous
            anchors.left: clawdBtn.right
            width: wsRow.width
            height: parent.height - 1
            acceptedButtons: Qt.NoButton
            onWheel: w => Hyprland.dispatch('hl.dsp.focus({ workspace = "' + (w.angleDelta.y > 0 ? "e-1" : "e+1") + '" })')

            Rectangle {    // active workspace highlight, slides between numbers
                readonly property int idx: Hyprland.focusedWorkspace ? root.wsIds.indexOf(Hyprland.focusedWorkspace.id) : -1
                visible: idx >= 0
                x: Math.max(0, idx) * 32
                width: 32
                height: parent.height
                color: Theme.accent
                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            }

            Row {
                id: wsRow
                height: parent.height
                Repeater {
                    model: root.wsIds
                    delegate: Rectangle {
                        required property int modelData
                        readonly property int wsid: modelData
                        readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsid) || null
                        readonly property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsid
                        readonly property bool urgent: !!ws && ws.urgent
                        width: 32
                        height: parent.height
                        color: !active && wm.containsMouse ? Theme.surface : "transparent"
                        Label {
                            anchors.centerIn: parent
                            text: parent.wsid
                            Behavior on color { ColorAnimation { duration: 120 } }
                            color: parent.active ? Theme.black : (parent.urgent ? Theme.accent : (parent.ws ? Theme.text : Theme.muted))
                        }
                        Rectangle {    // urgent: accent underline
                            visible: parent.urgent && !parent.active
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 2
                            color: Theme.accent
                        }
                        MouseArea {
                            id: wm
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = "' + parent.wsid + '" })')
                        }
                    }
                }
            }
        }

        // center: clock
        BarButton {
            name: "cal"
            anchors.centerIn: parent
            height: parent.height - 1
            label: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm").toLowerCase()
            labelColor: Theme.text
        }

        // right: stats + tray
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 4
            height: parent.height - 1
            spacing: 0

            BarButton {     // recording: pulsing tag, click to stop
                visible: Rec.active
                height: parent.height
                label: "rec " + Rec.elapsed
                labelColor: Theme.black
                color: Theme.accent
                clickAction: () => Rec.stop()
                SequentialAnimation on opacity {
                    running: Rec.active; loops: Animation.Infinite
                    NumberAnimation { to: 0.55; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }
            Media { height: parent.height }
            BarButton { name: "cpu"; height: parent.height; label: "cpu " + Math.round(Stats.cpu) + "%" }
            BarButton { name: "mem"; height: parent.height; label: "mem " + Math.round(Stats.memUsed / Stats.memTotal * 100) + "%" }
            BarButton { name: "vol"; height: parent.height; label: root.volLabel(); onScrolled: d => root.nudgeVol(d) }
            BarButton { name: "net"; height: parent.height; label: !Stats.netUp ? "offline" : (Stats.iface.startsWith("wl") ? "wifi" : "eth") }
            BarButton {
                visible: root.kb !== ""
                height: parent.height
                label: root.kb
                clickAction: () => Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
            }
            BarButton {
                visible: Notifs.dnd
                height: parent.height
                label: "dnd"
                labelColor: Theme.accent
                clickAction: () => Notifs.dnd = false
            }

            Repeater {
                model: SystemTray.items
                delegate: Item {
                    required property var modelData
                    width: 26
                    height: parent.height
                    Image {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        source: modelData.icon
                        sourceSize: Qt.size(16, 16)
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            const p = bar.contentItem.mapFromItem(parent, 0, parent.height)
                            if (m.button === Qt.MiddleButton) modelData.secondaryActivate()
                            else if (m.button === Qt.RightButton || modelData.onlyMenu) { if (modelData.hasMenu) modelData.display(bar, p.x, p.y) }
                            else modelData.activate()
                        }
                        onWheel: w => modelData.scroll(w.angleDelta.y, false)
                    }
                }
            }
        }
    }

    PopupWindow {
        id: popup
        property string shown: ""
        readonly property bool wanted: ["cpu", "mem", "vol", "net", "cal"].includes(UI.open)
        property real reveal: wanted ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Connections {
            target: UI
            function onOpenChanged() { if (popup.wanted) popup.shown = UI.open }
        }

        anchor.window: bar
        anchor.rect.x: { UI.open; return UI.anchorItem ? bar.contentItem.mapFromItem(UI.anchorItem, UI.anchorItem.width, 0).x : 0 }
        anchor.rect.y: bar.height + 6
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide
        implicitWidth: 300
        implicitHeight: (loader.item ? loader.item.implicitHeight : 0) + 28
        visible: wanted || reveal > 0.001
        color: "transparent"

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                width: parent.width
                height: parent.height
                y: -height * (1 - popup.reveal)
                opacity: popup.reveal
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                Loader {
                    id: loader
                    anchors.fill: parent
                    anchors.margins: 14
                    source: popup.shown === "cpu" ? "CpuPanel.qml"
                          : popup.shown === "mem" ? "MemPanel.qml"
                          : popup.shown === "vol" ? "VolPanel.qml"
                          : popup.shown === "net" ? "NetPanel.qml"
                          : popup.shown === "cal" ? "CalPanel.qml" : ""
                }
            }
        }
    }

    HyprlandFocusGrab {
        windows: [popup, bar]
        active: popup.wanted
        onCleared: UI.closeFromGrab()
    }
}
