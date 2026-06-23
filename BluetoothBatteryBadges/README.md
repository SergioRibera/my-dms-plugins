# Bluetooth Battery Badges

DankBar plugin. Shows one badge per connected Bluetooth device that reports
battery (via BlueZ `Battery1` interface). Each badge is a Material Symbol icon
chosen from device class/name plus the battery percentage.

Detected kinds:

- `sports_esports` — Gamepads (DualShock, DualSense, Xbox, Joy-Con, Pro Controller, 8BitDo, Stadia, generic)
- `headset_mic` — Headsets (with mic)
- `headphones` — Headphones (no mic)
- `speaker` — Speakers / soundbars
- `mic` — Standalone microphones
- `mouse`, `keyboard`, `watch`, `smartphone` — Input/wearable/phone
- `bluetooth` — Fallback for unknown devices

The pill also opens a popout listing every device with a larger icon, the
device name, the kind label, and the battery percentage.

## Install

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cp -r BluetoothBatteryBadges ~/.config/DankMaterialShell/plugins/
```

Then in DMS: Settings → Plugins → Scan → enable, and add
`bluetoothBatteryBadges` to a DankBar section.

## Settings

| Key              | Type    | Default | Notes                                              |
|------------------|---------|---------|----------------------------------------------------|
| `showPercentage` | toggle  | `true`  | Show `nn%` beside the icon                         |
| `colorByLevel`   | toggle  | `true`  | Tint icon error/warning/success by thresholds      |
| `onlyShowLow`    | toggle  | `false` | Only show devices at or below `lowThreshold`       |
| `hideWhenEmpty`  | toggle  | `true`  | Collapse the widget when no battery is reported    |
| `lowThreshold`   | slider  | `20`    | Below = error color                                |
| `midThreshold`   | slider  | `50`    | Below = warning color, above = success color       |

## Requires

- DMS `>= 0.1.0`
- `bluez` exposing the `org.bluez.Battery1` interface (BlueZ 5.48+)
- The device must actually report battery — controllers and most modern audio
  gear do; some cheap peripherals don't.
