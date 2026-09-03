// Base item every bar widget extends.
//
// It codifies the contract between the bar host and each widget, so no widget
// has to re-derive it:
//
//   bar        - the hosting Bar instance (colours, geometry, run()).
//   moduleName - the widget's id, used for logging and IPC routing.
//   settings   - per-widget overrides, read through setting().
//   active     - whether the widget has anything to show. Set by the widget,
//                read by the host: false drops it from the row entirely.
//   screen     - the screen this instance is drawn on. The bar is
//                instantiated once per monitor, so anything per-monitor has
//                to come from here rather than from a global.
//
// Widgets set their own implicitWidth; height defaults to the bar's.

import QtQuick
import qs.Commons

Item {
    id: root

    property QtObject bar: null
    property string moduleName: ""
    property var settings: ({})

    // Which monitor this copy of the widget lives on. Injected by the host,
    // because a widget cannot otherwise tell: Variants builds one bar surface
    // per screen and every copy evaluates the same global state identically.
    // Any widget answering a question about "this screen" needs this.
    property var screen: null

    // Widgets with no hardware behind them -- a battery on a desktop, a
    // backlight on a machine with no panel -- clear this instead of drawing an
    // empty husk. The host skips an inactive widget along with its spacing,
    // where a zero-width one would still leave a gap in the row.
    property bool active: true

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
