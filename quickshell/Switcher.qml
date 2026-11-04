import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// alt-tab switcher (KDE style): hold ALT, tap TAB to walk the list (most recently used first, all
// workspaces), release ALT to jump to the selected window. hyprland.lua drives it over IPC:
//   qs ipc call switcher next | prev | commit | cancel
// while open: arrows / click choose, enter selects, esc cancels.
Scope {
    id: root
    property bool shown: false
    property var wins: []
    property int index: 0
    property bool loading: false
    property int pending: 0          // steps requested while the window list is still loading
    property bool pendingCommit: false

    function load(dir) {
        shown = true
        loading = true
        pending = dir
        pendingCommit = false
        scan.running = true
    }
    function step(dir) {
        if (!shown) { load(dir); return }
        if (loading) { pending += dir; return }
        if (wins.length) index = (index + dir + wins.length) % wins.length
    }
    function commit() {
        if (!shown) return
        if (loading) { pendingCommit = true; return }
        target = wins[index] ? wins[index].address : ""
        shown = false
        focusTimer.restart()     // let the overlay give up keyboard focus first, or Hyprland keeps it
    }
    property string target: ""
    Timer {
        id: focusTimer
        interval: 40
        onTriggered: if (root.target) Hyprland.dispatch('hl.dsp.focus({ window = "address:' + root.target + '" })')
    }
    function cancel() { shown = false; loading = false; pendingCommit = false }

    Process {
        id: scan
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []
                try { list = JSON.parse(text).filter(c => c.mapped && !c.hidden && c.workspace.id !== -1) } catch (e) {}
                list.sort((a, b) => a.focusHistoryID - b.focusHistoryID)
                root.wins = list
                root.loading = false
                // first tab goes to the previous window (index 1), shift+tab to the oldest (-1)
                const n = list.length
                root.index = n ? ((root.pending % n) + n) % n : 0
                if (!root.shown) return
                if (root.pendingCommit) root.commit()
            }
        }
    }

    function iconFor(cls) {
        const e = DesktopEntries.heuristicLookup(cls)
        return Quickshell.iconPath(e ? e.icon : cls.toLowerCase(), true) || Quickshell.iconPath("application-x-executable", true)
    }

    IpcHandler {
        target: "switcher"
        function next(): void { root.step(1) }
        function prev(): void { root.step(-1) }
        function commit(): void { root.commit() }
        function cancel(): void { root.cancel() }
    }

    PanelWindow {
        id: win
        property real reveal: root.shown ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        visible: root.shown || reveal > 0.001
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Qt.rgba(0, 0, 0, 0.35 * reveal)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "clawd-switcher"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) keys.forceActiveFocus()

        MouseArea { anchors.fill: parent; onPressed: root.cancel() }

        Rectangle {
            id: card
            readonly property int tile: 148
            width: Math.min(parent.width - 80, Math.max(1, root.wins.length) * (tile + 10) + 30)
            height: tile + 66
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 14 * (1 - win.reveal)
            opacity: win.reveal
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
            MouseArea { anchors.fill: parent }

            Item {
                id: keys
                focus: true
                Keys.onPressed: ev => {
                    const k = ev.key
                    if (k === Qt.Key_Escape) root.cancel()
                    else if (k === Qt.Key_Right || k === Qt.Key_L) root.step(1)
                    else if (k === Qt.Key_Left || k === Qt.Key_H) root.step(-1)
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.commit()
                    else return
                    ev.accepted = true
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                ListView {
                    id: lv
                    Layout.fillWidth: true
                    Layout.preferredHeight: card.tile
                    orientation: ListView.Horizontal
                    spacing: 10
                    clip: true
                    model: root.wins
                    currentIndex: root.index
                    highlightMoveDuration: 120
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: width / 2 - card.tile / 2
                    preferredHighlightEnd: width / 2 + card.tile / 2
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool sel: ListView.isCurrentItem
                        width: card.tile
                        height: card.tile
                        color: sel ? Theme.surface : "transparent"
                        border.color: sel ? Theme.accent : Theme.border
                        border.width: sel ? 2 : 1

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 22
                            width: 56; height: 56
                            source: root.iconFor(cell.modelData.class)
                            sourceSize: Qt.size(56, 56)
                            smooth: true
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 90
                            width: parent.width - 16
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: cell.modelData.class
                            color: cell.sel ? Theme.text : Theme.muted
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 112
                            width: parent.width - 16
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: cell.modelData.title
                            color: Theme.muted
                            font.pixelSize: 10
                        }
                        Rectangle {     // workspace tag
                            anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 6
                            width: wt.implicitWidth + 10; height: 16
                            color: cell.sel ? Theme.accent : Theme.border
                            Label {
                                id: wt
                                anchors.centerIn: parent
                                text: cell.modelData.workspace.name
                                color: cell.sel ? Theme.black : Theme.text
                                font.pixelSize: 10
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root.index = cell.index; root.commit() }
                        }
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.wins.length && root.wins[root.index] ? root.wins[root.index].title : "no windows"
                    color: Theme.text
                }
            }
        }
    }
}
