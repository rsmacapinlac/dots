// Hover detail for a bar widget.
//
// The rule from docs/quickshell-widgets.md: hover may add detail, it may not
// carry the answer. Everything shown here has to be redundant -- the thing you
// occasionally want a precise figure for, never the state the widget exists to
// communicate. If a widget's meaning depends on its tooltip, the widget is
// broken and the tooltip is hiding it.
//
// This is a real window rather than an Item inside the bar because the bar is
// 34px tall and a tooltip has to escape it. Layer-shell surfaces clip to their
// own geometry, so there is no drawing outside the panel.
//
// It never takes focus. A tooltip that steals the keyboard from the window
// underneath it is a bug in a keyboard-driven desktop, not a nicety.

import QtQuick
import Quickshell
import qs.Commons

PopupWindow {
    id: root

    // The widget this hangs beneath.
    property Item anchorItem: null
    // Hover state, driven by the widget's own MouseArea.
    property bool open: false
    // Primary line, then a quieter second line.
    property string text: ""
    property string detail: ""

    // Long enough that sweeping the pointer across the bar on the way
    // somewhere else does not strobe every tooltip it passes over.
    property int delay: 400

    readonly property bool hasContent: text !== "" || detail !== ""
    // Set once the pointer has stayed put for `delay`. Reset the instant hover
    // ends, so leaving and returning restarts the wait rather than reopening
    // immediately.
    property bool settled: false

    anchor {
        item: root.anchorItem
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.top: Style.space(1.5)
        // Bar widgets sit at the screen edges, where a tooltip centred on the
        // widget would hang off the display. Slide it back inside instead of
        // letting the compositor clip it.
        adjustment: PopupAdjustment.SlideX
    }

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight
    color: "transparent"
    grabFocus: false
    visible: root.open && root.settled && root.hasContent

    onOpenChanged: {
        if (root.open) {
            wait.restart();
        } else {
            wait.stop();
            root.settled = false;
        }
    }

    Timer {
        id: wait
        interval: root.delay
        onTriggered: root.settled = true
    }

    Rectangle {
        id: body

        implicitWidth: column.implicitWidth + Style.space(3) * 2
        implicitHeight: column.implicitHeight + Style.space(2) * 2
        radius: Style.radius
        color: Theme.surface
        border.width: Style.borderWidth
        border.color: Theme.border

        Column {
            id: column

            anchors.centerIn: parent
            spacing: Style.space(0.5)

            Text {
                text: root.text
                visible: text !== ""
                color: Theme.barText
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
            }

            Text {
                text: root.detail
                visible: text !== ""
                color: Theme.barTextMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
            }
        }
    }
}
