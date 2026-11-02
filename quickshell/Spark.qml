import QtQuick

// blocky column chart, right-aligned, 40 samples
Canvas {
    id: c
    property var values: []
    property real maxValue: 100      // 0 = auto-scale
    property color color: Theme.accent
    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const n = 40
        const w = width / n
        let m = maxValue
        if (m <= 0) { m = 1; for (const v of values) if (v > m) m = v }
        ctx.fillStyle = Theme.surface
        ctx.fillRect(0, height - 1, width, 1)
        ctx.fillStyle = color
        const off = n - values.length
        for (let i = 0; i < values.length; i++) {
            const h = Math.max(1, Math.round(Math.min(1, values[i] / m) * (height - 2)))
            ctx.fillRect(Math.round((off + i) * w), height - 1 - h, Math.max(1, Math.floor(w) - 1), h)
        }
    }
}
