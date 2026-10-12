# RGB Theme for DankMaterialShell

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) plugin that paints the PC's RGB lighting in the accent color of the theme. With a dynamic theme DMS picks that color from the wallpaper, so fans, coolers and strips change together with the wallpaper.

## How it works

Whenever the theme color or the plugin settings change, the plugin runs the OpenRGB command line once with the new color and lets it exit. Nothing stays running in between, and no OpenRGB server is needed.

LEDs show pale colors as white, so only the hue of the theme color is used. Saturation and brightness come from the settings (100% and 60% by default). Direct mode has no brightness control of its own, so brightness is folded into the color.

Many boards keep standby power on the RGB headers, so the LEDs can stay lit while the PC is suspended or hibernated. The plugin holds a logind delay lock (`sleep-guard.py`), turns the zones black when the system announces sleep, and paints the theme color again after waking up. This can be turned off in the settings. The color the board shows while booting, before DMS starts, is up to the BIOS: on Gigabyte boards look for the LED options for the power-on and sleep states.

Each zone is sent with its own size and color. Some controllers, such as the Gigabyte IT5711 on Z890 boards, otherwise take the color only for the last zone.

## Requirements

- DMS 1.6.0 or newer
- OpenRGB: a package with `openrgb` on PATH, or an AppImage in `~/.local/bin` or `~/Applications`. An AppImage is preferred when both exist, because newer boards often work only with a nightly build.
- `python3`, `gdbus` and systemd for turning the lighting off during sleep
- Access to the devices for OpenRGB: on most boards the `i2c-dev` module and the udev rules from openrgb.org.

Tested on a Gigabyte Z890M AORUS ELITE WIFI7 ICE (IT5711) with OpenRGB 1.0 nightly.

## Installation

### From a registry

In DMS Settings → Plugins, add the registry `https://github.com/ilyamen/dms-plugin-registry.git`. Then install **RGB Theme** from Browse, or run:

```sh
dms plugins install rgbTheme
```

### Manually

```sh
git clone https://github.com/ilyamen/dms-rgb-theme ~/.config/DankMaterialShell/plugins/rgbTheme
```

Enable the plugin in Settings → Plugins and open its settings. Press **Find devices**, then switch on the zones to paint. For addressable (ARGB) headers enter how many LEDs are chained on them; a number with some headroom does no harm.

## Settings

| Setting | Default | |
| --- | --- | --- |
| Color | From the theme | Or a fixed color |
| Brightness | 60% | |
| Saturation | 100% | Below about 70% most LEDs look white |
| Turn off during sleep | on | |
| OpenRGB mode | Direct | Some controllers take a color only in Static |
| OpenRGB binary | automatic | Path to a specific `openrgb` or AppImage |

## Removal

Disable or uninstall the plugin in Settings → Plugins. The plugin installs nothing outside its folder; the sleep guard stops together with it. The lighting keeps the last color until something else sets it.

## License

MIT
