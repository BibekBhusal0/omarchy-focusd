import QtQuick
import qs.Commons

Canvas {
  id: root

  property real progress: 0
  property color trackColor: Color.muted
  property color fillColor: Color.accent
  property real strokeWidth: Math.max(2, Style.spaceReal(3))

  antialiasing: true

  onProgressChanged: requestPaint()
  onTrackColorChanged: requestPaint()
  onFillColorChanged: requestPaint()
  onStrokeWidthChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var context = getContext("2d")
    context.clearRect(0, 0, width, height)

    var lineWidth = Math.max(1, Number(root.strokeWidth))
    var radius = Math.max(0, Math.min(width, height) / 2 - lineWidth / 2)
    if (radius <= 0) return

    var centerX = width / 2
    var centerY = height / 2
    var startAngle = -Math.PI / 2
    var value = Math.max(0, Math.min(1, Number(root.progress) || 0))

    context.save()
    context.lineWidth = lineWidth
    context.lineCap = "round"

    context.beginPath()
    context.strokeStyle = root.trackColor
    context.arc(centerX, centerY, radius, 0, Math.PI * 2, false)
    context.stroke()

    if (value > 0) {
      context.beginPath()
      context.strokeStyle = root.fillColor
      context.arc(centerX, centerY, radius, startAngle,
                  startAngle + Math.PI * 2 * value, false)
      context.stroke()
    }

    context.restore()
  }
}
