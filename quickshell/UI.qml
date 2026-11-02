pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property string open: ""
    property Item anchorItem: null
    property var buttons: ({})
    property int procUsers: 0

    // The focus grab closes a popup on any outside click, including a click on the
    // button that opened it. Remember that so the button's own click doesn't reopen it.
    property string closedName: ""
    property double closedAt: 0
    function closeFromGrab() {
        closedName = open
        closedAt = Date.now()
        open = ""
    }

    function toggle(name, item) {
        if (open === name) { open = ""; return }
        if (name === closedName && Date.now() - closedAt < 800) { closedName = ""; return }
        anchorItem = item
        open = name
    }
    function toggleByName(name) { toggle(name, buttons[name] || null) }
}
