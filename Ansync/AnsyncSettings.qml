import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "ansync"

    StyledText {
        width: parent.width
        text: "Ansync bridges your Android companion to DMS via D-Bus (org.gameros.Ansync1). The daemon must be running."
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: "State semaphore: green = live (Hello received, streams ready) · yellow = linking (TLS up, Hello pending) · gray = paired but offline. Subscribed to Manager.DeviceConnectivityChanged for real-time updates."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: "Mirror button asks the phone to grant screen capture (a notif appears there to tap). The local mirror window opens immediately and stays empty until video starts."
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
        label: "Hide bar pill when no paired devices"
        description: "Keeps the bar clean when no companion is connected."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "confirmForget"
        label: "Confirm before forgetting a device"
        description: "Show a confirmation dialog before removing pairing."
        defaultValue: true
    }

    StringSetting {
        settingKey: "pollIntervalMs"
        label: "Poll interval (ms)"
        description: "How often to refresh device list from D-Bus."
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
        description: "Forward NotificationPosted signals to org.freedesktop.Notifications. Requires Permission notifications on the device."
        defaultValue: false
    }

    StyledText {
        width: parent.width
        text: "Camera defaults"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "defaultCameraId"
        label: "Default camera"
        description: "Android cameraId. 0 = primary back, 1 = primary front."
        options: [
            {label: "Back (0)", value: "0"},
            {label: "Front (1)", value: "1"}
        ]
        defaultValue: "0"
    }

    SelectionSetting {
        settingKey: "cameraResolution"
        label: "Resolution"
        options: [
            {label: "720p (1280×720)", value: "1280x720"},
            {label: "1080p (1920×1080)", value: "1920x1080"},
            {label: "1440p (2560×1440)", value: "2560x1440"}
        ]
        defaultValue: "1920x1080"
    }

    SelectionSetting {
        settingKey: "cameraFps"
        label: "Frame rate"
        options: [
            {label: "30 fps", value: "30"},
            {label: "60 fps", value: "60"}
        ]
        defaultValue: "60"
    }

    SelectionSetting {
        settingKey: "cameraCodec"
        label: "Codec"
        options: [
            {label: "H.264 (AVC)", value: "h264"},
            {label: "H.265 (HEVC)", value: "h265"}
        ]
        defaultValue: "h264"
    }

    SelectionSetting {
        settingKey: "cameraAspect"
        label: "Aspect"
        options: [
            {label: "Crop", value: "crop"},
            {label: "Letterbox", value: "letterbox"},
            {label: "Stretch", value: "stretch"}
        ]
        defaultValue: "crop"
    }

    StringSetting {
        settingKey: "cameraBitrateKbps"
        label: "Bitrate (kbps)"
        placeholder: "8000"
        defaultValue: "8000"
    }

    ToggleSetting {
        settingKey: "cameraStabilization"
        label: "Stabilization"
        description: "Enable Camera2 CONTROL_VIDEO_STABILIZATION_MODE_ON when device supports it."
        defaultValue: false
    }

    StyledText {
        width: parent.width
        text: "Audio default"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "quickMicDirection"
        label: "Audio route direction"
        description: "Used by the popout Audio button."
        options: [
            {label: "Device → Host (use Android as mic)", value: "device-to-host"},
            {label: "Host → Device (play through Android)", value: "host-to-device"},
            {label: "Both", value: "both"}
        ]
        defaultValue: "device-to-host"
    }
}
