pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string iface: "enp35s0"      // replaced by the default-route interface once detected

    property real cpu: 0
    property var cores: []
    property var cpuHist: []
    property real memUsed: 0
    property real memTotal: 1
    property real swapUsed: 0
    property real swapTotal: 0
    property string load: ""
    property real rx: 0
    property real tx: 0
    property real rxTotal: 0
    property real txTotal: 0
    property var rxHist: []
    property var txHist: []
    property bool netUp: false
    property string ip: ""
    property var topCpu: []
    property var topMem: []

    property var _prevCpu: null
    property var _prevCores: null
    property var _prevNet: null
    property double _prevT: 0

    function fmtBytes(n) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++ }
        return (i === 0 ? Math.round(n) : n.toFixed(1)) + " " + u[i]
    }
    function fmtRate(n) { return fmtBytes(n) + "/s" }
    function fmtKb(kb) { return fmtBytes(kb * 1024) }

    function push(arr, v) { return arr.concat([v]).slice(-40) }

    function parse(t) {
        const recs = []
        let tot = null
        for (const raw of t.split("\n")) {
            const l = raw.trim()
            if (!l) continue
            if (l.startsWith("cpu")) {
                const p = l.split(/\s+/)
                const v = p.slice(1).map(Number)
                const rec = { idle: v[3] + v[4], total: v.reduce((a, b) => a + b, 0) }
                if (p[0] === "cpu") tot = rec; else recs.push(rec)
            } else if (l.startsWith("MemTotal:")) {
                memTotal = Number(l.split(/\s+/)[1])
            } else if (l.startsWith("MemAvailable:")) {
                memUsed = memTotal - Number(l.split(/\s+/)[1])
            } else if (l.startsWith("SwapTotal:")) {
                swapTotal = Number(l.split(/\s+/)[1])
            } else if (l.startsWith("SwapFree:")) {
                swapUsed = swapTotal - Number(l.split(/\s+/)[1])
            } else if (l.startsWith(iface + ":")) {
                const f = l.split(":")[1].trim().split(/\s+/).map(Number)
                const now = Date.now()
                rxTotal = f[0]; txTotal = f[8]
                if (_prevNet && now > _prevT) {
                    const dt = (now - _prevT) / 1000
                    rx = Math.max(0, (f[0] - _prevNet[0]) / dt)
                    tx = Math.max(0, (f[8] - _prevNet[1]) / dt)
                    rxHist = push(rxHist, rx)
                    txHist = push(txHist, tx)
                }
                _prevNet = [f[0], f[8]]
                _prevT = now
            } else if (/^(up|down|unknown|dormant|lowerlayerdown)$/.test(l)) {
                netUp = l === "up"
            } else if (/^[\d.]+ [\d.]+ [\d.]+ /.test(l)) {
                load = l.split(" ").slice(0, 3).join("  ")
            }
        }
        if (tot) {
            if (_prevCpu) {
                const dT = tot.total - _prevCpu.total
                const dI = tot.idle - _prevCpu.idle
                cpu = dT > 0 ? (1 - dI / dT) * 100 : 0
                cpuHist = push(cpuHist, cpu)
            }
            _prevCpu = tot
        }
        if (_prevCores && _prevCores.length === recs.length) {
            cores = recs.map((c, i) => {
                const dT = c.total - _prevCores[i].total
                return dT > 0 ? (1 - (c.idle - _prevCores[i].idle) / dT) * 100 : 0
            })
        }
        _prevCores = recs
    }

    function parseProcs(t) {
        const parts = t.split("---")
        const rd = s => s.split("\n").map(l => l.trim()).filter(l => l).map(l => {
            const m = l.match(/^(.*?)\s+([\d.]+)\s+(\d+)$/)
            return m ? { name: m[1], cpu: Number(m[2]), rss: Number(m[3]) } : null
        }).filter(x => x)
        topCpu = rd(parts[0] || "")
        topMem = rd(parts[1] || "")
    }

    Process {
        id: poll
        command: ["sh", "-c",
            "grep '^cpu' /proc/stat; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo; " +
            "cat /proc/loadavg; grep '" + root.iface + ":' /proc/net/dev; cat /sys/class/net/" + root.iface + "/operstate"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: poll.running = true
    }

    // follow the default route (ethernet, wifi, usb tether...)
    Process {
        id: routeProc
        command: ["sh", "-c", "ip route show default | awk '{for (i = 1; i < NF; i++) if ($i == \"dev\") { print $(i + 1); exit }}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim()
                if (d && d !== root.iface) { root.iface = d; root._prevNet = null; root.rxHist = []; root.txHist = [] }
            }
        }
    }
    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: routeProc.running = true
    }

    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 -o addr show " + root.iface + " | awk '{print $4}' | head -1"]
        stdout: StdioCollector { onStreamFinished: root.ip = text.trim() }
    }
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: ipProc.running = true
    }

    Process {
        id: procs
        command: ["sh", "-c",
            "ps -eo comm:24,pcpu,rss --no-headers --sort=-pcpu | head -5; echo ---; " +
            "ps -eo comm:24,pcpu,rss --no-headers --sort=-rss | head -5"]
        stdout: StdioCollector { onStreamFinished: root.parseProcs(text) }
    }
    Timer {
        interval: 2000; running: UI.procUsers > 0; repeat: true; triggeredOnStart: true
        onTriggered: procs.running = true
    }
}
