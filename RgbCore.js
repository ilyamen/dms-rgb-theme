.pragma library

// Shared by the background component and the settings page: finds OpenRGB, reads
// its devices and applies a color, publishing the results through PluginService
// global vars so both update together.

var PLUGIN_ID = "rgbTheme";
// OpenRGB detects every controller on each run, which takes a few seconds
var OPENRGB_TIMEOUT = 60000;
// DMS writes a new theme in several steps; apply only once it settles
var APPLY_DEBOUNCE = 1500;

var proc = null;
var store = null;

function init(procSingleton, pluginService) {
    proc = procSingleton;
    store = pluginService;
}

function publish(key, value) {
    if (store)
        store.setGlobalVar(PLUGIN_ID, key, value);
}

function current(key, fallback) {
    return store ? store.getGlobalVar(PLUGIN_ID, key, fallback) : fallback;
}

function setting(key, fallback) {
    return store ? store.loadPluginData(PLUGIN_ID, key, fallback) : fallback;
}

// The path from the settings, then an AppImage (nightly builds support more
// boards than the packaged release), then openrgb on PATH. Prints the binary
// as the first line, followed by the output of the command it runs.
var FIND_OPENRGB = 'if [ -n "$1" ]; then bin=$1; else '
    + 'for f in "$HOME"/.local/bin/OpenRGB*.AppImage "$HOME"/Applications/OpenRGB*.AppImage; do '
    + '[ -x "$f" ] && bin=$f && break; done; '
    + '[ -n "$bin" ] || bin=$(command -v openrgb); fi; '
    + '[ -n "$bin" ] && [ -x "$bin" ] || exit 3; echo "$bin"; shift; '
    + '[ $# -gt 0 ] || exit 0; exec "$bin" --noautoconnect "$@" 2>&1';

function openrgbCommand(args) {
    return ["sh", "-c", FIND_OPENRGB, "sh", setting("openrgbPath", "").trim()].concat(args);
}

// Quoted names in `--list-detailed` may contain spaces: 'I/O Cover'
function splitNames(text) {
    const names = [];
    const re = /'([^']*)'|\[([^\]]*)\]|(\S+)/g;
    let match;
    while ((match = re.exec(text)) !== null)
        names.push(match[1] ?? match[2] ?? match[3]);
    return names;
}

function parseDevices(lines) {
    const devices = [];
    let device = null;
    for (const line of lines) {
        const head = /^(\d+): (.+)$/.exec(line);
        if (head) {
            device = {
                "index": parseInt(head[1]),
                "name": head[2].trim(),
                "type": "",
                "modes": [],
                "zones": []
            };
            devices.push(device);
            continue;
        }
        if (!device)
            continue;
        const field = /^\s+(\w+):\s+(.*)$/.exec(line);
        if (!field)
            continue;
        if (field[1] === "Type")
            device.type = field[2].trim();
        else if (field[1] === "Modes")
            device.modes = splitNames(field[2]);
        else if (field[1] === "Zones")
            device.zones = splitNames(field[2]);
    }
    return devices;
}

function scan() {
    if (!proc || current("scanning", false))
        return;
    publish("scanning", true);
    proc.runCommand("rgbTheme.scan", openrgbCommand(["--list-detailed"]), (output, exitCode) => {
        publish("scanning", false);
        const lines = output.split("\n");
        if (exitCode === 3) {
            publish("openrgb", "");
            publish("devices", []);
            return;
        }
        publish("openrgb", lines[0]);
        publish("devices", parseDevices(lines.slice(1)));
    }, 0, OPENRGB_TIMEOUT);
}

function toHex(value) {
    const hex = Math.round(Math.max(0, Math.min(1, value)) * 255).toString(16).toUpperCase();
    return hex.length < 2 ? "0" + hex : hex;
}

// LEDs show pastel tones as white, so the theme color keeps only its hue: the
// saturation and brightness come from the settings. Direct mode has no
// brightness of its own, which is why it is folded into the color.
function ledColor(color, cfg) {
    const saturation = (cfg.saturation ?? 100) / 100;
    const value = (cfg.brightness ?? 60) / 100;
    const r = color.r, g = color.g, b = color.b;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    const delta = max - min;
    let hue = 0;
    if (delta > 0) {
        if (max === r)
            hue = ((g - b) / delta) % 6;
        else if (max === g)
            hue = (b - r) / delta + 2;
        else
            hue = (r - g) / delta + 4;
        hue = (hue * 60 + 360) % 360;
    }
    const s = delta > 0 ? saturation : 0;
    const c = value * s;
    const x = c * (1 - Math.abs((hue / 60) % 2 - 1));
    const m = value - c;
    const sector = Math.floor(hue / 60);
    const rgb = [[c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x]][sector % 6];
    return toHex(rgb[0] + m) + toHex(rgb[1] + m) + toHex(rgb[2] + m);
}

function sourceColor(themeColor, cfg) {
    // ColorSetting stores "#rrggbb", or "#aarrggbb" with transparency
    const custom = /^#(?:[0-9a-f]{2})?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(cfg.customColor ?? "");
    if ((cfg.source ?? "theme") === "custom" && custom)
        return {
            "r": parseInt(custom[1], 16) / 255,
            "g": parseInt(custom[2], 16) / 255,
            "b": parseInt(custom[3], 16) / 255
        };
    return themeColor;
}

// Each zone gets its own size and color: some controllers (Gigabyte IT5711)
// only take the color for the last zone otherwise.
function applyArgs(hex, cfg) {
    const args = [];
    const mode = cfg.mode ?? "direct";
    for (const target of cfg.zones ?? []) {
        args.push("-d", String(target.device), "-z", String(target.zone));
        if (target.size > 0)
            args.push("-sz", String(target.size));
        args.push("-m", mode, "-c", hex);
    }
    return args;
}

// Run by sleep-guard.py before suspend or hibernation: all zones to black
function sleepGuardCommand(cfg, dir) {
    const args = applyArgs("000000", cfg);
    if (args.length === 0 || !dir)
        return [];
    return ["python3", "-I", dir + "/sleep-guard.py"].concat(openrgbCommand(args));
}

function apply(themeColor, cfg, immediate) {
    if (!proc)
        return;
    const args = applyArgs(ledColor(sourceColor(themeColor, cfg), cfg), cfg);
    if (args.length === 0) {
        publish("last", null);
        return;
    }
    const hex = args[args.length - 1];
    proc.runCommand("rgbTheme.apply", openrgbCommand(args), (output, exitCode) => {
        publish("last", {
            "color": "#" + hex,
            "time": Date.now(),
            "error": exitCode === 0 ? "" : exitCode === 3 ? "OpenRGB not found" : output.split("\n").slice(1).join("\n").trim() || ("exit code " + exitCode)
        });
    }, immediate ? 0 : APPLY_DEBOUNCE, OPENRGB_TIMEOUT);
}

function isZoneSelected(cfg, device, zone) {
    return (cfg.zones ?? []).some(t => t.device === device && t.zone === zone);
}

function zoneSize(cfg, device, zone) {
    return (cfg.zones ?? []).find(t => t.device === device && t.zone === zone)?.size ?? 0;
}

// Addressable headers accept a LED count; the others are fixed-size
function isResizable(name) {
    return /argb|addressable|strip/i.test(name);
}

function withZone(zones, device, zone, enabled, size) {
    const rest = (zones ?? []).filter(t => !(t.device === device && t.zone === zone));
    if (enabled)
        rest.push({
            "device": device,
            "zone": zone,
            "size": size
        });
    rest.sort((a, b) => a.device - b.device || a.zone - b.zone);
    return rest;
}
