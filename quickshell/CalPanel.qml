import QtQuick
import QtQuick.Layouts

// month grid, monday first. scroll or < > to change month, click title for today.
ColumnLayout {
    id: cal
    spacing: 10
    readonly property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()

    function shift(d) {
        const m = month + d
        year += Math.floor(m / 12)
        month = ((m % 12) + 12) % 12
    }
    readonly property var cells: {
        const first = new Date(year, month, 1)
        const lead = (first.getDay() + 6) % 7
        const days = new Date(year, month + 1, 0).getDate()
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = i - lead + 1
            out.push(d >= 1 && d <= days ? d : 0)
        }
        return out
    }

    RowLayout {
        Layout.fillWidth: true
        Label {
            text: Qt.formatDate(new Date(cal.year, cal.month, 1), "MMMM yyyy").toLowerCase()
            color: Theme.accent; font.pixelSize: 16; font.bold: true
            Layout.fillWidth: true
            MouseArea { anchors.fill: parent; onClicked: { cal.year = cal.today.getFullYear(); cal.month = cal.today.getMonth() } }
        }
        Repeater {
            model: [["<", -1], [">", 1]]
            delegate: Rectangle {
                required property var modelData
                width: 24; height: 20
                color: nm.containsMouse ? Theme.surface : "transparent"
                Label { anchors.centerIn: parent; text: modelData[0]; color: Theme.muted }
                MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; onClicked: cal.shift(modelData[1]) }
            }
        }
    }
    Label { text: Qt.formatDate(cal.today, "dddd, d MMMM").toLowerCase(); color: Theme.muted }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2
        Repeater {
            model: ["mo", "tu", "we", "th", "fr", "sa", "su"]
            delegate: Label { required property string modelData; text: modelData; color: Theme.muted; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
        }
        Repeater {
            model: cal.cells
            delegate: Rectangle {
                required property int modelData
                required property int index
                readonly property bool isToday: modelData === cal.today.getDate() && cal.month === cal.today.getMonth() && cal.year === cal.today.getFullYear()
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                color: isToday ? Theme.accent : "transparent"
                Label {
                    anchors.centerIn: parent
                    text: modelData || ""
                    color: parent.isToday ? Theme.black : (index % 7 >= 5 ? Theme.muted : Theme.text)
                    font.bold: parent.isToday
                }
            }
        }
    }

    WheelHandler { onWheel: e => cal.shift(e.angleDelta.y > 0 ? -1 : 1) }
}
