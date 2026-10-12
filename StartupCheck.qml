import QtQuick
import qs.Common
import qs.Services
import "RgbCore.js" as Core

QtObject {
    function check(done) {
        Core.init(Proc, PluginService);
        Proc.runCommand("rgbTheme.depCheck", Core.openrgbCommand([]), (stdout, exitCode) => {
            if (exitCode === 0) {
                done(null);
                return;
            }
            done({
                "title": I18n.trFor("rgbTheme", "OpenRGB is required"),
                "details": I18n.trFor("rgbTheme", "Install OpenRGB, or put an OpenRGB AppImage into ~/.local/bin, then re-enable the plugin. Newer boards often work only with a nightly build from openrgb.org.")
            });
        });
    }
}
