// Base item every bar widget extends.
//
// It codifies the contract the bar host injects into each widget, so no widget
// has to re-derive it:
//
//   bar        - the hosting Bar instance (colours, geometry, run()).
//   moduleName - the widget's id, used for logging and IPC routing.
//   settings   - per-widget overrides, read through setting().
//
// Widgets set their own implicitWidth; height defaults to the bar's.

import QtQuick
import qs.Commons

Item {
    id: root

    property QtObject bar: null
    property string moduleName: ""
    property var settings: ({})

    // Lifted off the host so widgets stop writing `bar ? bar.x : fallback`.
    // The fallback matters during construction: a widget is created before the
    // Loader assigns `bar`, and a binding that reads null would settle at 0 and
    // leave the widget invisible.
    readonly property int barSize: bar ? bar.barSize : Style.barSize
    readonly property color foreground: bar ? bar.foreground : Theme.barText

    implicitHeight: barSize

    // Read one value from this widget's settings, with a fallback for missing
    // or null entries.
    function setting(name, fallback) {
        var value = settings ? settings[name] : undefined;
        return value === undefined || value === null ? fallback : value;
    }

    // Run a shell command detached from the shell process.
    function run(command) {
        if (bar)
            bar.run(command);
    }
}
