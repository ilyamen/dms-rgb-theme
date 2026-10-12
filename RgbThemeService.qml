import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "RgbCore.js" as Core

// Applies the color whenever the theme or the settings change. OpenRGB runs
// only then and exits, so nothing stays in the background between changes
// except the small sleep guard that turns the lighting off before sleep.
PluginComponent {
    id: root

    readonly property color themeColor: Theme.primary
    readonly property var last: PluginService.globalVars["rgbTheme"]?.last ?? null
    property string reportedError: ""

    readonly property var guardCommand: (pluginData.offOnSleep ?? true) ? Core.sleepGuardCommand(pluginData, PluginService.availablePlugins["rgbTheme"]?.pluginDirectory) : []

    Component.onCompleted: {
        Core.init(Proc, PluginService);
        Core.apply(themeColor, pluginData, true);
    }

    onThemeColorChanged: Core.apply(themeColor, pluginData, false)
    onPluginDataChanged: Core.apply(themeColor, pluginData, false)

    onLastChanged: {
        const error = last?.error ?? "";
        if (error !== "" && error !== reportedError)
            ToastService.showError(I18n.trFor("rgbTheme", "RGB lighting not updated"), error);
        reportedError = error;
    }

    // Restarted when the zones change, since the guard is given the command up front
    property string startedGuard: ""
    onGuardCommandChanged: {
        const key = JSON.stringify(guardCommand);
        if (key === startedGuard)
            return;
        startedGuard = key;
        sleepGuard.running = false;
        guardRestart.restart();
    }

    Timer {
        id: guardRestart
        interval: 500
        onTriggered: sleepGuard.running = root.guardCommand.length > 0
    }

    Process {
        id: sleepGuard

        command: root.guardCommand
        running: false
        stdout: SplitParser {
            onRead: line => {
                if (line === "resume")
                    Core.apply(root.themeColor, root.pluginData, true);
            }
        }
    }
}
