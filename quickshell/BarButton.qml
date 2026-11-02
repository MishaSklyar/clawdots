import QtQuick

// bar item. click toggles the popup called `name`, unless clickAction is set.
Rectangle {
    id: b
    property string name
    property string label
    property color labelColor: Theme.muted
    property var clickAction: null     // function; replaces the popup toggle
    signal scrolled(int delta)         // wheel: +up / -down

    readonly property bool opened: name !== "" && UI.open === name
    implicitWidth: t.implicitWidth + 24
    color: opened ? Theme.accent : (ma.containsMouse ? Theme.surface : "transparent")
    Component.onCompleted: if (name) UI.buttons[name] = b

    Text {
        id: t
        anchors.centerIn: parent
        text: b.label
        color: b.opened ? Theme.black : (ma.containsMouse ? Theme.text : b.labelColor)
        font.family: Theme.font
        font.pixelSize: Theme.fs
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: b.clickAction ? b.clickAction() : UI.toggle(b.name, b)
        onWheel: w => b.scrolled(w.angleDelta.y)
    }
}
