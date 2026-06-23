import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "bluetoothBatteryBadges"

    StyledText {
        width: parent.width
        text: "Shows a small icon + battery percentage for every connected Bluetooth device that reports battery (gamepads, headsets, speakers, mice, etc.)."
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText || Theme.surfaceText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        settingKey: "showPercentage"
        label: "Show percentage"
        description: "Display battery percentage next to the device icon"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "colorByLevel"
        label: "Color by battery level"
        description: "Tint icons red/yellow/green based on the thresholds below"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "onlyShowLow"
        label: "Only show low-battery devices"
        description: "Hide badges for devices above the low-battery threshold"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "hideWhenEmpty"
        label: "Hide widget when empty"
        description: "Collapse the badge area when no device reports battery"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "includeUsbPeripherals"
        label: "Include USB / dongle peripherals"
        description: "Also show wireless devices using a proprietary USB dongle whose driver exposes battery via /sys/class/power_supply (Logitech HID++, hyperx_cloud_flight, etc.)"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "lowThreshold"
        label: "Low-battery threshold"
        description: "Below this value the icon is colored as error"
        defaultValue: 20
        minimum: 5
        maximum: 50
        unit: "%"
    }

    SliderSetting {
        settingKey: "midThreshold"
        label: "Mid-battery threshold"
        description: "Below this value the icon is colored as warning"
        defaultValue: 50
        minimum: 20
        maximum: 90
        unit: "%"
    }

    SliderSetting {
        settingKey: "sysfsPollSeconds"
        label: "sysfs poll interval"
        description: "How often to re-read /sys/class/power_supply for controllers (PS5/PS4) and HID devices that don't expose BlueZ Battery1"
        defaultValue: 30
        minimum: 5
        maximum: 300
        unit: "s"
    }

    SliderSetting {
        settingKey: "customPollSeconds"
        label: "Custom command poll interval"
        description: "How often to re-run the custom battery commands below"
        defaultValue: 60
        minimum: 10
        maximum: 600
        unit: "s"
    }

    ListSettingWithInput {
        settingKey: "customCommands"
        label: "Custom battery commands"
        description: "Run external scripts that print one device per line as \"name|percent|status|kind\". Use this for vendors with no kernel battery support (Redragon Compx, Logitech via solaar, Razer via openrazer, headsetcontrol, etc.). Fields after \"percent\" are optional. Lines starting with # are ignored."
        defaultValue: []
        fields: [
            {id: "label", label: "Label", placeholder: "Redragon M908", width: 140},
            {id: "command", label: "Shell command", placeholder: "echo 'Redragon M908|72|Discharging|mouse'", width: 320, required: true},
            {id: "kind", label: "Kind override", placeholder: "mouse", width: 120}
        ]
    }
}
