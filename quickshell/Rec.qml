pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// screen recording state, written by bin/rec to $XDG_RUNTIME_DIR/clawd-rec
Singleton {
    id: root
    property bool active: false
    property double start: 0
    property int secs: 0
    readonly property string elapsed: Math.floor(secs / 60) + ":" + String(secs % 60).padStart(2, "0")

    function stop() { Quickshell.execDetached([Quickshell.env("HOME") + "/clawdots/bin/rec"]) }

    FileView {
        id: f
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/clawd-rec"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { const p = text().trim().split(" "); root.start = Number(p[1]) || 0; root.active = root.start > 0 }
        onLoadFailed: root.active = false
    }
    Timer {     // FileView doesn't see deletes/creates reliably; recheck each second while it matters
        interval: 1000; repeat: true; running: true
        onTriggered: {
            f.reload()
            if (root.active) root.secs = Math.max(0, Math.floor(Date.now() / 1000 - root.start))
        }
    }
}
