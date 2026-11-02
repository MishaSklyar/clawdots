pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// notification daemon (org.freedesktop.Notifications). Toasts.qml draws them.
Singleton {
    id: root
    property bool dnd: false
    readonly property var list: server.trackedNotifications.values
    readonly property int count: list.length

    function clear() { for (const n of list.slice()) n.dismiss() }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => {
            // do-not-disturb drops everything except critical
            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return
            n.tracked = true
        }
    }
}
