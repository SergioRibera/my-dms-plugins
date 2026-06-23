pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    readonly property string service: "rs.sergioribera.ferricast"
    readonly property string objectPath: "/rs/sergioribera/ferricast"
    readonly property string iface: "rs.sergioribera.ferricast.Manager1"

    property bool available: false
    property bool initialized: false
    property bool isRefreshing: false

    property var protocols: []
    property var enumCapabilities: []
    readonly property bool canEnumerateMonitors: enumCapabilities.indexOf("monitors") !== -1
    readonly property bool canEnumerateWindows: enumCapabilities.indexOf("windows") !== -1

    property var deviceIds: []
    property var devices: ({})

    property var activeStreams: ({})
    readonly property int activeStreamCount: Object.keys(activeStreams).length

    property var monitors: []
    property var windows: []

    property bool _subscribed: false

    signal devicesListChanged
    signal deviceAdded(string deviceId)
    signal deviceRemoved(string deviceId)
    signal streamStarted(string deviceId, string deviceName)
    signal streamStopped(string deviceId)
    signal streamReconnecting(string deviceId, int attempt, string reason)
    signal streamError(string deviceId, string message)
    signal discoveryError(string protocol, string message)
    signal monitorsListChanged
    signal windowsListChanged

    Component.onCompleted: {
        if (DMSService.isConnected) {
            checkAvailability();
            subscribeToSignals();
        }
    }

    Connections {
        target: DMSService
        function onConnectionStateChanged() {
            if (!DMSService.isConnected) {
                root.available = false;
                root.initialized = false;
                root._subscribed = false;
                return;
            }
            root.checkAvailability();
            root.subscribeToSignals();
        }

        function onDbusSignalReceived(subId, data) {
            root._handleSignal(data);
        }
    }

    function checkAvailability() {
        DMSService.dbusListNames("session", response => {
            if (response.error) {
                available = false;
                return;
            }
            const names = response.result?.names || [];
            const wasAvailable = available;
            available = names.indexOf(service) !== -1;

            if (available && !initialized)
                initialize();

            if (!available && wasAvailable) {
                initialized = false;
                deviceIds = [];
                devices = {};
                activeStreams = {};
                monitors = [];
                windows = [];
                devicesListChanged();
            }
        });
    }

    function subscribeToSignals() {
        if (_subscribed)
            return;
        _subscribed = true;
        DMSService.dbusSubscribe("session", service, "", iface, "", response => {
            if (response.error) {
                console.warn("[Ferricast] subscription failed:", response.error);
                _subscribed = false;
            }
        });
    }

    function initialize() {
        initialized = true;
        fetchProtocols();
        fetchEnumerationCapabilities();
        refreshDevices();
        refreshActiveStreams();
        if (canEnumerateMonitors)
            refreshMonitors();
        if (canEnumerateWindows)
            refreshWindows();
    }

    function fetchProtocols() {
        DMSService.dbusGetProperty("session", service, objectPath, iface, "Protocols", response => {
            if (!response.error)
                protocols = response.result || [];
        });
    }

    function fetchEnumerationCapabilities() {
        DMSService.dbusGetProperty("session", service, objectPath, iface, "EnumerationCapabilities", response => {
            if (!response.error)
                enumCapabilities = response.result || [];
        });
    }

    function refreshDevices() {
        if (!available || isRefreshing)
            return;
        isRefreshing = true;

        DMSService.dbusCall("session", service, objectPath, iface, "ListDevices", [], response => {
            isRefreshing = false;
            if (response.error)
                return;
            const list = response.result?.values?.[0] || [];
            const newDevices = {};
            const ids = [];
            for (const tuple of list) {
                const dev = _deviceFromTuple(tuple);
                if (!dev)
                    continue;
                ids.push(dev.id);
                newDevices[dev.id] = dev;
            }
            deviceIds = ids;
            devices = newDevices;
            devicesListChanged();
        });
    }

    function refreshActiveStreams() {
        if (!available)
            return;
        DMSService.dbusCall("session", service, objectPath, iface, "ListActiveStreams", [], response => {
            if (response.error)
                return;
            const list = response.result?.values?.[0] || [];
            const map = {};
            for (const tuple of list) {
                if (!tuple || tuple.length < 2)
                    continue;
                map[tuple[0]] = {
                    deviceId: tuple[0],
                    deviceName: tuple[1]
                };
            }
            activeStreams = map;
        });
    }

    function refreshMonitors() {
        if (!available || !canEnumerateMonitors) {
            monitors = [];
            return;
        }
        DMSService.dbusCall("session", service, objectPath, iface, "ListMonitors", [], response => {
            if (response.error) {
                monitors = [];
                return;
            }
            const list = response.result?.values?.[0] || [];
            const result = [];
            for (const tuple of list) {
                const m = _monitorFromTuple(tuple);
                if (m)
                    result.push(m);
            }
            monitors = result;
            monitorsListChanged();
        });
    }

    function refreshWindows() {
        if (!available || !canEnumerateWindows) {
            windows = [];
            return;
        }
        DMSService.dbusCall("session", service, objectPath, iface, "ListWindows", [], response => {
            if (response.error) {
                windows = [];
                return;
            }
            const list = response.result?.values?.[0] || [];
            const result = [];
            for (const tuple of list) {
                const w = _windowFromTuple(tuple);
                if (w)
                    result.push(w);
            }
            windows = result;
            windowsListChanged();
        });
    }

    function _escGVariant(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/'/g, "\\'");
    }

    function _buildSourceGVariant(kind, args) {
        const safeKind = _escGVariant(kind || "");
        const parts = [];
        if (args) {
            for (const k of Object.keys(args)) {
                const v = args[k];
                if (v === undefined || v === null)
                    continue;
                parts.push("'" + _escGVariant(k) + "': <'" + _escGVariant(v) + "'>");
            }
        }
        return "('" + safeKind + "', {" + parts.join(", ") + "})";
    }

    function startStream(deviceId, kind, args, callback) {
        if (!available) {
            callback?.({
                error: "Ferricast unavailable"
            });
            return;
        }
        const source = _buildSourceGVariant(kind, args);
        const argv = ["gdbus", "call", "--session", "--dest", service, "--object-path", objectPath, "--method", iface + ".StartStream", String(deviceId), source];
        Quickshell.execDetached(argv);
        callback?.({});
    }

    function startDefault(deviceId, callback) {
        startStream(deviceId, "", {}, callback);
    }

    function startMonitor(deviceId, monitorId, callback) {
        const args = monitorId ? {
            "monitor": monitorId
        } : ({});
        startStream(deviceId, "screen", args, callback);
    }

    function startWindow(deviceId, windowIdentifier, callback) {
        const args = windowIdentifier ? {
            "identifier": windowIdentifier
        } : ({});
        startStream(deviceId, "window", args, callback);
    }

    function stopStream(deviceId, callback) {
        if (!available) {
            callback?.({
                error: "Ferricast unavailable"
            });
            return;
        }
        DMSService.dbusCall("session", service, objectPath, iface, "StopStream", [deviceId], response => {
            callback?.(response);
        });
    }

    function getDevice(deviceId) {
        return devices[deviceId] || null;
    }

    function isStreaming(deviceId) {
        return activeStreams.hasOwnProperty(deviceId);
    }

    function _handleSignal(data) {
        switch (data.member) {
        case "DeviceAdded":
            {
                const dev = _deviceFromTuple(data.body?.[0]);
                if (!dev)
                    return;
                if (deviceIds.indexOf(dev.id) === -1)
                    deviceIds = deviceIds.concat([dev.id]);
                devices = Object.assign({}, devices, {
                    [dev.id]: dev
                });
                deviceAdded(dev.id);
                devicesListChanged();
                break;
            }
        case "DeviceRemoved":
            {
                const id = data.body?.[0];
                if (!id)
                    return;
                deviceIds = deviceIds.filter(d => d !== id);
                const copy = Object.assign({}, devices);
                delete copy[id];
                devices = copy;
                deviceRemoved(id);
                devicesListChanged();
                break;
            }
        case "StreamStarted":
            {
                const id = data.body?.[0];
                const name = data.body?.[1] || "";
                if (!id)
                    return;
                activeStreams = Object.assign({}, activeStreams, {
                    [id]: {
                        deviceId: id,
                        deviceName: name
                    }
                });
                streamStarted(id, name);
                break;
            }
        case "StreamStopped":
            {
                const id = data.body?.[0];
                if (!id)
                    return;
                const copy = Object.assign({}, activeStreams);
                delete copy[id];
                activeStreams = copy;
                streamStopped(id);
                break;
            }
        case "StreamReconnecting":
            streamReconnecting(data.body?.[0] || "", data.body?.[1] || 0, data.body?.[2] || "");
            break;
        case "StreamError":
            streamError(data.body?.[0] || "", data.body?.[1] || "");
            break;
        case "DiscoveryError":
            discoveryError(data.body?.[0] || "", data.body?.[1] || "");
            break;
        case "MonitorsChanged":
            refreshMonitors();
            break;
        case "WindowsChanged":
            refreshWindows();
            break;
        default:
            break;
        }
    }

    function _deviceFromTuple(t) {
        if (!t || t.length < 5)
            return null;
        return {
            id: t[0],
            name: t[1],
            protocol: t[2],
            model: t[3],
            host: t[4],
            capabilities: t[5] || ({})
        };
    }

    function _monitorFromTuple(t) {
        if (!t || t.length < 11)
            return null;
        return {
            id: t[0],
            name: t[1],
            make: t[2],
            model: t[3],
            x: t[4],
            y: t[5],
            width: t[6],
            height: t[7],
            scale: t[8],
            refreshMhz: t[9],
            primary: t[10],
            extra: t[11] || ({})
        };
    }

    function _windowFromTuple(t) {
        if (!t || t.length < 10)
            return null;
        return {
            id: t[0],
            title: t[1],
            appId: t[2],
            pid: t[3],
            hasGeometry: t[4],
            x: t[5],
            y: t[6],
            width: t[7],
            height: t[8],
            onMonitor: t[9],
            extra: t[10] || ({})
        };
    }
}
