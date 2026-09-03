// Quickshell desktop shell.
//
// One long-running process hosts everything. Summoning a panel is then a
// property change inside a live process rather than a cold Quickshell start,
// and the service singletons (UPower, Hyprland, Pipewire) connect once instead
// of once per component.
//
// The bar layout is declared here, in QML, rather than read from a config
// file. There is one author and one machine; a settings file plus the registry
// to interpret it would be indirection with nothing on the other end of it.
//
// Layout:
//   config/quickshell/Commons/   singletons: palette, semantic roles, metrics
//   config/quickshell/Ui/        reusable chrome: bar host, widget bases
//   config/quickshell/modules/   the widgets themselves
//
// Commons and Ui are reached as `qs.Commons` / `qs.Ui`, declared by a qmldir in
// each directory. That matters: a singleton imported by relative path is
// instantiated once per importing file, so every consumer silently gets its
// own empty copy. Only a type in a declared module is process-wide.

import QtQuick
import Quickshell
import qs.Ui
import "modules" as Modules

ShellRoot {
    Bar {
        position: "top"

        leftWidgets: [
            Component {
                Modules.Workspaces {}
            }
        ]
    }
}
