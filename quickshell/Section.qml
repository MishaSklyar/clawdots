import QtQuick
import QtQuick.Layouts

// small muted caps heading
Label {
    property string title
    text: title.toUpperCase()
    color: Theme.muted
    font.pixelSize: 10
    font.letterSpacing: 1.5
    Layout.fillWidth: true
}
