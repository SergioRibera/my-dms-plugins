import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "bt-battery-badges"

    readonly property int lowThreshold: pluginData.lowThreshold !== undefined ? pluginData.lowThreshold : 20
    readonly property int midThreshold: pluginData.midThreshold !== undefined ? pluginData.midThreshold : 50
    readonly property bool showPercentage: pluginData.showPercentage !== undefined ? pluginData.showPercentage : true
    readonly property bool onlyShowLow: pluginData.onlyShowLow !== undefined ? pluginData.onlyShowLow : false
    readonly property bool hideWhenEmpty: pluginData.hideWhenEmpty !== undefined ? pluginData.hideWhenEmpty : true
    readonly property bool colorByLevel: pluginData.colorByLevel !== undefined ? pluginData.colorByLevel : true
    readonly property bool includeUsbPeripherals: pluginData.includeUsbPeripherals !== undefined ? pluginData.includeUsbPeripherals : true
    readonly property int sysfsPollSeconds: pluginData.sysfsPollSeconds !== undefined ? pluginData.sysfsPollSeconds : 30
    readonly property int customPollSeconds: pluginData.customPollSeconds !== undefined ? pluginData.customPollSeconds : 60
    readonly property var customCommands: pluginData.customCommands || []

    // sysfs raw entries: [{name, scope, capacity, status, model}]
    property var sysfsEntries: []
    // custom-command results, keyed by command index → [{name, pct, status, kindKey}]
    property var customSlots: ({})

    readonly property string _instanceTag: (parentScreen?.name || "default") + "." + Math.floor(Math.random() * 1e9)
    readonly property string _procId: "bluetoothBatteryBadges.sysfs." + _instanceTag
    readonly property string _customProcIdBase: "bluetoothBatteryBadges.custom." + _instanceTag

    function normalizeMac(raw) {
        if (!raw) {
            return ""
        }
        const cleaned = raw.replace(/[_-]/g, ":").toUpperCase()
        const match = cleaned.match(/([0-9A-F]{2}(?::[0-9A-F]{2}){5})/)
        return match ? match[1] : ""
    }

    function refreshSysfs() {
        const script = 'for d in /sys/class/power_supply/*; do' +
            ' [ -r "$d/capacity" ] || continue;' +
            ' t=$(cat "$d/type" 2>/dev/null);' +
            ' [ "$t" = "Battery" ] || continue;' +
            ' n=$(basename "$d");' +
            ' s=$(cat "$d/scope" 2>/dev/null);' +
            ' c=$(cat "$d/capacity" 2>/dev/null);' +
            ' st=$(cat "$d/status" 2>/dev/null);' +
            ' m=$(cat "$d/model_name" 2>/dev/null | tr "|\\n" "  ");' +
            ' printf "%s|%s|%s|%s|%s\\n" "$n" "$s" "$c" "$st" "$m";' +
            ' done'

        Proc.runCommand(
            root._procId,
            ["sh", "-c", script],
            (stdout, exitCode) => {
                if (exitCode !== 0) {
                    return
                }
                const entries = []
                const lines = (stdout || "").split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    if (!line) {
                        continue
                    }
                    const parts = line.split("|")
                    if (parts.length < 4) {
                        continue
                    }
                    const name = parts[0]
                    const scope = (parts[1] || "").trim()
                    const cap = parseInt(parts[2], 10)
                    const status = (parts[3] || "").trim()
                    const model = (parts[4] || "").trim()

                    if (isNaN(cap)) {
                        continue
                    }
                    // Skip system battery (laptop main pack).
                    if (scope === "System" || /^(BAT\d+|macsmc-battery|axp\d+-battery)$/i.test(name)) {
                        continue
                    }
                    entries.push({name: name, scope: scope, capacity: cap, status: status, model: model})
                }
                root.sysfsEntries = entries
            },
            50
        )
    }

    function kindFromKey(key) {
        const k = (key || "").trim().toLowerCase()
        if (!k) {
            return null
        }
        if (k === "mouse") return {icon: "mouse", kind: "Mouse"}
        if (k === "keyboard") return {icon: "keyboard", kind: "Keyboard"}
        if (k === "controller" || k === "gamepad") return {icon: "sports_esports", kind: "Controller"}
        if (k === "headset") return {icon: "headset_mic", kind: "Headset"}
        if (k === "headphones") return {icon: "headphones", kind: "Headphones"}
        if (k === "speaker") return {icon: "speaker", kind: "Speaker"}
        if (k === "mic" || k === "microphone") return {icon: "mic", kind: "Microphone"}
        if (k === "watch") return {icon: "watch", kind: "Watch"}
        if (k === "phone") return {icon: "smartphone", kind: "Phone"}
        return null
    }

    function parseCustomOutput(stdout, defaultKind, defaultLabel) {
        const out = []
        const lines = (stdout || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (!line || line.startsWith("#")) {
                continue
            }
            const parts = line.split("|")
            const name = (parts[0] || defaultLabel || "Custom").trim()
            const pct = parseInt(parts[1], 10)
            if (isNaN(pct)) {
                continue
            }
            const status = (parts[2] || "").trim()
            const kindKey = ((parts[3] || defaultKind) || "").trim()
            out.push({name: name, pct: Math.max(0, Math.min(100, pct)), status: status, kindKey: kindKey})
        }
        return out
    }

    function refreshCustom() {
        const cmds = customCommands
        // Prune slots for commands that no longer exist.
        const newSlots = {}
        for (let i = 0; i < cmds.length; i++) {
            const key = String(i)
            newSlots[key] = customSlots[key] || []
        }
        customSlots = newSlots

        for (let i = 0; i < cmds.length; i++) {
            const entry = cmds[i]
            if (!entry || !entry.command) {
                continue
            }
            const idx = i
            const defKind = entry.kind || ""
            const defLabel = entry.label || ""
            const cmd = entry.command
            Proc.runCommand(
                root._customProcIdBase + "." + idx,
                ["sh", "-c", cmd],
                (stdout, exitCode) => {
                    if (exitCode !== 0) {
                        return
                    }
                    const parsed = root.parseCustomOutput(stdout, defKind, defLabel)
                    const updated = Object.assign({}, root.customSlots)
                    updated[String(idx)] = parsed
                    root.customSlots = updated
                },
                100
            )
        }
    }

    Component.onCompleted: {
        refreshSysfs()
        refreshCustom()
        setVisibilityOverride(shouldShow)
    }

    onShouldShowChanged: setVisibilityOverride(shouldShow)
    onCustomCommandsChanged: refreshCustom()

    Timer {
        interval: Math.max(5, root.sysfsPollSeconds) * 1000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refreshSysfs()
    }

    Timer {
        interval: Math.max(10, root.customPollSeconds) * 1000
        running: root.customCommands.length > 0
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refreshCustom()
    }

    Connections {
        target: BluetoothService.adapter
        ignoreUnknownSignals: true
        function onDevicesChanged() {
            root.refreshSysfs()
        }
    }

    function detectKindFromStrings(rawIcon, rawName) {
        const name = (rawName || "").toLowerCase()
        const icon = (rawIcon || "").toLowerCase()

        const isGamepad = icon.includes("gaming") || icon.includes("joypad") || icon.includes("gamepad")
            || /\b(dualshock|dualsense|xbox|joy.?con|pro controller|8bitdo|wireless controller|gamepad|stadia|steam controller|ps[345]?[-_ ]?controller)\b/.test(name)
        if (isGamepad) {
            return {icon: "sports_esports", kind: "Controller"}
        }
        if (icon.includes("headset") || /\b(headset|airpod|arctis|gaming headset|jabra|hyperx)\b/.test(name)) {
            return {icon: "headset_mic", kind: "Headset"}
        }
        if (icon.includes("headphone") || /\b(headphone|wh-1000|wh-ch|sony wh|bose qc|akg|sennheiser|beats)\b/.test(name)) {
            return {icon: "headphones", kind: "Headphones"}
        }
        if (icon.includes("speaker") || /\b(speaker|soundbar|jbl|flip|charge|sonos)\b/.test(name)) {
            return {icon: "speaker", kind: "Speaker"}
        }
        if (icon.includes("microphone") || /\b(\bmic\b|microphone|wireless mic)\b/.test(name)) {
            return {icon: "mic", kind: "Microphone"}
        }
        if (icon.includes("mouse") || /\b(mouse|mx[\s_-]?master|mx[\s_-]?anywhere|trackball|magic mouse|gpro|gpx|deathadder|viper|basilisk)\b/.test(name)) {
            return {icon: "mouse", kind: "Mouse"}
        }
        if (icon.includes("keyboard") || /\b(keyboard|mx[\s_-]?keys|huntsman|blackwidow|magic keyboard)\b/.test(name)) {
            return {icon: "keyboard", kind: "Keyboard"}
        }
        if (icon.includes("watch") || name.includes("watch")) {
            return {icon: "watch", kind: "Watch"}
        }
        if (icon.includes("phone") || /\b(iphone|android|pixel|samsung)\b/.test(name)) {
            return {icon: "smartphone", kind: "Phone"}
        }
        if (/\b(hidpp|logitech|razer|corsair|steelseries)\b/.test(name)) {
            return {icon: "usb", kind: "USB Device"}
        }
        return {icon: "bluetooth", kind: "Device"}
    }

    function statusToCharging(status) {
        if (!status) {
            return false
        }
        const s = status.toLowerCase()
        return s === "charging" || s === "full" || s === "not charging"
    }

    function isActivelyCharging(status) {
        return (status || "").toLowerCase() === "charging"
    }

    // Build merged list: BT connected devices + USB peripherals from sysfs.
    readonly property var combinedDevices: {
        const result = []
        const matchedSysfsNames = {}

        const btDevices = (BluetoothService.adapter && BluetoothService.adapter.devices)
            ? BluetoothService.adapter.devices.values
            : []

        for (let i = 0; i < btDevices.length; i++) {
            const dev = btDevices[i]
            if (!dev || !dev.connected) {
                continue
            }
            const macKey = (dev.address || "").toUpperCase()

            let pct = -1
            let source = ""
            let status = ""

            // Prefer sysfs (gives charging state); fallback to BlueZ Battery1.
            let sysfsMatch = null
            if (macKey) {
                for (let j = 0; j < sysfsEntries.length; j++) {
                    if (normalizeMac(sysfsEntries[j].name) === macKey) {
                        sysfsMatch = sysfsEntries[j]
                        matchedSysfsNames[sysfsEntries[j].name] = true
                        break
                    }
                }
            }

            if (sysfsMatch) {
                pct = sysfsMatch.capacity
                status = sysfsMatch.status
                source = "sysfs"
            } else if (dev.batteryAvailable && dev.battery > 0) {
                pct = Math.round(dev.battery * 100)
                source = "bluez"
            }

            if (pct < 0) {
                continue
            }
            const meta = detectKindFromStrings(dev.icon, dev.name || dev.deviceName)
            result.push({
                name: dev.name || dev.deviceName || dev.address || "Unknown",
                pct: pct,
                status: status,
                charging: isActivelyCharging(status),
                kind: meta.kind,
                icon: meta.icon,
                source: source
            })
        }

        // USB / proprietary-dongle peripherals (Logitech HID++, etc.).
        if (includeUsbPeripherals) {
            for (let k = 0; k < sysfsEntries.length; k++) {
                const e = sysfsEntries[k]
                if (matchedSysfsNames[e.name]) {
                    continue
                }
                if (normalizeMac(e.name)) {
                    // Has MAC but no matching connected BT device → likely stale; skip.
                    continue
                }
                const label = e.model || e.name
                const meta = detectKindFromStrings("", label)
                result.push({
                    name: label,
                    pct: e.capacity,
                    status: e.status,
                    charging: isActivelyCharging(e.status),
                    kind: meta.kind,
                    icon: meta.icon,
                    source: "sysfs-usb"
                })
            }
        }

        // Custom user-defined commands (Redragon, solaar, openrazer, headsetcontrol, etc.).
        for (const slotKey in customSlots) {
            const arr = customSlots[slotKey]
            for (let m = 0; m < arr.length; m++) {
                const c = arr[m]
                const explicit = kindFromKey(c.kindKey)
                const meta = explicit || detectKindFromStrings("", c.name)
                result.push({
                    name: c.name,
                    pct: c.pct,
                    status: c.status,
                    charging: isActivelyCharging(c.status),
                    kind: meta.kind,
                    icon: meta.icon,
                    source: "custom"
                })
            }
        }

        return result
    }

    readonly property var visibleDevices: {
        if (onlyShowLow) {
            return combinedDevices.filter(d => d.pct <= lowThreshold)
        }
        return combinedDevices
    }

    readonly property bool hasDevices: visibleDevices.length > 0
    readonly property bool shouldShow: hasDevices || !hideWhenEmpty

    function levelColor(pct, charging) {
        if (charging) {
            return Theme.primary
        }
        if (!colorByLevel) {
            return Theme.surfaceText
        }
        if (pct <= lowThreshold) {
            return Theme.error
        }
        if (pct <= midThreshold) {
            return Theme.warning
        }
        return Theme.success
    }

    component BadgeIcon: Item {
        property string iconName: "bluetooth"
        property color iconColor: Theme.surfaceText
        property bool charging: false
        property real iconSize: 18

        implicitWidth: iconSize
        implicitHeight: iconSize

        DankIcon {
            anchors.centerIn: parent
            name: parent.iconName
            size: parent.iconSize
            color: parent.iconColor
        }

        // Bolt overlay when charging.
        Rectangle {
            visible: parent.charging
            width: Math.max(8, parent.iconSize * 0.55)
            height: width
            radius: width / 2
            color: Theme.primary
            border.color: Theme.surfaceContainer
            border.width: 1
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -width * 0.25
            anchors.bottomMargin: -height * 0.25

            DankIcon {
                anchors.centerIn: parent
                name: "bolt"
                filled: true
                size: parent.width * 0.85
                color: Theme.primaryText
            }
        }
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: badgeRow.implicitWidth
            implicitHeight: parent ? parent.widgetThickness : 24

            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: Theme.spacingS

                Repeater {
                    model: root.visibleDevices

                    Row {
                        spacing: Theme.spacingXS

                        BadgeIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: modelData.icon
                            iconColor: root.levelColor(modelData.pct, modelData.charging)
                            charging: modelData.charging
                            iconSize: root.iconSize
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.showPercentage
                            text: modelData.pct + "%"
                            color: root.levelColor(modelData.pct, modelData.charging)
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: parent ? parent.widgetThickness : 24
            implicitHeight: badgeCol.implicitHeight

            Column {
                id: badgeCol
                anchors.centerIn: parent
                spacing: Theme.spacingS

                Repeater {
                    model: root.visibleDevices

                    Column {
                        spacing: 0
                        anchors.horizontalCenter: parent.horizontalCenter

                        BadgeIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            iconName: modelData.icon
                            iconColor: root.levelColor(modelData.pct, modelData.charging)
                            charging: modelData.charging
                            iconSize: root.iconSize
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.showPercentage
                            text: modelData.pct + "%"
                            color: root.levelColor(modelData.pct, modelData.charging)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: pop

            headerText: "Bluetooth Battery"
            detailsText: root.hasDevices
                ? root.visibleDevices.length + " peripheral(s) reporting battery"
                : "No peripherals report battery"
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - pop.headerHeight - pop.detailsHeight - Theme.spacingXL

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.visibleDevices

                        StyledRect {
                            width: parent.width
                            height: 60
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh

                            BadgeIcon {
                                id: kindIcon
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: modelData.icon
                                iconColor: root.levelColor(modelData.pct, modelData.charging)
                                charging: modelData.charging
                                iconSize: Theme.iconSize
                            }

                            Column {
                                anchors.left: kindIcon.right
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: pctText.left
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: modelData.name
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                StyledText {
                                    text: {
                                        let parts = [modelData.kind, modelData.source]
                                        if (modelData.charging) {
                                            parts.push("charging")
                                        } else if (modelData.status === "Full") {
                                            parts.push("full")
                                        }
                                        return parts.join(" · ")
                                    }
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            StyledText {
                                id: pctText
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.pct + "%"
                                color: root.levelColor(modelData.pct, modelData.charging)
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 60
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        visible: !root.hasDevices

                        StyledText {
                            anchors.centerIn: parent
                            text: "No peripherals reporting battery"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 400
    popoutHeight: 440
}
