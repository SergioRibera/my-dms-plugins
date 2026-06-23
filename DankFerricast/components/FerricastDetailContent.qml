import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import "../services"

Rectangle {
    id: root

    property int listHeight: 280

    property string expandedDeviceId: ""
    property string expandedMode: ""

    implicitHeight: contentColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            spacing: Theme.spacingS
            width: parent.width

            StyledText {
                text: {
                    const n = FerricastService.deviceIds.length;
                    const active = FerricastService.activeStreamCount;
                    if (!FerricastService.available)
                        return "Ferricast unavailable";
                    if (n === 0)
                        return "No receivers discovered";
                    return n + " receiver" + (n === 1 ? "" : "s") + (active > 0 ? " • " + active + " streaming" : "");
                }
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                Layout.fillWidth: true
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: refreshArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"
                Layout.alignment: Qt.AlignVCenter
                opacity: FerricastService.isRefreshing ? 0.5 : 1.0

                DankIcon {
                    anchors.centerIn: parent
                    name: FerricastService.isRefreshing ? "sync" : "refresh"
                    size: Theme.iconSize - 4
                    color: Theme.primary
                }

                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: FerricastService.isRefreshing ? Qt.BusyCursor : Qt.PointingHandCursor
                    enabled: !FerricastService.isRefreshing
                    onClicked: {
                        FerricastService.refreshDevices();
                        FerricastService.refreshActiveStreams();
                        if (FerricastService.canEnumerateMonitors)
                            FerricastService.refreshMonitors();
                        if (FerricastService.canEnumerateWindows)
                            FerricastService.refreshWindows();
                    }
                }
            }
        }

        Rectangle {
            height: 1
            width: parent.width
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        Item {
            width: parent.width
            height: root.listHeight

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: !FerricastService.available

                DankIcon {
                    name: "cast_off"
                    size: 36
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: "Ferricast daemon not running"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: "Start `ferricast` to discover receivers"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: FerricastService.available && FerricastService.deviceIds.length === 0

                DankIcon {
                    name: "cast"
                    size: 36
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: "No receivers found"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: "Make sure your TV / receiver is on the same network"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DankListView {
                id: deviceListView
                anchors.fill: parent
                visible: FerricastService.available && FerricastService.deviceIds.length > 0
                spacing: 8
                clip: true

                model: FerricastService.deviceIds

                delegate: Rectangle {
                    id: deviceDelegate
                    required property string modelData

                    property var device: FerricastService.getDevice(modelData)
                    property bool streaming: FerricastService.isStreaming(modelData)
                    property bool isExpanded: root.expandedDeviceId === modelData
                    property string expandedMode: isExpanded ? root.expandedMode : ""

                    width: deviceListView.width
                    height: cardCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                    Column {
                        id: cardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            DankIcon {
                                name: deviceDelegate.streaming ? "cast_connected" : "cast"
                                size: Theme.iconSize + 4
                                color: deviceDelegate.streaming ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                width: parent.width - Theme.iconSize - Theme.spacingM * 2 - actionsRow.width - 8

                                StyledText {
                                    text: deviceDelegate.device?.name || deviceDelegate.modelData
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                StyledText {
                                    text: {
                                        const d = deviceDelegate.device;
                                        if (!d)
                                            return "";
                                        const parts = [];
                                        if (d.protocol)
                                            parts.push(d.protocol);
                                        if (d.model)
                                            parts.push(d.model);
                                        else if (d.host)
                                            parts.push(d.host);
                                        if (deviceDelegate.streaming)
                                            parts.push("streaming");
                                        return parts.join(" • ");
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: deviceDelegate.streaming ? Theme.primary : Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            Row {
                                id: actionsRow
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                DankActionButton {
                                    visible: !deviceDelegate.streaming
                                    iconName: "play_arrow"
                                    iconColor: Theme.primary
                                    buttonSize: 36
                                    tooltipText: "Start streaming"
                                    onClicked: FerricastService.startDefault(deviceDelegate.modelData)
                                }

                                DankActionButton {
                                    visible: !deviceDelegate.streaming && FerricastService.canEnumerateMonitors
                                    iconName: "desktop_windows"
                                    iconColor: deviceDelegate.expandedMode === "monitors" ? Theme.primary : Theme.surfaceText
                                    buttonSize: 36
                                    tooltipText: "Pick a monitor"
                                    onClicked: {
                                        if (root.expandedDeviceId === deviceDelegate.modelData && root.expandedMode === "monitors") {
                                            root.expandedDeviceId = "";
                                            root.expandedMode = "";
                                        } else {
                                            root.expandedDeviceId = deviceDelegate.modelData;
                                            root.expandedMode = "monitors";
                                            FerricastService.refreshMonitors();
                                        }
                                    }
                                }

                                DankActionButton {
                                    visible: !deviceDelegate.streaming && FerricastService.canEnumerateWindows
                                    iconName: "select_window"
                                    iconColor: deviceDelegate.expandedMode === "windows" ? Theme.primary : Theme.surfaceText
                                    buttonSize: 36
                                    tooltipText: "Pick a window"
                                    onClicked: {
                                        if (root.expandedDeviceId === deviceDelegate.modelData && root.expandedMode === "windows") {
                                            root.expandedDeviceId = "";
                                            root.expandedMode = "";
                                        } else {
                                            root.expandedDeviceId = deviceDelegate.modelData;
                                            root.expandedMode = "windows";
                                            FerricastService.refreshWindows();
                                        }
                                    }
                                }

                                DankActionButton {
                                    visible: deviceDelegate.streaming
                                    iconName: "stop"
                                    iconColor: Theme.error
                                    buttonSize: 36
                                    tooltipText: "Stop streaming"
                                    onClicked: {
                                        FerricastService.stopStream(deviceDelegate.modelData, response => {
                                            if (response.error)
                                                ToastService.showError("Failed to stop", response.error);
                                        });
                                    }
                                }
                            }
                        }

                        Column {
                            visible: deviceDelegate.isExpanded && deviceDelegate.expandedMode === "monitors"
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                visible: FerricastService.monitors.length === 0
                                text: "No monitors reported"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Repeater {
                                model: FerricastService.monitors
                                Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 36
                                    radius: Theme.cornerRadius
                                    color: monArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.rightMargin: Theme.spacingM
                                        spacing: Theme.spacingS

                                        DankIcon {
                                            name: "desktop_windows"
                                            size: Theme.iconSize - 4
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: {
                                                const m = modelData;
                                                const label = m.name || m.id;
                                                if (m.width > 0 && m.height > 0)
                                                    return label + "  " + m.width + "×" + m.height + (m.primary ? " (primary)" : "");
                                                return label;
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: monArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            FerricastService.startMonitor(deviceDelegate.modelData, modelData.id);
                                            root.expandedDeviceId = "";
                                            root.expandedMode = "";
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            visible: deviceDelegate.isExpanded && deviceDelegate.expandedMode === "windows"
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                visible: FerricastService.windows.length === 0
                                text: "No windows reported"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Repeater {
                                model: FerricastService.windows
                                Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 36
                                    radius: Theme.cornerRadius
                                    color: winArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.rightMargin: Theme.spacingM
                                        spacing: Theme.spacingS

                                        DankIcon {
                                            name: "select_window"
                                            size: Theme.iconSize - 4
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: {
                                                const w = modelData;
                                                const label = w.title || w.appId || w.id;
                                                return w.appId && w.title ? (w.appId + " — " + w.title) : label;
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width - Theme.iconSize - Theme.spacingS
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: winArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            FerricastService.startWindow(deviceDelegate.modelData, modelData.id);
                                            root.expandedDeviceId = "";
                                            root.expandedMode = "";
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
