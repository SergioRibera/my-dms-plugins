import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "ansync"

    StyledText {
        width: parent.width
        text: "Bridges the ansync daemon (org.gameros.Ansync1) to DMS."
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: "State: green = live · yellow = linking · gray = offline."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: "Mirror, mic share and camera start from the phone's QSTiles. The PC surfaces them read-only."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: "PC audio (host → device) is the only PC-triggered stream. Toggle it from the device row."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: "Bar & polling"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "hideWhenEmpty"
        label: "Hide bar pill when empty"
        description: "Hide when no paired device."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "confirmForget"
        label: "Confirm forget"
        description: "Ask before removing a pairing."
        defaultValue: true
    }

    StringSetting {
        settingKey: "pollIntervalMs"
        label: "Poll interval (ms)"
        description: "Device-list refresh rate."
        placeholder: "2000"
        defaultValue: "2000"
    }

    StyledText {
        width: parent.width
        text: "Notifications"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "notificationBridge"
        label: "Bridge Android notifications"
        description: "Forward NotificationPosted to freedesktop.Notifications."
        defaultValue: false
    }
}
