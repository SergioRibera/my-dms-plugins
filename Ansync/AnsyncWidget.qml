import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "."

PluginComponent {
    id: root

    layerNamespacePlugin: "ansync"

    readonly property bool hideWhenEmpty: pluginData.hideWhenEmpty !== undefined ? pluginData.hideWhenEmpty : false
    readonly property bool notificationBridge: pluginData.notificationBridge === true
    readonly property bool confirmForget: pluginData.confirmForget !== undefined ? pluginData.confirmForget : true
    readonly property string defaultCameraId: pluginData.defaultCameraId || "0"
    readonly property string cameraResolution: pluginData.cameraResolution || "1920x1080"
    readonly property int cameraFps: parseInt(pluginData.cameraFps || "60")
    readonly property string cameraCodec: pluginData.cameraCodec || "h264"
    readonly property string cameraAspect: pluginData.cameraAspect || "crop"
    readonly property int cameraBitrateKbps: parseInt(pluginData.cameraBitrateKbps || "8000")
    readonly property bool cameraStabilization: pluginData.cameraStabilization === true
    readonly property string quickMicDirection: pluginData.quickMicDirection || "device-to-host"
    readonly property int pollIntervalMs: parseInt(pluginData.pollIntervalMs || "2000")

    readonly property var svc: AnsyncService

    Component.onCompleted: {
        AnsyncService.pollIntervalMs = root.pollIntervalMs
        AnsyncService.notificationBridge = root.notificationBridge
    }

    Connections {
        target: root
        function onPollIntervalMsChanged()     { AnsyncService.pollIntervalMs = root.pollIntervalMs }
        function onNotificationBridgeChanged() { AnsyncService.notificationBridge = root.notificationBridge }
    }

    readonly property int deviceCount: AnsyncService.devices.length
    readonly property int liveCount: AnsyncService.devices.filter(d => d.live).length
    readonly property int pendingCount: AnsyncService.devices.filter(d => d.pending).length
    readonly property bool hasDevices: deviceCount > 0
    readonly property bool shouldShow: hasDevices || !hideWhenEmpty

    // Tri-state colour resolver for the semaphore. Maps the
    // `ConnState` enum from daemon-core to DMS theme tokens.
    function stateColor(state) {
        if (state === "active") return Theme.primary
        if (state === "authenticated" || state === "pairing") return Theme.warning
                                                                ?? Theme.tertiary
                                                                ?? Theme.primary
        return Theme.surfaceVariantText
    }
    function stateIcon(state) {
        if (state === "active") return "smartphone"
        if (state === "authenticated" || state === "pairing") return "sync"
        return "mobile_off"
    }

    readonly property var capIconMap: ({
        "screen_mirror": {icon: "screen_share", label: "Screen mirror"},
        "camera_video": {icon: "videocam", label: "Camera video"},
        "camera_audio": {icon: "mic_external_on", label: "Camera audio"},
        "mic": {icon: "mic", label: "Microphone"},
        "audio_in": {icon: "headphones", label: "Audio in"},
        "audio_out": {icon: "speaker", label: "Audio out"},
        "files": {icon: "folder", label: "Files"},
        "share": {icon: "share", label: "Quick share"},
        "input_from_device": {icon: "touch_app", label: "Input from device"},
        "input_to_device": {icon: "ads_click", label: "Input to device"},
        "notifications": {icon: "notifications", label: "Notifications"},
        "stylus": {icon: "edit", label: "Stylus"},
        "hevc": {icon: "hd", label: "HEVC"}
    })

    readonly property var allPermFlags: [
        "screen_mirror", "camera_video", "camera_audio", "mic",
        "audio_in", "audio_out", "files_send", "files_receive",
        "clipboard_in", "clipboard_out", "input_from_device", "input_to_device",
        "notifications", "share_receive"
    ]

    ccWidgetIcon: liveCount > 0 ? "smartphone"
                                 : (pendingCount > 0 ? "sync" : "mobile_off")
    ccWidgetPrimaryText: "Ansync"
    ccWidgetSecondaryText: !svc.daemonAvailable
        ? "Daemon offline"
        : (deviceCount === 0 ? "No paired devices"
            : (liveCount > 0
                ? liveCount + " live of " + deviceCount
                : (pendingCount > 0
                    ? pendingCount + " linking"
                    : deviceCount + " paired, all offline")))
    ccWidgetIsActive: liveCount > 0

    onCcWidgetToggled: {
        if (deviceCount === 1) {
            const d = svc.devices[0]
            if (d.live) svc.toggleScreen(d.id)
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            visible: root.shouldShow

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.liveCount > 0 ? "smartphone"
                      : (root.pendingCount > 0 ? "sync"
                      : (root.hasDevices ? "mobile_off" : "phonelink_erase"))
                size: Theme.iconSize - 2
                color: !root.svc.daemonAvailable
                       ? Theme.error
                       : (root.liveCount > 0 ? Theme.primary
                          : (root.pendingCount > 0
                                ? (Theme.warning ?? Theme.tertiary ?? Theme.primary)
                                : Theme.surfaceVariantText))
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasDevices
                text: root.liveCount + "/" + root.deviceCount
                color: root.liveCount > 0 ? Theme.primary : Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2
            visible: root.shouldShow

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.liveCount > 0 ? "smartphone"
                      : (root.pendingCount > 0 ? "sync" : "mobile_off")
                size: Theme.iconSize - 2
                color: root.liveCount > 0 ? Theme.primary
                       : (root.pendingCount > 0
                            ? (Theme.warning ?? Theme.tertiary ?? Theme.primary)
                            : Theme.surfaceVariantText)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.hasDevices
                text: root.liveCount + "/" + root.deviceCount
                color: root.liveCount > 0 ? Theme.primary : Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: pop
            headerText: pop.popoutState === "pair" ? "Pair device (USB)"
                       : pop.popoutState === "pairAuto" ? "Pair device"
                       : pop.popoutState === "wifiPair" ? "Pair over Wi-Fi"
                       : pop.popoutState === "wifiPin" ? "Enter PIN"
                       : pop.popoutState === "forget" ? "Forget device?"
                       : pop.popoutState === "camera" ? "Start camera"
                       : "Ansync"
            detailsText: pop.popoutState !== "list" ? ""
                : !root.svc.daemonAvailable
                    ? "Daemon offline — start ansyncd"
                    : root.hasDevices
                        ? root.deviceCount + " device(s) • "
                          + root.liveCount + " live"
                          + (root.pendingCount > 0
                                ? " • " + root.pendingCount + " linking"
                                : "")
                        : "No paired devices yet"
            showCloseButton: true

            property string popoutState: "list"
            property var pairSerials: []
            property string pairSelected: ""
            property string forgetTargetId: ""
            property string forgetTargetName: ""

            // Wi-Fi pair state.
            property var wifiCandidates: []
            property string wifiSelectedAddr: ""
            property string wifiSelectedPubkey: ""
            property string wifiSelectedName: ""
            property string wifiSessionPath: ""
            property string wifiPin: ""
            property string wifiStatus: ""    // user-visible status text
            property bool   wifiBrowsing: false

            // Camera-start popup state. `cameraTargetId` is the device
            // the next StartCamera will hit. The other fields seed
            // from the plugin's saved defaults when the popup opens
            // (see `openCameraPopup`) so the user can tweak only what
            // changes per session.
            property string cameraTargetId: ""
            property string cameraTargetName: ""
            property string cameraSelId: "0"
            property string cameraSelResolution: "1920x1080"
            property int    cameraSelFps: 60
            property string cameraSelCodec: "h264"
            property string cameraSelAspect: "crop"
            property bool   cameraSelStab: false
            property int    cameraSelBitrate: 8000

            function openCameraPopup(id, name) {
                pop.cameraTargetId = id
                pop.cameraTargetName = name || ""
                pop.cameraSelId = root.defaultCameraId
                pop.cameraSelResolution = root.cameraResolution
                pop.cameraSelFps = root.cameraFps
                pop.cameraSelCodec = root.cameraCodec
                pop.cameraSelAspect = root.cameraAspect
                pop.cameraSelStab = root.cameraStabilization
                pop.cameraSelBitrate = root.cameraBitrateKbps
                pop.popoutState = "camera"
            }

            Connections {
                target: root.svc
                function onAdbDevicesListed(serials) {
                    pop.pairSerials = serials
                    if (serials.length === 1) pop.pairSelected = serials[0]
                    // Auto-detect transport dispatch. When the user
                    // clicked the unified "Pair Android device" button
                    // the popout sits on `pairAuto` until ADB answers:
                    //   - serials present → USB flow.
                    //   - empty → Wi-Fi PIN browse.
                    if (pop.popoutState === "pairAuto") {
                        if (serials.length > 0) {
                            pop.popoutState = "pair"
                        } else {
                            pop.wifiStatus = "No USB device — scanning the LAN…"
                            pop.wifiBrowsing = true
                            pop.popoutState = "wifiPair"
                            root.svc.browseAvailable(5)
                        }
                    }
                }
                function onWifiCandidatesFound(list) {
                    pop.wifiCandidates = list
                    pop.wifiBrowsing = false
                    pop.wifiStatus = list.length === 0
                        ? "No pair-ready devices on the LAN. Open ansync on the phone first."
                        : ""
                }
                function onWifiPairStarted(path) {
                    pop.wifiSessionPath = path
                    pop.wifiStatus = "Dialling " + (pop.wifiSelectedName || pop.wifiSelectedAddr) + "…"
                }
                function onWifiPairAwaitingPin(path, hostName, address) {
                    pop.wifiSessionPath = path
                    pop.wifiSelectedName = hostName || pop.wifiSelectedName
                    pop.wifiStatus = "Type the 6-digit PIN shown on " + (hostName || "the phone") + "."
                    pop.popoutState = "wifiPin"
                }
                function onWifiPairCompleted(deviceId, name) {
                    pop.wifiSessionPath = ""
                    pop.wifiPin = ""
                    pop.popoutState = "list"
                    if (typeof ToastService !== "undefined") {
                        ToastService.showInfo("Ansync", "Paired " + (name || deviceId))
                    }
                }
                function onWifiPairFailed(reason) {
                    pop.wifiStatus = "Pair failed: " + reason
                    if (typeof ToastService !== "undefined") {
                        ToastService.showError("Ansync", "Pair failed: " + reason)
                    }
                }
            }

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - pop.headerHeight - pop.detailsHeight - Theme.spacingXL

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: pop.popoutState === "list"

                    StyledRect {
                        width: parent.width
                        height: 44
                        radius: Theme.cornerRadius
                        color: pairArea.containsMouse ? Theme.primaryHover : Theme.primary
                        visible: root.svc.daemonAvailable

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "add_link"; size: Theme.iconSize - 2
                                color: Theme.primaryText
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Pair Android device"
                                color: Theme.primaryText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: pairArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // One button → auto-detect transport. Ask ADB first;
                            // if it lists any authorized device we go USB, else
                            // we fall through to the Wi-Fi PIN flow (mDNS browse +
                            // PairingSession).
                            onClicked: {
                                pop.pairSelected = ""
                                pop.pairSerials = []
                                pop.wifiCandidates = []
                                pop.wifiSelectedAddr = ""
                                pop.wifiSelectedPubkey = ""
                                pop.wifiSelectedName = ""
                                pop.wifiSessionPath = ""
                                pop.wifiPin = ""
                                pop.popoutState = "pairAuto"
                                pop.wifiStatus = "Looking for an Android device…"
                                root.svc.listAdbDevices()
                            }
                        }
                    }

                    Repeater {
                        model: root.svc.devices

                        StyledRect {
                            id: deviceRow
                            width: parent.width
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh
                            implicitHeight: rowCol.implicitHeight + Theme.spacingM * 2

                            property bool expanded: false
                            property var device: modelData

                            Column {
                                id: rowCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: root.stateIcon(deviceRow.device.state)
                                        size: Theme.iconSize
                                        color: root.stateColor(deviceRow.device.state)
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - parent.spacing * 4 - Theme.iconSize - 220
                                        spacing: 2

                                        StyledText {
                                            text: deviceRow.device.name
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                        StyledText {
                                            text: root.svc.stateLabel(deviceRow.device.state) +
                                                  (deviceRow.device.address ? " • " + deviceRow.device.address : "")
                                            color: root.stateColor(deviceRow.device.state)
                                            font.pixelSize: Theme.fontSizeSmall
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Repeater {
                                            model: deviceRow.device.caps
                                            DankIcon {
                                                readonly property var meta: root.capIconMap[modelData] || {icon: "help", label: modelData}
                                                name: meta.icon
                                                size: Theme.iconSize - 6
                                                color: Theme.surfaceVariantText
                                                ToolTip.text: meta.label
                                                ToolTip.visible: tipMa.containsMouse
                                                ToolTip.delay: 400
                                                MouseArea { id: tipMa; anchors.fill: parent; hoverEnabled: true }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingXS

                                    Repeater {
                                        // Toggle-style action grid. Each entry's `on`
                                        // bit comes straight from the service's local
                                        // stream cache (`root.svc.streams`), so the
                                        // same icon switches between activate / stop
                                        // representations and dispatches the
                                        // corresponding D-Bus call. Stale state
                                        // (Android-side cap died without telling us)
                                        // self-corrects on the next click.
                                        model: [
                                            // Per-action buttons stay clickable regardless
                                            // of the live/pending semaphore: the daemon
                                            // is idempotent and either fires the action
                                            // or logs "no live connection" without
                                            // crashing. Greying buttons out led to user
                                            // confusion ("did you remove them?") whenever
                                            // a freshly paired peer was still mid-Hello.
                                            {
                                                iconOff: "screen_share", iconOn: "stop_screen_share",
                                                labelOff: "Mirror (tap to grant on phone)",
                                                labelOn: "Stop mirror",
                                                on: root.svc.isStreamOn(deviceRow.device.id, "mirror"),
                                                action: () => root.svc.toggleScreen(deviceRow.device.id),
                                                enabled: true
                                            },
                                            {
                                                iconOff: "mic", iconOn: "mic_off",
                                                labelOff: "Start mic share", labelOn: "Stop mic share",
                                                on: root.svc.isStreamOn(deviceRow.device.id, "mic"),
                                                action: () => root.svc.toggleMic(deviceRow.device.id),
                                                enabled: true
                                            },
                                            {
                                                iconOff: "videocam", iconOn: "videocam_off",
                                                labelOff: "Start camera", labelOn: "Stop camera",
                                                on: root.svc.isStreamOn(deviceRow.device.id, "camera"),
                                                // Stop is a direct call — no choices to make. Start
                                                // pops the config picker so the user picks lens /
                                                // resolution / codec per session; the plugin
                                                // defaults seed the initial values.
                                                action: () => {
                                                    if (root.svc.isStreamOn(deviceRow.device.id, "camera")) {
                                                        root.svc.stopCamera(deviceRow.device.id)
                                                        root.svc._setStream(deviceRow.device.id, "camera", false)
                                                    } else {
                                                        pop.openCameraPopup(
                                                            deviceRow.device.id,
                                                            deviceRow.device.name || "")
                                                    }
                                                },
                                                enabled: true
                                            },
                                            {
                                                iconOff: "volume_up", iconOn: "volume_off",
                                                labelOff: "Start audio route", labelOn: "Stop audio route",
                                                on: root.svc.isStreamOn(deviceRow.device.id, "audio"),
                                                action: () => root.svc.toggleAudio(
                                                    deviceRow.device.id, root.quickMicDirection),
                                                enabled: true
                                            },
                                            {
                                                iconOff: "tune", iconOn: "tune",
                                                labelOff: "Permissions", labelOn: "Permissions",
                                                on: deviceRow.expanded,
                                                action: () => deviceRow.expanded = !deviceRow.expanded,
                                                enabled: true
                                            },
                                            {
                                                iconOff: "delete", iconOn: "delete",
                                                labelOff: "Forget", labelOn: "Forget",
                                                on: false,
                                                action: () => {
                                                    if (root.confirmForget) {
                                                        pop.forgetTargetId = deviceRow.device.id
                                                        pop.forgetTargetName = deviceRow.device.name
                                                        pop.popoutState = "forget"
                                                    } else {
                                                        root.svc.forget(deviceRow.device.id)
                                                    }
                                                },
                                                enabled: true
                                            }
                                        ]

                                        StyledRect {
                                            width: 36; height: 32
                                            radius: Theme.cornerRadius
                                            color: modelData.on
                                                ? Theme.primaryContainer
                                                : (actionArea.containsMouse && modelData.enabled
                                                       ? Theme.surfaceContainerHighest : "transparent")
                                            opacity: modelData.enabled ? 1.0 : 0.4

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: modelData.on ? modelData.iconOn : modelData.iconOff
                                                size: Theme.iconSize - 4
                                                color: modelData.on ? Theme.primary : Theme.surfaceText
                                            }

                                            MouseArea {
                                                id: actionArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: modelData.enabled
                                                ToolTip.text: modelData.on ? modelData.labelOn : modelData.labelOff
                                                ToolTip.visible: containsMouse
                                                ToolTip.delay: 400
                                                onClicked: modelData.action()
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: Theme.spacingXS
                                    visible: deviceRow.expanded

                                    StyledText {
                                        text: "Permissions"
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                    }

                                    Grid {
                                        width: parent.width
                                        columns: 2
                                        columnSpacing: Theme.spacingS
                                        rowSpacing: Theme.spacingXS

                                        Repeater {
                                            model: root.allPermFlags

                                            Row {
                                                id: permRow
                                                width: (parent.width - Theme.spacingS) / 2
                                                spacing: Theme.spacingS
                                                property string flag: modelData || ""
                                                property bool current: false

                                                function refresh() {
                                                    if (deviceRow.expanded && permRow.flag.length > 0) {
                                                        root.svc.getPerm(deviceRow.device.id, permRow.flag,
                                                            v => permRow.current = v)
                                                    }
                                                }

                                                Component.onCompleted: permRow.refresh()

                                                Connections {
                                                    target: deviceRow
                                                    function onExpandedChanged() { permRow.refresh() }
                                                }

                                                DankToggle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    checked: permRow.current
                                                    onToggled: (value) => {
                                                        permRow.current = value
                                                        root.svc.setPerm(deviceRow.device.id,
                                                                        permRow.flag, value)
                                                    }
                                                }

                                                StyledText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: permRow.flag.replace(/_/g, " ")
                                                    color: Theme.surfaceText
                                                    font.pixelSize: Theme.fontSizeSmall
                                                }
                                            }
                                        }
                                    }

                                    Row {
                                        spacing: Theme.spacingS
                                        StyledRect {
                                            width: resetText.implicitWidth + Theme.spacingM * 2
                                            height: 28
                                            radius: Theme.cornerRadius
                                            color: resetArea.containsMouse ? Theme.errorHover : Theme.error
                                            StyledText {
                                                id: resetText
                                                anchors.centerIn: parent
                                                text: "Reset all"
                                                color: "white"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                            }
                                            MouseArea {
                                                id: resetArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.svc.resetPerms(deviceRow.device.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 60
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        visible: !root.hasDevices && root.svc.daemonAvailable

                        StyledText {
                            anchors.centerIn: parent
                            text: "Pair via USB or Wi-Fi PIN to add a device"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                        }
                    }
                }
            }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: pop.popoutState === "pairAuto"

                    StyledText {
                        width: parent.width
                        text: pop.wifiStatus.length > 0
                            ? pop.wifiStatus
                            : "Looking for an Android device…"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: pop.popoutState === "pair"

                    StyledText {
                        width: parent.width
                        text: pop.pairSerials.length === 0
                            ? "No ADB devices found. Connect via USB and authorize."
                            : "Select a device:"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        Repeater {
                            model: pop.pairSerials
                            StyledRect {
                                width: parent.width
                                height: 36
                                radius: Theme.cornerRadius
                                color: pop.pairSelected === modelData
                                       ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                border.color: pop.pairSelected === modelData
                                              ? Theme.primary : "transparent"
                                border.width: pop.pairSelected === modelData ? 2 : 0

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.family: "monospace"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pop.pairSelected = modelData
                                }
                            }
                        }
                    }

                    Row {
                        spacing: Theme.spacingS
                        anchors.right: parent.right

                        StyledRect {
                            width: 80; height: 32; radius: Theme.cornerRadius
                            color: refreshArea.containsMouse ? Theme.surfaceContainerHighest
                                                              : Theme.surfaceContainerHigh
                            StyledText {
                                anchors.centerIn: parent; text: "Rescan"
                                color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall
                            }
                            MouseArea {
                                id: refreshArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.svc.listAdbDevices()
                            }
                        }

                        StyledRect {
                            width: 80; height: 32; radius: Theme.cornerRadius
                            color: cancelArea.containsMouse ? Theme.surfaceContainerHighest
                                                             : Theme.surfaceContainerHigh
                            StyledText {
                                anchors.centerIn: parent; text: "Cancel"
                                color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall
                            }
                            MouseArea {
                                id: cancelArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: pop.popoutState = "list"
                            }
                        }

                        StyledRect {
                            width: 80; height: 32; radius: Theme.cornerRadius
                            color: pairBtnArea.containsMouse ? Theme.primaryHover : Theme.primary
                            opacity: pop.pairSelected.length > 0 ? 1.0 : 0.5
                            StyledText {
                                anchors.centerIn: parent; text: "Pair"
                                color: Theme.primaryText; font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: pairBtnArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: pop.pairSelected.length > 0
                                onClicked: {
                                    root.svc.pair(pop.pairSelected)
                                    if (typeof ToastService !== "undefined") {
                                        ToastService.showInfo("Ansync", "Pairing " + pop.pairSelected + "…")
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: pop.popoutState === "wifiPair"

                    StyledText {
                        width: parent.width
                        text: pop.wifiStatus.length > 0 ? pop.wifiStatus
                            : (pop.wifiCandidates.length === 0
                                ? "Scanning the LAN for pair-ready devices…"
                                : "Pick a device:")
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        Repeater {
                            model: pop.wifiCandidates
                            StyledRect {
                                width: parent.width
                                height: 44
                                radius: Theme.cornerRadius
                                color: pop.wifiSelectedAddr === modelData.addr
                                       ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                border.color: pop.wifiSelectedAddr === modelData.addr
                                              ? Theme.primary : "transparent"
                                border.width: pop.wifiSelectedAddr === modelData.addr ? 2 : 0

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        text: modelData.name
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                    }
                                    StyledText {
                                        text: modelData.addr + "  •  " +
                                              modelData.pubkey.substring(0, 16) + "…"
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: "monospace"
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        pop.wifiSelectedAddr = modelData.addr
                                        pop.wifiSelectedPubkey = modelData.pubkey
                                        pop.wifiSelectedName = modelData.name
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        spacing: Theme.spacingS
                        anchors.right: parent.right

                        StyledRect {
                            width: 80; height: 32; radius: Theme.cornerRadius
                            color: wifiRescanArea.containsMouse ? Theme.surfaceContainerHighest
                                                                 : Theme.surfaceContainerHigh
                            StyledText {
                                anchors.centerIn: parent; text: "Rescan"
                                color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall
                            }
                            MouseArea {
                                id: wifiRescanArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pop.wifiStatus = "Scanning the LAN…"
                                    pop.wifiBrowsing = true
                                    root.svc.browseAvailable(5)
                                }
                            }
                        }

                        StyledRect {
                            width: 80; height: 32; radius: Theme.cornerRadius
                            color: wifiCancelArea.containsMouse ? Theme.surfaceContainerHighest
                                                                 : Theme.surfaceContainerHigh
                            StyledText {
                                anchors.centerIn: parent; text: "Cancel"
                                color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall
                            }
                            MouseArea {
                                id: wifiCancelArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: pop.popoutState = "list"
                            }
                        }

                        StyledRect {
                            width: 90; height: 32; radius: Theme.cornerRadius
                            color: wifiPairBtnArea.containsMouse ? Theme.primaryHover : Theme.primary
                            opacity: pop.wifiSelectedAddr.length > 0 ? 1.0 : 0.5
                            StyledText {
                                anchors.centerIn: parent; text: "Pair"
                                color: Theme.primaryText; font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: wifiPairBtnArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: pop.wifiSelectedAddr.length > 0
                                onClicked: {
                                    pop.wifiStatus = "Connecting to " +
                                        (pop.wifiSelectedName || pop.wifiSelectedAddr) + "…"
                                    root.svc.startWifiPair(pop.wifiSelectedAddr,
                                                           pop.wifiSelectedPubkey)
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: pop.popoutState === "wifiPin"

                    StyledText {
                        width: parent.width
                        text: pop.wifiStatus.length > 0 ? pop.wifiStatus
                                                        : "Enter the 6-digit PIN shown on the device."
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        width: parent.width
                        placeholderText: "6-digit PIN"
                        text: pop.wifiPin
                        onTextEdited: pop.wifiPin = text
                    }

                    Row {
                        spacing: Theme.spacingS
                        anchors.right: parent.right

                        StyledRect {
                            width: 80; height: 32; radius: Theme.cornerRadius
                            color: pinCancelArea.containsMouse ? Theme.surfaceContainerHighest
                                                                : Theme.surfaceContainerHigh
                            StyledText {
                                anchors.centerIn: parent; text: "Cancel"
                                color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall
                            }
                            MouseArea {
                                id: pinCancelArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pop.wifiSessionPath.length > 0) {
                                        root.svc.cancelPair(pop.wifiSessionPath)
                                    }
                                    pop.popoutState = "list"
                                }
                            }
                        }

                        StyledRect {
                            width: 90; height: 32; radius: Theme.cornerRadius
                            color: pinSubmitArea.containsMouse ? Theme.primaryHover : Theme.primary
                            opacity: pop.wifiPin.replace(/\D/g, "").length === 6 ? 1.0 : 0.5
                            StyledText {
                                anchors.centerIn: parent; text: "Submit"
                                color: Theme.primaryText; font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: pinSubmitArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: pop.wifiPin.replace(/\D/g, "").length === 6
                                onClicked: {
                                    root.svc.submitPin(pop.wifiSessionPath,
                                                       pop.wifiPin.replace(/\D/g, ""))
                                    pop.wifiStatus = "Verifying PIN…"
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: pop.popoutState === "forget"

                    StyledText {
                        width: parent.width
                        text: "Remove pairing with " + pop.forgetTargetName + "?"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: Theme.spacingS
                        anchors.right: parent.right

                        StyledRect {
                            width: 80; height: 32; radius: Theme.cornerRadius
                            color: fcArea.containsMouse ? Theme.surfaceContainerHighest
                                                         : Theme.surfaceContainerHigh
                            StyledText {
                                anchors.centerIn: parent; text: "Cancel"
                                color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall
                            }
                            MouseArea {
                                id: fcArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: pop.popoutState = "list"
                            }
                        }

                        StyledRect {
                            width: 80; height: 32; radius: Theme.cornerRadius
                            color: ffArea.containsMouse ? Theme.errorHover : Theme.error
                            StyledText {
                                anchors.centerIn: parent; text: "Forget"
                                color: "white"; font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: ffArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.svc.forget(pop.forgetTargetId)
                                    pop.popoutState = "list"
                                }
                            }
                        }
                    }
                }

                Column {
                    id: camCol
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: pop.popoutState === "camera"

                            StyledText {
                                width: parent.width
                                text: pop.cameraTargetName.length > 0
                                    ? pop.cameraTargetName
                                    : "Camera configuration"
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM
                                StyledText {
                                    width: 90
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Lens"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                                DankDropdown {
                                    width: parent.width - 90 - Theme.spacingM
                                    height: 36
                                    text: ""
                                    currentValue: pop.cameraSelId === "0" ? "Back (0)"
                                                : pop.cameraSelId === "1" ? "Front (1)"
                                                : pop.cameraSelId
                                    options: ["Back (0)", "Front (1)"]
                                    onValueChanged: function(v) {
                                        pop.cameraSelId = v === "Back (0)" ? "0"
                                                        : v === "Front (1)" ? "1"
                                                        : v
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM
                                StyledText {
                                    width: 90
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Resolution"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                                DankDropdown {
                                    width: parent.width - 90 - Theme.spacingM
                                    height: 36
                                    text: ""
                                    currentValue: pop.cameraSelResolution
                                    options: ["1920x1080", "1280x720", "1280x960", "640x480", "3840x2160"]
                                    onValueChanged: function(v) { pop.cameraSelResolution = v }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM
                                StyledText {
                                    width: 90
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Frame rate"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                                DankDropdown {
                                    width: parent.width - 90 - Theme.spacingM
                                    height: 36
                                    text: ""
                                    currentValue: String(pop.cameraSelFps)
                                    options: ["15", "24", "30", "60"]
                                    onValueChanged: function(v) { pop.cameraSelFps = parseInt(v) }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM
                                StyledText {
                                    width: 90
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Codec"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                                DankDropdown {
                                    width: parent.width - 90 - Theme.spacingM
                                    height: 36
                                    text: ""
                                    currentValue: pop.cameraSelCodec
                                    options: ["h264", "h265"]
                                    onValueChanged: function(v) { pop.cameraSelCodec = v }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM
                                StyledText {
                                    width: 90
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Aspect"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                                DankDropdown {
                                    width: parent.width - 90 - Theme.spacingM
                                    height: 36
                                    text: ""
                                    currentValue: pop.cameraSelAspect
                                    options: ["crop", "letterbox", "stretch"]
                                    onValueChanged: function(v) { pop.cameraSelAspect = v }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM
                                StyledText {
                                    width: 90
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Bitrate (k)"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                                DankTextField {
                                    width: parent.width - 90 - Theme.spacingM
                                    placeholderText: "8000"
                                    text: String(pop.cameraSelBitrate)
                                    onTextEdited: {
                                        const n = parseInt(text)
                                        if (!isNaN(n) && n > 0) pop.cameraSelBitrate = n
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM
                                StyledText {
                                    width: 90
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Stabilize"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                                StyledRect {
                                    width: 80; height: 28; radius: Theme.cornerRadius
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: pop.cameraSelStab
                                        ? (stabArea.containsMouse ? Theme.primaryHover : Theme.primary)
                                        : (stabArea.containsMouse ? Theme.surfaceContainerHighest
                                                                  : Theme.surfaceContainerHigh)
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: pop.cameraSelStab ? "On" : "Off"
                                        color: pop.cameraSelStab ? Theme.primaryText : Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                    MouseArea {
                                        id: stabArea; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: pop.cameraSelStab = !pop.cameraSelStab
                                    }
                                }
                            }

                            Item { width: parent.width; height: Theme.spacingS }

                            Row {
                                spacing: Theme.spacingS
                                anchors.right: parent.right

                                StyledRect {
                                    width: 80; height: 32; radius: Theme.cornerRadius
                                    color: camCancelArea.containsMouse ? Theme.surfaceContainerHighest
                                                                        : Theme.surfaceContainerHigh
                                    StyledText {
                                        anchors.centerIn: parent; text: "Cancel"
                                        color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall
                                    }
                                    MouseArea {
                                        id: camCancelArea; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: pop.popoutState = "list"
                                    }
                                }

                                StyledRect {
                                    width: 110; height: 32; radius: Theme.cornerRadius
                                    color: camStartArea.containsMouse ? Theme.primaryHover : Theme.primary
                                    StyledText {
                                        anchors.centerIn: parent; text: "Start camera"
                                        color: Theme.primaryText; font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        id: camStartArea; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const parts = pop.cameraSelResolution.split("x")
                                            root.svc.toggleCamera(pop.cameraTargetId, {
                                                cameraId: pop.cameraSelId,
                                                width: parseInt(parts[0]),
                                                height: parseInt(parts[1]),
                                                fps: pop.cameraSelFps,
                                                bitrateKbps: pop.cameraSelBitrate,
                                                codec: pop.cameraSelCodec,
                                                aspect: pop.cameraSelAspect,
                                                stabilization: pop.cameraSelStab
                                            })
                                            pop.popoutState = "list"
                                        }
                                    }
                                }
                            }
                        }
            }
        }

    popoutWidth: 560
    popoutHeight: 560

    ccDetailContent: Component {
        Rectangle {
            implicitHeight: ccCol.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: ccCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingXS

                Repeater {
                    model: root.svc.devices

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: root.stateIcon(modelData.state)
                            size: Theme.iconSize - 4
                            color: root.stateColor(modelData.state)
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name + " — " + root.svc.stateLabel(modelData.state)
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
