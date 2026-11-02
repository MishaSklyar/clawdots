import QtQuick
import QtQuick.Layouts

ColumnLayout {
    spacing: 10
    Component.onCompleted: UI.procUsers++
    Component.onDestruction: UI.procUsers--

    readonly property real frac: Stats.memUsed / Stats.memTotal

    RowLayout {
        Layout.fillWidth: true
        Section { title: "memory" }
        Label { text: Math.round(frac * 100) + "%"; color: Theme.accent; font.pixelSize: 22; font.bold: true }
    }
    Meter { Layout.fillWidth: true; value: frac }
    Label { text: Stats.fmtKb(Stats.memUsed) + " / " + Stats.fmtKb(Stats.memTotal); color: Theme.muted }

    Section { title: "swap" }
    Meter { Layout.fillWidth: true; value: Stats.swapTotal > 0 ? Stats.swapUsed / Stats.swapTotal : 0; fill: Theme.muted }
    Label { text: Stats.fmtKb(Stats.swapUsed) + " / " + Stats.fmtKb(Stats.swapTotal); color: Theme.muted }

    Section { title: "top processes" }
    Repeater {
        model: Stats.topMem
        delegate: RowLayout {
            Layout.fillWidth: true
            Label { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
            Label { text: Stats.fmtKb(modelData.rss); color: Theme.muted }
        }
    }
}
