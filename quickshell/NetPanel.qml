import QtQuick
import QtQuick.Layouts

ColumnLayout {
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        Section { title: "network" }
        Rectangle {
            Layout.preferredWidth: st.implicitWidth + 12
            Layout.preferredHeight: 18
            color: Stats.netUp ? Theme.accent : Theme.surface
            Label { id: st; anchors.centerIn: parent; text: Stats.netUp ? "online" : "offline"; font.pixelSize: 10; color: Stats.netUp ? Theme.black : Theme.muted }
        }
    }
    Label { text: Stats.iface; font.pixelSize: 16; font.bold: true }
    Label { text: Stats.ip || "no address"; color: Theme.muted }

    Section { title: "download" }
    RowLayout {
        Layout.fillWidth: true
        Label { text: Stats.fmtRate(Stats.rx); color: Theme.accent; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
        Label { text: Stats.fmtBytes(Stats.rxTotal) + " total"; color: Theme.muted }
    }
    Spark { Layout.fillWidth: true; Layout.preferredHeight: 36; values: Stats.rxHist; maxValue: 0 }

    Section { title: "upload" }
    RowLayout {
        Layout.fillWidth: true
        Label { text: Stats.fmtRate(Stats.tx); color: Theme.text; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
        Label { text: Stats.fmtBytes(Stats.txTotal) + " total"; color: Theme.muted }
    }
    Spark { Layout.fillWidth: true; Layout.preferredHeight: 36; values: Stats.txHist; maxValue: 0; color: Theme.muted }
}
