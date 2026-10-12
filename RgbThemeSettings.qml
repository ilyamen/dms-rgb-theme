import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "RgbCore.js" as Core

PluginSettings {
    id: root

    pluginId: "rgbTheme"

    readonly property var shared: PluginService.globalVars["rgbTheme"] ?? ({})
    readonly property bool scanning: shared.scanning === true
    readonly property string openrgb: shared.openrgb ?? ""
    readonly property var devices: shared.devices ?? null
    readonly property var last: shared.last ?? null

    // Bumped on every save so the zone list re-reads the stored selection
    property int revision: 0
    readonly property var cfg: {
        revision;
        return {
            "zones": loadValue("zones", []),
            "mode": loadValue("mode", "direct")
        };
    }

    Component.onCompleted: {
        Core.init(Proc, PluginService);
        if (devices === null)
            Core.scan();
    }

    function setZone(device, zone, enabled, size) {
        saveValue("zones", Core.withZone(cfg.zones, device, zone, enabled, size));
        revision++;
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("rgbTheme", "The lighting takes the accent color of the theme, which DMS picks from the wallpaper. Only the hue is kept: LEDs wash out pale colors, so saturation and brightness are set below.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: statusColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: statusColumn

            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingS

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSize
                    height: Theme.iconSize
                    radius: width / 2
                    color: root.last?.color ?? "transparent"
                    border.width: 1
                    border.color: Theme.outline
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.devices !== null && root.openrgb === "")
                            return I18n.trFor("rgbTheme", "OpenRGB not found");
                        if (!root.last)
                            return root.cfg.zones.length === 0 ? I18n.trFor("rgbTheme", "Choose the zones to paint below") : I18n.trFor("rgbTheme", "Waiting for the first color…");
                        if (root.last.error)
                            return I18n.trFor("rgbTheme", "Not applied: %1").arg(root.last.error);
                        return I18n.trFor("rgbTheme", "Lighting set to %1 at %2").arg(root.last.color).arg(new Date(root.last.time).toLocaleTimeString(Qt.locale(), "HH:mm"));
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: root.last?.error ? Theme.error : Theme.surfaceText
                }
            }

            StyledText {
                width: parent.width
                visible: root.openrgb !== ""
                text: root.openrgb
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideMiddle
            }

            Row {
                spacing: Theme.spacingS

                DankButton {
                    text: I18n.trFor("rgbTheme", "Apply now")
                    iconName: "palette"
                    enabled: root.cfg.zones.length > 0
                    onClicked: Core.apply(Theme.primary, SettingsData.getPluginSettingsForPlugin("rgbTheme"), true)
                }

                DankButton {
                    text: root.scanning ? I18n.trFor("rgbTheme", "Searching…") : I18n.trFor("rgbTheme", "Find devices")
                    iconName: "refresh"
                    enabled: !root.scanning
                    onClicked: Core.scan()
                }
            }
        }
    }

    SelectionSetting {
        settingKey: "source"
        label: I18n.trFor("rgbTheme", "Color")
        options: [
            {
                "label": I18n.trFor("rgbTheme", "From the theme"),
                "value": "theme"
            },
            {
                "label": I18n.trFor("rgbTheme", "Fixed color"),
                "value": "custom"
            }
        ]
        defaultValue: "theme"
    }

    ColorSetting {
        settingKey: "customColor"
        label: I18n.trFor("rgbTheme", "Fixed color")
        description: I18n.trFor("rgbTheme", "Used when the color is set to a fixed one")
        defaultValue: "#ff5d00"
    }

    SliderSetting {
        settingKey: "brightness"
        label: I18n.trFor("rgbTheme", "Brightness")
        defaultValue: 60
        minimum: 5
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "saturation"
        label: I18n.trFor("rgbTheme", "Saturation")
        description: I18n.trFor("rgbTheme", "Below about 70% most LEDs look white")
        defaultValue: 100
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SelectionSetting {
        settingKey: "mode"
        label: I18n.trFor("rgbTheme", "OpenRGB mode")
        description: I18n.trFor("rgbTheme", "Direct works on most controllers. Some take a color only in Static.")
        options: [
            {
                "label": "Direct",
                "value": "direct"
            },
            {
                "label": "Static",
                "value": "static"
            }
        ]
        defaultValue: "direct"
    }

    StringSetting {
        settingKey: "openrgbPath"
        label: I18n.trFor("rgbTheme", "OpenRGB binary")
        description: I18n.trFor("rgbTheme", "Leave empty to use an AppImage from ~/.local/bin or openrgb from PATH")
        placeholder: I18n.trFor("rgbTheme", "automatic")
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("rgbTheme", "Zones")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        visible: root.devices !== null && root.devices.length === 0
        text: root.openrgb === "" ? I18n.trFor("rgbTheme", "OpenRGB not found.") : I18n.trFor("rgbTheme", "OpenRGB found no devices. On many boards it needs the i2c-dev module and udev rules from openrgb.org.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.devices ?? []

        StyledRect {
            id: deviceCard

            required property var modelData

            width: parent.width
            height: deviceColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: deviceColumn

                x: Theme.spacingM
                y: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                spacing: Theme.spacingS

                StyledText {
                    width: parent.width
                    text: "%1 · %2".arg(deviceCard.modelData.name).arg(deviceCard.modelData.type)
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }

                Repeater {
                    model: deviceCard.modelData.zones

                    Row {
                        id: zoneRow

                        required property string modelData
                        required property int index
                        readonly property int device: deviceCard.modelData.index
                        readonly property bool selected: Core.isZoneSelected(root.cfg, device, index)
                        readonly property bool resizable: Core.isResizable(modelData)

                        width: parent.width
                        spacing: Theme.spacingS

                        DankToggle {
                            id: zoneToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: zoneRow.selected
                            onToggled: isChecked => root.setZone(zoneRow.device, zoneRow.index, isChecked, zoneRow.resizable ? (parseInt(sizeField.text) || 0) : 0)
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.spacingS * 3 - zoneToggle.width - (zoneRow.resizable ? sizeField.width + ledsLabel.width : 0)
                            text: zoneRow.modelData
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                        }

                        DankTextField {
                            id: sizeField

                            anchors.verticalCenter: parent.verticalCenter
                            width: 80
                            visible: zoneRow.resizable
                            text: String(Core.zoneSize(root.cfg, zoneRow.device, zoneRow.index) || 120)
                            validator: IntValidator {
                                bottom: 1
                                top: 1000
                            }
                            onEditingFinished: if (zoneRow.selected) root.setZone(zoneRow.device, zoneRow.index, true, parseInt(text) || 0)
                        }

                        StyledText {
                            id: ledsLabel

                            anchors.verticalCenter: parent.verticalCenter
                            visible: zoneRow.resizable
                            text: I18n.trFor("rgbTheme", "LEDs")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
        }
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("rgbTheme", "For addressable (ARGB) headers enter how many LEDs are chained on them; a larger number does no harm.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
