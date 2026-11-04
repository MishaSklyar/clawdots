import Quickshell
import Quickshell.Io

ShellRoot {
    Bar {}
    Toasts {}
    Osd {}
    WallPicker {}
    Corner {}
    Switcher {}

    // qs -p ~/clawdots/quickshell ipc call popup toggle cpu
    IpcHandler {
        target: "popup"
        function toggle(name: string): void { UI.toggleByName(name) }
        function open(name: string): void { UI.open = name }
        function close(): void { UI.open = "" }
    }

    // qs -p ~/clawdots/quickshell ipc call notifs clear | toggleDnd
    IpcHandler {
        target: "notifs"
        function clear(): void { Notifs.clear() }
        function toggleDnd(): void { Notifs.dnd = !Notifs.dnd }
    }
}
