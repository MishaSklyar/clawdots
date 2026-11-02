import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// wallpaper picker (SUPER+SHIFT+W): left/right (or h/l) to browse, enter to set, esc to close.
// lists ~/clawdots/wallpaper and ~/Pictures/[Ww]allpapers
Scope {
    id: root
    readonly property string name: "walls"
    readonly property string home: Quickshell.env("HOME")
    property var files: []
    property string current: ""

    function apply(path) {
        if (!path) return
        Quickshell.execDetached([home + "/clawdots/bin/wall", path])
        current = path
        UI.open = ""
    }
    function base(p) { return p.split("/").pop().replace(/\.[^.]+$/, "") }

    Process {
        id: scan
        command: ["sh", "-c",
            "readlink -f \"$HOME/clawdots/wallpaper/current\"; echo ---; " +
            "find \"$HOME/clawdots/wallpaper\" \"$HOME/Pictures/Wallpapers\" \"$HOME/Pictures/wallpapers\" -maxdepth 1 -type f " +
            "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) ! -name 'clawd-lock.png' 2>/dev/null | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [cur, list] = text.split("---\n")
                root.current = cur.trim()
                root.files = list.split("\n").filter(l => l)
                const i = root.files.indexOf(root.current)
                lv.currentIndex = i >= 0 ? i : 0
                lv.positionViewAtIndex(lv.currentIndex, ListView.Center)
            }
        }
    }

    PanelWindow {
        id: win
        property real reveal: UI.open === root.name ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        visible: UI.open === root.name || reveal > 0.001
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Qt.rgba(0, 0, 0, 0.55 * reveal)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "clawd-walls"
        WlrLayershell.keyboardFocus: UI.open === root.name ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Connections {
            target: UI
            function onOpenChanged() { if (UI.open === root.name) { scan.running = true; keys.forceActiveFocus() } }
        }

        MouseArea { anchors.fill: parent; onPressed: UI.open = "" }

        Rectangle {
            id: card
            width: Math.min(parent.width - 80, 1100)
            height: 330
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 30 * (1 - win.reveal)
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
                    if (k === Qt.Key_Escape) UI.open = ""
                    else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Down || k === Qt.Key_Tab) lv.incrementCurrentIndex()
                    else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Up || k === Qt.Key_Backtab) lv.decrementCurrentIndex()
                    else if (k === Qt.Key_Home) lv.currentIndex = 0
                    else if (k === Qt.Key_End) lv.currentIndex = lv.count - 1
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.apply(root.files[lv.currentIndex])
                    else return
                    ev.accepted = true
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Section { title: "wallpaper"; Layout.fillWidth: false }
                    Item { Layout.fillWidth: true }
                    Label { text: lv.count ? (lv.currentIndex + 1) + " / " + lv.count : ""; color: Theme.muted }
                }

                ListView {
                    id: lv
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: 14
                    clip: true
                    model: root.files
                    highlightMoveDuration: 180
                    preferredHighlightBegin: width / 2 - 160
                    preferredHighlightEnd: width / 2 + 160
                    highlightRangeMode: ListView.ApplyRange
                    boundsBehavior: Flickable.StopAtBounds
                    WheelHandler { onWheel: e => e.angleDelta.y > 0 ? lv.decrementCurrentIndex() : lv.incrementCurrentIndex() }

                    delegate: Item {
                        id: cell
                        required property string modelData
                        required property int index
                        readonly property bool sel: ListView.isCurrentItem
                        readonly property bool isCur: modelData === root.current
                        width: 320
                        height: lv.height

                        Rectangle {
                            id: frame
                            width: 320; height: 180
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -14
                            scale: cell.sel ? 1 : 0.86
                            opacity: cell.sel ? 1 : 0.5
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            color: Theme.surface
                            border.color: cell.sel ? Theme.accent : Theme.border
                            border.width: cell.sel ? 2 : 1

                            Image {
                                anchors.fill: parent
                                anchors.margins: parent.border.width
                                source: "file://" + cell.modelData
                                sourceSize: Qt.size(320, 180)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }
                            Rectangle {     // "current" tag
                                visible: cell.isCur
                                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                                width: ct.implicitWidth + 10; height: 16
                                color: Theme.accent
                                Label { id: ct; anchors.centerIn: parent; text: "current"; color: Theme.black; font.pixelSize: 10 }
                            }
                        }
                        Label {
                            anchors.top: frame.bottom
                            anchors.topMargin: 12
                            anchors.horizontalCenter: frame.horizontalCenter
                            width: 300
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                            text: root.base(cell.modelData)
                            color: cell.sel ? Theme.text : Theme.muted
                        }
                        MouseArea {
                            anchors.fill: frame
                            onClicked: cell.sel ? root.apply(cell.modelData) : lv.currentIndex = cell.index
                        }
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "<-  ->  browse     enter  set     esc  close"
                    color: Theme.muted
                    font.pixelSize: 10
                }
            }
        }
    }
}
