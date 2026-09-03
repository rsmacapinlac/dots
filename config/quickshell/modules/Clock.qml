// Clock.
//
// Two questions, per docs/quickshell-widgets.md:
//   1. What time is it?
//   2. What is today's date?
//
// A clock is unusual for this bar: it has no states. Nothing about it is ever
// urgent, nothing needs a response, and there is no "which one, right now" to
// answer. So the section on states competing for legibility applies to its
// *fields* instead. The time is what you look at many times an hour and the
// date is what you look at a few times a day, so the time is given full
// contrast and the date recedes to muted. Same principle, different axis.
//
// No seconds. A digit that changes every second is sustained change in the
// bar, and sustained change is the one channel reserved for "this needs a
// response". Spending it on a clock that is never urgent is exactly the
// permanent animation the doc warns trains you to ignore the signal. It would
// also wake the process sixty times as often for information that changes no
// decision -- you do not act on the difference between 12:35:10 and 12:35:40.
//
// The format is ISO, matching the `date '+%Y-%m-%d %H:%M'` the waybar config
// used before this. It sorts, it is unambiguous about day-vs-month, and it
// reads the same way as everything else in a terminal-first setup.
//
// There is no click handler. A clock has no obvious action, and the
// conventional one -- a calendar popup -- would be a second interface in the
// bar for something `cal` already does better.
//
// SystemClock rather than a Timer: it wakes on the minute boundary instead of
// polling, so it neither drifts nor spins between ticks.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "clock"

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property string dateText: Qt.formatDateTime(clock.date, "yyyy-MM-dd")
    readonly property string timeText: Qt.formatDateTime(clock.date, "HH:mm")
    // The weekday is the one thing the ISO form cannot tell you, which is what
    // makes it the right thing to put on hover: the same question -- what is
    // today's date -- answered more fully, never a new one.
    readonly property string longDate: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")

    implicitWidth: row.implicitWidth

    Tooltip {
        anchorItem: root
        open: hover.containsMouse
        text: root.longDate
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Style.space(2)

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.dateText
            color: Theme.barTextMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.timeText
            color: root.foreground
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        }
    }
}
