import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// claude hot corner: hold SUPER and push the mouse into the bottom-right corner (see hyprland.lua).
// up/down or 1-3 to pick, enter to open, esc to close.
Scope {
    id: root
    readonly property string name: "corner"
    readonly property string home: Quickshell.env("HOME")
    readonly property var items: [
        { label: "claude.ai", hint: "website", cmd: ["xdg-open", "https://claude.ai"] },
        { label: "claude code", hint: "in wezterm", cmd: ["wezterm", "start", "--cwd", home, "--", "fish", "-c", "claude; exec fish"] },
        { label: "claude", hint: "desktop app", cmd: ["claude-desktop"] },
    ]
    property int cur: 0

    function run(i) {
        const it = items[i]
        if (!it) return
        UI.open = ""
        Quickshell.execDetached(it.cmd)
    }

    PanelWindow {
        id: win
        property real reveal: UI.open === root.name ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        visible: UI.open === root.name || reveal > 0.001
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "clawd-corner"
        WlrLayershell.keyboardFocus: UI.open === root.name ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Connections {
            target: UI
            function onOpenChanged() { if (UI.open === root.name) { root.cur = 0; keys.forceActiveFocus() } }
        }

        MouseArea { anchors.fill: parent; onPressed: UI.open = "" }

        Rectangle {
            id: card
            width: 280
            height: col.implicitHeight + 24
            // slides out of the corner
            x: parent.width - width - 12 + (width + 12) * (1 - win.reveal)
            y: parent.height - height - 12 + (height + 12) * (1 - win.reveal)
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
            MouseArea { anchors.fill: parent }
            Rectangle { width: parent.width; height: 2; color: Theme.accent }

            Item {
                id: keys
                focus: true
                Keys.onPressed: ev => {
                    const k = ev.key, n = root.items.length
                    if (k === Qt.Key_Escape) UI.open = ""
                    else if (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) root.cur = (root.cur + 1) % n
                    else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) root.cur = (root.cur + n - 1) % n
                    else if (k >= Qt.Key_1 && k < Qt.Key_1 + n) root.run(k - Qt.Key_1)
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.run(root.cur)
                    else return
                    ev.accepted = true
                }
            }

            ColumnLayout {
                id: col
                x: 12; y: 14
                width: parent.width - 24
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    spacing: 10
                    Clawd { unit: 2 }
                    Section { title: "claude"; Layout.fillWidth: true }
                }

                Repeater {
                    model: root.items
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool sel: index === root.cur
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: sel ? Theme.accent : "transparent"
                        Label {
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            text: (index + 1) + "  " + modelData.label
                            color: parent.sel ? Theme.black : Theme.text
                            font.pixelSize: 14
                            font.bold: parent.sel
                        }
                        Label {
                            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.hint
                            color: parent.sel ? Theme.black : Theme.muted
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.cur = index
                            onClicked: root.run(index)
                        }
                    }
                }
            }
        }
    }
}
