// Battery.
//
// Two questions, per docs/quickshell-widgets.md:
//   1. Do I need to plug in?
//   2. Am I running off the battery, or off mains?
//
// One channel per question, so neither answer has to be read out of the
// other. Fill length and colour answer the first; the bolt answers the
// second, and sits outside the battery body so it never competes with the
// colour that carries severity.
//
// There is no numeral. The percentage was the obvious thing to draw and it is
// the thing this widget deliberately does not: fill length and the colour
// ladder already answer "do I need to plug in", and a digit sitting next to
// them is a fourth thing to parse that changes no decision the shape did not
// already prompt. Losing it also bought the width the body now spends on fill
// range, which is what makes the shape answer legible in the first place.
// The number lives on hover instead, where the doc says it belongs: detail on
// request, never the answer itself. Nothing below the pointer is required to
// read the widget -- the tooltip only ever restates, more precisely, what the
// shape already said.
//
// Nothing is clickable. There is no obvious action for "the battery is at
// 40%", and the doc's rule is that a widget without one does not need a click
// handler. Power actions live behind the keyboard, not in the bar.
//
// The service connects lazily: UPower's fields read empty until a QML binding
// reads them, because the read is what opens the D-Bus connection. Everything
// below is a declarative binding for that reason -- a one-shot read in
// Component.onCompleted would see zeroes and latch there.

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "battery"

    readonly property var device: UPower.displayDevice

    // A desktop and an LXC container both have a displayDevice; neither has a
    // battery behind it. Drawing an empty husk there would answer no question,
    // so the widget leaves the row entirely.
    readonly property bool present: device !== null && device.ready && device.isLaptopBattery && device.isPresent

    // percentage is a 0..1 fraction, not 0..100.
    readonly property real charge: device !== null ? Math.max(0, Math.min(1, device.percentage)) : 0

    // The system-wide flag, rather than the device's charge state. Q2 asks
    // whether mains is attached, and onBattery answers exactly that -- where
    // the device state splits the same fact across Charging, FullyCharged and
    // PendingCharge, three values to distinguish for one binary answer.
    readonly property bool onMains: device !== null && !UPower.onBattery

    // Carried over from the waybar config this replaces, so the levels that
    // used to mean something still do.
    readonly property real warnLevel: setting("warnLevel", 0.30)
    readonly property real criticalLevel: setting("criticalLevel", 0.15)

    // Severity only applies on battery. Plugged in at 10% is recovering, not
    // failing, and colouring it red would train the red to be ignored.
    readonly property bool low: !onMains && charge <= warnLevel
    readonly property bool critical: !onMains && charge <= criticalLevel

    // Seconds until the battery is flat, or until it is full on mains. UPower
    // reports 0 when it has no estimate yet -- just after a plug event, or
    // while the draw rate is still settling after a load change.
    readonly property real secondsLeft: {
        if (device === null)
            return 0;
        return root.onMains ? device.timeToFull : device.timeToEmpty;
    }

    readonly property string estimate: {
        if (device === null)
            return "";
        if (root.onMains && root.charge >= 0.995)
            return "Fully charged";
        if (root.secondsLeft <= 0)
            return "Estimating\u2026";
        return root.formatDuration(root.secondsLeft) + (root.onMains ? " until full" : " remaining");
    }

    // Rounded to the minute. A seconds field on a figure this noisy would be
    // false precision.
    function formatDuration(seconds) {
        var minutes = Math.round(seconds / 60);
        var hours = Math.floor(minutes / 60);
        var rest = minutes % 60;
        if (hours > 0)
            return hours + "h " + (rest < 10 ? "0" : "") + rest + "m";
        return rest + "m";
    }

    readonly property color tint: {
        if (root.critical)
            return Theme.critical;
        if (root.low)
            return Theme.warning;
        return Theme.barTextMuted;
    }

    // ------------------------------------------------------------- geometry
    // Wider than a battery glyph would be, because fill length is the only
    // thing encoding how much is left: every pixel of body is resolution on
    // the widget's primary question.
    readonly property int bodyWidth: Style.space(7)
    readonly property int bodyHeight: Style.space(3.5)
    readonly property int capWidth: Style.space(0.5)
    readonly property int capHeight: Style.space(1.5)
    readonly property int fillInset: Style.space(0.5)

    active: present
    implicitWidth: row.implicitWidth

    // Detail on demand: the exact charge, and how long it buys you. Both are
    // redundant -- the fill length and the bolt already answered the widget's
    // two questions -- which is the only reason they are allowed here.
    Tooltip {
        anchorItem: root
        open: hover.containsMouse
        text: Math.round(root.charge * 100) + "%"
        detail: root.estimate
    }

    // Hover only. There is no click action, and swallowing button presses over
    // the bar for a widget that does nothing with them would be rude.
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Style.space(1.5)

        // The slot is reserved whether or not mains is attached. The bar's
        // right section is right-anchored, so a bolt that appears and
        // disappears would shove the whole row sideways on every dock and
        // undock -- a third of this widget's width, several times a day, for a
        // state change you already see. Holding the space costs a small gap on
        // battery and keeps the bar still.
        Item {
            Layout.preferredWidth: bolt.implicitWidth
            Layout.preferredHeight: bolt.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: bolt
                anchors.centerIn: parent
                text: ""
                color: Theme.good
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                // Gated on `present` as well as `onMains`, so the bolt can
                // never claim mains during the window before UPower has
                // answered -- onBattery reads false until it does.
                opacity: root.present && root.onMains ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Style.animationNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Item {
            id: graphic

            Layout.preferredWidth: root.bodyWidth + root.capWidth
            Layout.preferredHeight: root.bodyHeight
            Layout.alignment: Qt.AlignVCenter

            // Motion means "this needs a response", and it stops when the
            // condition clears. Critical *and* discharging is the only state
            // here that qualifies: on mains at 10% the battery is recovering
            // and needs nothing from you, so it stays still. The same cycle
            // and amplitude as the workspace pulse, so the bar has one
            // vocabulary for urgency rather than two.
            //
            // An urgent workspace could in principle pulse at the same moment.
            // Both are genuinely "needs a response" and neither is worth
            // demoting to avoid a collision that requires a window shouting
            // while the battery is nearly flat.
            SequentialAnimation on scale {
                running: root.critical
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation {
                    to: 1.12
                    duration: 620
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1.0
                    duration: 620
                    easing.type: Easing.InOutSine
                }
            }

            Rectangle {
                id: body

                width: root.bodyWidth
                height: root.bodyHeight
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                radius: Style.space(1)
                color: "transparent"
                border.width: Style.borderWidth
                border.color: root.tint

                Behavior on border.color {
                    ColorAnimation {
                        duration: Style.animationFast
                    }
                }

                Rectangle {
                    id: fill

                    anchors.left: parent.left
                    anchors.leftMargin: root.fillInset
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - root.fillInset * 2
                    // Floored so a nearly-dead battery still draws a sliver:
                    // an empty outline reads as "no data", which is a
                    // different and much less alarming thing than "no charge".
                    width: Math.max(Style.space(0.5), (parent.width - root.fillInset * 2) * root.charge)
                    radius: Style.space(0.5)
                    color: root.tint

                    Behavior on width {
                        NumberAnimation {
                            duration: Style.animationNormal
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Style.animationFast
                        }
                    }
                }
            }

            Rectangle {
                id: cap

                width: root.capWidth
                height: root.capHeight
                anchors.left: body.right
                anchors.verticalCenter: parent.verticalCenter
                radius: Style.borderWidth
                color: root.tint

                Behavior on color {
                    ColorAnimation {
                        duration: Style.animationFast
                    }
                }
            }
        }
    }
}
