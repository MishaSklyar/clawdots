import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    property alias window: win
    property string query: ""
    property string name: "launcher"      // UI.open value that shows this one
    property bool showPower: true
    property bool centered: false

    readonly property var results: {
        const q = query.toLowerCase().trim()
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        const score = e => {
            const n = e.name.toLowerCase()
            if (!q) return 0
            if (n.startsWith(q)) return 0
            if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 1
            if (n.includes(q)) return 2
            const rest = ((e.genericName || "") + " " + (e.comment || "") + " " + (e.keywords || []).join(" ")).toLowerCase()
            if (rest.includes(q)) return 3
            // subsequence: "gst" -> "ghostty"
            let i = 0
            for (const ch of n) if (ch === q[i]) i++
            return i === q.length ? 4 : -1
        }
        return apps.map(e => ({ e: e, s: score(e) }))
                   .filter(x => x.s >= 0)
                   .sort((a, b) => a.s - b.s || a.e.name.localeCompare(b.e.name))
                   .map(x => x.e)
    }

    // calculator: "2+2", "=sqrt(2)*pi", "15% of 80" style math. enter copies the result.
    readonly property string calc: {
        let q = query.trim().replace(/^=/, "").replace(/\^/g, "**").replace(/(\d+(?:\.\d+)?)\s*% of\s*/g, "$1/100*")
        if (!q || !/[\d)]/.test(q)) return ""
        if (!/^[\d\s+\-*/().,%a-z]*$/i.test(q)) return ""
        if (!/[+\-*/%(]/.test(q) && !query.trim().startsWith("=")) return ""
        // only math words survive: anything else is an app search
        const words = q.match(/[a-z]+/gi) || []
        const ok = ["sqrt", "pi", "e", "sin", "cos", "tan", "log", "ln", "abs", "round", "floor", "ceil", "min", "max", "pow", "of"]
        if (!words.every(w => ok.includes(w.toLowerCase()))) return ""
        q = q.replace(/\bln\b/g, "log").replace(/\blog\b(?=\()/g, "log")
        try {
            const f = new Function("sqrt", "pi", "e", "sin", "cos", "tan", "log", "abs", "round", "floor", "ceil", "min", "max", "pow",
                                   '"use strict"; return (' + q + ")")
            const v = f(Math.sqrt, Math.PI, Math.E, Math.sin, Math.cos, Math.tan, Math.log, Math.abs, Math.round, Math.floor, Math.ceil, Math.min, Math.max, Math.pow)
            if (typeof v !== "number" || !isFinite(v)) return ""
            return String(Math.round(v * 1e10) / 1e10)
        } catch (err) { return "" }
    }

    function launch(e) {
        if (!e) return
        UI.open = ""
        if (e.runInTerminal) Quickshell.execDetached(["ghostty", "-e"].concat(e.command))
        else e.execute()
    }

    PanelWindow {
        id: win
        property real reveal: UI.open === root.name ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        visible: UI.open === root.name || reveal > 0.001
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: UI.open === root.name ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Connections {
            target: UI
            function onOpenChanged() {
                if (UI.open === root.name) { root.query = ""; search.text = ""; lv.currentIndex = 0; search.forceActiveFocus() }
            }
        }

        // full-screen invisible backdrop: a click anywhere outside the card closes it
        // (exclusive keyboard focus stops clicks reaching other windows, so we catch them here)
        MouseArea { anchors.fill: parent; onPressed: UI.open = "" }

        Item {
            id: slot
            readonly property int cw: root.centered ? 520 : 380
            readonly property int ch: root.centered ? 460 : 500
            x: root.centered ? Math.round((parent.width - cw) / 2) : 4
            y: root.centered ? Math.round((parent.height - ch) / 2) : 36
            width: cw
            height: ch
            clip: true

            Rectangle {
                id: card
                width: parent.width
                height: parent.height
                y: root.centered ? 0 : -height * (1 - win.reveal)
                scale: root.centered ? 0.94 + 0.06 * win.reveal : 1
                opacity: win.reveal
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                MouseArea { anchors.fill: parent }   // clicks on empty card area don't fall through to the backdrop

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // search
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: Theme.surface
                        border.color: search.activeFocus ? Theme.accent : Theme.border
                        border.width: 1
                        Label { id: prompt; x: 10; anchors.verticalCenter: parent.verticalCenter; text: ">"; color: Theme.accent; font.bold: true }
                        TextInput {
                            id: search
                            anchors.left: prompt.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.black
                            font.family: Theme.font
                            font.pixelSize: 13
                            clip: true
                            onTextChanged: { root.query = text; lv.currentIndex = 0 }
                            Text {
                                visible: !search.text
                                text: "search apps, or do math: 2^10, 15% of 80"
                                color: Theme.muted
                                font: search.font
                            }
                            Keys.onPressed: ev => {
                                const n = root.results.length
                                if (ev.key === Qt.Key_Escape) { UI.open = ""; ev.accepted = true }
                                else if (ev.key === Qt.Key_Down || (ev.modifiers & Qt.ControlModifier && ev.key === Qt.Key_N)) {
                                    lv.currentIndex = Math.min(n - 1, lv.currentIndex + 1); lv.positionViewAtIndex(lv.currentIndex, ListView.Contain); ev.accepted = true
                                } else if (ev.key === Qt.Key_Up || (ev.modifiers & Qt.ControlModifier && ev.key === Qt.Key_P)) {
                                    lv.currentIndex = Math.max(0, lv.currentIndex - 1); lv.positionViewAtIndex(lv.currentIndex, ListView.Contain); ev.accepted = true
                                } else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                                    if (root.calc && (n === 0 || root.query.trim().startsWith("="))) {
                                        Quickshell.execDetached(["wl-copy", root.calc]); UI.open = ""
                                    } else root.launch(root.results[lv.currentIndex])
                                    ev.accepted = true
                                }
                            }
                        }
                    }

                    // calculator result
                    Rectangle {
                        visible: root.calc !== ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        color: Theme.surface
                        Rectangle { width: 2; height: parent.height; color: Theme.accent }
                        Label {
                            x: 14; anchors.verticalCenter: parent.verticalCenter
                            text: "= " + root.calc
                            color: Theme.accent; font.pixelSize: 20; font.bold: true
                            width: parent.width - 120; elide: Text.ElideRight
                        }
                        Label {
                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            text: "enter: copy"; color: Theme.muted; font.pixelSize: 10
                        }
                        MouseArea { anchors.fill: parent; onClicked: { Quickshell.execDetached(["wl-copy", root.calc]); UI.open = "" } }
                    }

                    // app list
                    ListView {
                        id: lv
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 120
                        clip: true
                        model: root.results
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool cur: index === lv.currentIndex
                            width: lv.width
                            height: 36
                            color: cur ? Theme.accent : (am.containsMouse ? Theme.surface : "transparent")
                            Image {
                                id: ico
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22; height: 22
                                sourceSize: Qt.size(22, 22)
                                source: Quickshell.iconPath(modelData.icon, true) || Quickshell.iconPath("application-x-executable", true)
                            }
                            Label {
                                anchors.left: ico.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                elide: Text.ElideRight
                                color: parent.cur ? Theme.black : Theme.text
                            }
                            MouseArea {
                                id: am
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: lv.currentIndex = index
                                onClicked: root.launch(modelData)
                            }
                        }
                        Label {
                            visible: lv.count === 0 && root.calc === ""
                            anchors.centerIn: parent
                            text: "no matches"
                            color: Theme.muted
                        }
                    }

                    // power
                    Rectangle { visible: root.showPower; Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
                    RowLayout {
                        visible: root.showPower
                        Layout.fillWidth: true
                        Layout.minimumHeight: 32
                        Layout.maximumHeight: 32
                        spacing: 6
                        PowerButton { Layout.fillWidth: true; Layout.preferredHeight: 32; label: "shutdown"; cmd: ["systemctl", "poweroff"] }
                        PowerButton { Layout.fillWidth: true; Layout.preferredHeight: 32; label: "reboot"; cmd: ["systemctl", "reboot"] }
                        PowerButton { Layout.fillWidth: true; Layout.preferredHeight: 32; label: "logout"; cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] }
                        PowerButton { Layout.fillWidth: true; Layout.preferredHeight: 32; label: "sleep"; cmd: ["systemctl", "suspend"] }
                    }
                }
            }
        }
    }
}
