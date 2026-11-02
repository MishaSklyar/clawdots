import QtQuick
import QtQuick.Layouts

ColumnLayout {
    spacing: 10
    Component.onCompleted: UI.procUsers++
    Component.onDestruction: UI.procUsers--

    RowLayout {
        Layout.fillWidth: true
        Section { title: "cpu" }
        Label { text: Math.round(Stats.cpu) + "%"; color: Theme.accent; font.pixelSize: 22; font.bold: true }
    }
    Spark { Layout.fillWidth: true; Layout.preferredHeight: 48; values: Stats.cpuHist; maxValue: 100 }

    Section { title: "cores" }
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        spacing: 3
        Repeater {
            model: Stats.cores
            delegate: Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle { anchors.fill: parent; color: Theme.surface }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(1, parent.height * modelData / 100)
                    color: Theme.accent
                }
            }
        }
    }
    Label { text: "load  " + Stats.load; color: Theme.muted }

    Section { title: "top processes" }
    Repeater {
        model: Stats.topCpu
        delegate: RowLayout {
            Layout.fillWidth: true
            Label { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
            Label { text: modelData.cpu.toFixed(1) + "%"; color: Theme.muted }
        }
    }
}
