import QtQuick

// pixel Clawd, 12x8 grid. blink closes the eyes, frame 1/2 lifts alternate legs (running).
Canvas {
    property int unit: 2
    property color body: Theme.accent
    property color eye: Theme.black
    property bool blink: false
    property int frame: 0          // 0 standing, 1/2 running
    property int look: 0           // -1 left, 0 ahead, 1 right
    implicitWidth: 12 * unit
    implicitHeight: 8 * unit
    onBodyChanged: requestPaint()
    onEyeChanged: requestPaint()
    onBlinkChanged: requestPaint()
    onFrameChanged: requestPaint()
    onLookChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const u = unit
        const rect = (r, c0, c1, h) => ctx.fillRect(c0 * u, r * u, (c1 - c0 + 1) * u, (h || 1) * u)
        ctx.fillStyle = body
        for (const r of [0, 1, 4, 5]) rect(r, 2, 9)
        for (const r of [2, 3]) rect(r, 0, 11)
        const up = frame === 1 ? [4, 9] : frame === 2 ? [2, 7] : []
        for (const c of [2, 4, 7, 9]) { rect(6, c, c); if (!up.includes(c)) rect(7, c, c) }
        ctx.fillStyle = eye
        for (const c of [3 + look, 8 + look]) {
            if (blink) ctx.fillRect(c * u, 1.5 * u, u, u / 2)
            else rect(1, c, c)
        }
    }
}
