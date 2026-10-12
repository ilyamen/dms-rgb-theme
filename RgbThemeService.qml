import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "RgbCore.js" as Core

// Applies the color whenever the theme or the settings change. OpenRGB runs
// only then and exits, so nothing stays in the background between changes.
PluginComponent {
    id: root

    readonly property color themeColor: Theme.primary
    readonly property var last: PluginService.globalVars["rgbTheme"]?.last ?? null
    property string reportedError: ""

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
}
