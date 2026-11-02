import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// notification toasts, top-right under the bar.
// click: default action (or dismiss). right-click: dismiss. hover pauses the timeout.
PanelWindow {
    id: win
    anchors { top: true; right: true }
    margins { top: 8; right: 8 }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clawd-toasts"
    implicitWidth: 340
    implicitHeight: Math.max(1, col.implicitHeight)
    visible: Notifs.count > 0
    color: "transparent"

    Column {
        id: col
        width: parent.width
        spacing: 6

        Repeater {
            model: Notifs.list
            delegate: Rectangle {
                id: toast
                required property var modelData
                readonly property var n: modelData
                readonly property bool critical: n.urgency === NotificationUrgency.Critical
                readonly property var defaultAction: Array.from(n.actions).find(a => a.identifier === "default") || null
                readonly property string img: n.image || (n.appIcon ? Quickshell.iconPath(n.appIcon, true) : "")

                width: col.width
                height: body.implicitHeight + 24
                color: ma.containsMouse ? Theme.surface : Theme.bg
                border.color: critical ? Theme.accent : Theme.border
                border.width: 1

                Rectangle { width: 2; height: parent.height; color: Theme.accent }   // accent stripe

                Timer {
                    interval: toast.n.expireTimeout > 0 ? toast.n.expireTimeout : 6000
                    running: !toast.critical && !ma.containsMouse
                    onTriggered: toast.n.expire()
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => {
                        if (m.button === Qt.LeftButton && toast.defaultAction) toast.defaultAction.invoke()
                        else toast.n.dismiss()
                    }
                }

                RowLayout {
                    id: body
                    x: 14; y: 12
                    width: parent.width - 26
                    spacing: 10

                    Image {
                        visible: toast.img !== ""
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        sourceSize: Qt.size(72, 72)
                        fillMode: Image.PreserveAspectFit
                        source: toast.img
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        RowLayout {
                            Layout.fillWidth: true
                            Section { title: toast.n.appName || "notification"; Layout.fillWidth: true; elide: Text.ElideRight }
                            Label { text: "x"; color: xm.containsMouse ? Theme.accent : Theme.muted
                                MouseArea { id: xm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: toast.n.dismiss() } }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: toast.n.summary
                            font.bold: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Label {
                            visible: text !== ""
                            Layout.fillWidth: true
                            text: toast.n.body
                            textFormat: Text.StyledText
                            color: Theme.muted
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            linkColor: Theme.accent
                            onLinkActivated: l => Qt.openUrlExternally(l)
                        }
                        RowLayout {
                            visible: acts.count > 0
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 6
                            Repeater {
                                id: acts
                                model: Array.from(toast.n.actions).filter(a => a.identifier !== "default")
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    color: am.containsMouse ? Theme.accent : "transparent"
                                    border.color: am.containsMouse ? Theme.accent : Theme.border
                                    border.width: 1
                                    Label { anchors.centerIn: parent; text: modelData.text; color: am.containsMouse ? Theme.black : Theme.text; elide: Text.ElideRight; width: Math.min(implicitWidth, parent.width - 8) }
                                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.invoke() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
