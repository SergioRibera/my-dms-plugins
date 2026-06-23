import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components"
import "./services"

PluginComponent {
    id: root

    readonly property bool available: FerricastService.available
    readonly property int deviceCount: FerricastService.deviceIds.length
    readonly property int activeCount: FerricastService.activeStreamCount
    readonly property bool hasActive: activeCount > 0

    property bool _autostartAttempted: false

    Timer {
        id: autostartTimer
        interval: 1500
        repeat: false
        onTriggered: root._tryAutostart()
    }

    Process {
        id: autostartProcess
        command: ["ferricast", "--background"]
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("[Ferricast] autostart stderr:", text.trim())
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("[Ferricast] autostart exited", exitCode)
                ToastService.showError("Ferricast", "Failed to start daemon (exit " + exitCode + ")")
            }
        }
    }

    Timer {
        id: postSpawnRecheck
        interval: 800
        repeat: true
        triggeredOnStart: false
        property int attempts: 0
        onTriggered: {
            attempts++
            FerricastService.checkAvailability()
            if (FerricastService.available || attempts >= 6)
                stop()
        }
    }

    Component.onCompleted: {
        if (DMSService.isConnected)
            autostartTimer.start()
    }

    Connections {
        target: DMSService
        function onConnectionStateChanged() {
            if (DMSService.isConnected && !root._autostartAttempted)
                autostartTimer.start()
        }
    }

    function _tryAutostart() {
        if (_autostartAttempted)
            return
        if (FerricastService.available) {
            _autostartAttempted = true
            return
        }
        _autostartAttempted = true
        console.info("[Ferricast] daemon not on bus, spawning `ferricast --background`")
        autostartProcess.running = true
        postSpawnRecheck.attempts = 0
        postSpawnRecheck.start()
    }

    ccWidgetIcon: hasActive ? "cast_connected" : "cast"
    ccWidgetPrimaryText: "Ferricast"
    ccWidgetSecondaryText: {
        if (!available)
            return "Unavailable";
        if (hasActive) {
            const firstId = Object.keys(FerricastService.activeStreams)[0];
            const stream = FerricastService.activeStreams[firstId];
            const name = stream?.deviceName || firstId;
            return activeCount === 1 ? name : (name + " +" + (activeCount - 1));
        }
        if (deviceCount === 0)
            return "No receivers";
        return deviceCount + " receiver" + (deviceCount === 1 ? "" : "s");
    }
    ccWidgetIsActive: hasActive

    ccDetailHeight: 350
    onCcWidgetExpanded: {
        FerricastService.checkAvailability();
        if (FerricastService.available) {
            FerricastService.refreshDevices();
            FerricastService.refreshActiveStreams();
        }
    }

    onCcWidgetToggled: {
        if (!hasActive)
            return;
        const firstId = Object.keys(FerricastService.activeStreams)[0];
        if (!firstId)
            return;
        FerricastService.stopStream(firstId, response => {
            if (response.error)
                ToastService.showError("Failed to stop", response.error);
        });
    }

    ccDetailContent: Component {
        FerricastDetailContent {
            listHeight: 300
        }
    }

    Connections {
        target: FerricastService

        function onStreamStarted(deviceId, deviceName) {
            ToastService.showInfo("Streaming started", deviceName || deviceId);
        }

        function onStreamStopped(deviceId) {
            const dev = FerricastService.getDevice(deviceId);
            ToastService.showInfo("Streaming stopped", dev?.name || deviceId);
        }

        function onStreamReconnecting(deviceId, attempt, reason) {
            const dev = FerricastService.getDevice(deviceId);
            ToastService.showWarning("Reconnecting (#" + attempt + ")", (dev?.name || deviceId) + (reason ? " — " + reason : ""));
        }

        function onStreamError(deviceId, message) {
            const dev = FerricastService.getDevice(deviceId);
            ToastService.showError("Stream error", (dev?.name || deviceId) + ": " + message);
        }

        function onDiscoveryError(protocol, message) {
            ToastService.showError("Discovery error (" + protocol + ")", message);
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: (root.barConfig?.noBackground ?? false) ? 1 : 2

            DankIcon {
                name: root.hasActive ? "cast_connected" : "cast"
                size: Theme.barIconSize(root.barThickness, -4)
                color: root.hasActive ? Theme.primary : Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.hasActive && root.activeCount > 1
                text: root.activeCount.toString()
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                color: Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 1

            DankIcon {
                name: root.hasActive ? "cast_connected" : "cast"
                size: Theme.barIconSize(root.barThickness)
                color: root.hasActive ? Theme.primary : Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.hasActive && root.activeCount > 1
                text: root.activeCount.toString()
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
