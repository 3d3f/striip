import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

pragma ComponentBehavior: Bound

Scope {
    id: dock

    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false

    readonly property bool isVertical: dockEffectivePosition === "left" || dockEffectivePosition === "right"
    readonly property real dockHeight: Config.options?.dock.height ?? 50
    readonly property real buttonSize: Math.round(dockHeight * 0.85)
    readonly property real dotMargin: Math.round(dockHeight * 0.2)
    readonly property real buttonSlotSize: buttonSize + dotMargin * 2
    readonly property real dockThickness:  buttonSlotSize + Appearance.sizes.hyprlandGapsOut * 2

    readonly property string dockEffectivePosition: {
        const pos = Config.options?.dock.position ?? "bottom"
        if (pos !== "auto") return pos
        return (Config.options?.bar.bottom && !Config.options?.bar.vertical) ? "top" : "bottom"
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData

            visible: !GlobalStates.screenLocked && !positionChanging

            readonly property real dockThickness: dock.dockThickness

            property bool reveal: false
            property bool positionChanging: false

            readonly property bool isMouseOver: triggerStrip.containsMouse
                || (dockLoader.item?.containsMouse ?? false)
                || triggerStripDrop.containsDrag
                || triggerStripDrop.containsDrag
                || (dockLoader.item?.externalDragOver ?? false)

            readonly property bool shouldBeOpen: dock.pinned
                || isMouseOver
                || (dockLoader.item?.requestDockShow ?? false)
                || (Config.options?.dock?.revealOnEmptyWorkspace && workspaceEmpty)

            function updateReveal() {
                if (dockRoot.shouldBeOpen) {
                    graceTimer.stop()
                    dockRoot.reveal = true
                } else if (!graceTimer.running) {
                    graceTimer.restart()
                }
            }

            onShouldBeOpenChanged: Qt.callLater(dockRoot.updateReveal)

            readonly property bool workspaceEmpty: {
                const wsId = HyprlandData.activeWorkspace?.id ?? -1
                return wsId === -1 || HyprlandData.hyprlandClientsForWorkspace(wsId).length === 0
            }

            onWorkspaceEmptyChanged: {
                if (!workspaceEmpty && !dockRoot.isMouseOver && !dock.pinned)
                    dockRoot.reveal = false
            }

            implicitWidth: dock.isVertical ? dockThickness : 1
            implicitHeight: dock.isVertical ? 1 : dockThickness

            anchors {
                top: dock.dockEffectivePosition !== "bottom"
                bottom: dock.dockEffectivePosition !== "top"
                left: dock.dockEffectivePosition !== "right"
                right: dock.dockEffectivePosition !== "left"
            }

            exclusiveZone: dock.pinned ? dockThickness : 0
            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            mask: Region {
                item: triggerStrip
                Region { 
                    item: dockLoader.item?.mouseArea ?? null 
                }
            }

            Timer {
                id: unloadTimer
                interval: Appearance.animation.elementMoveFast.duration + 100
            }

            Timer {
                id: graceTimer
                interval: 800
                onTriggered: if (!dockRoot.shouldBeOpen) dockRoot.reveal = false
            }

            onRevealChanged: {
                if (!reveal) unloadTimer.restart()
                else unloadTimer.stop()
            }

            Connections {
                target: dock
                function onDockEffectivePositionChanged() {
                    dockRoot.positionChanging = true
                    positionChangeTimer.restart()
                }
            }

            Timer {
                id: positionChangeTimer
                interval: 200
                onTriggered: dockRoot.positionChanging = false
            }

            HyprlandFocusGrab {
                id: dragFocusGrab
                active: dockLoader.activeAsync && (dockLoader.item ? dockLoader.item.dragState : "idle") !== "idle"
                windows: [dockRoot]
                onCleared: {
                    if (dockLoader.item && dockLoader.item.dragState !== "idle") {
                        dockLoader.item.endDrag()
                        dockLoader.item.endFileDrag()
                    }
                }
            }

            MouseArea {
                id: triggerStrip
                hoverEnabled: true
                z: 1
                readonly property real stripThickness: 2

                width: dock.isVertical ? stripThickness : parent.width
                height: dock.isVertical ? parent.height : stripThickness

                state: dock.dockEffectivePosition
                states: [
                    State {
                        name: "top"
                        AnchorChanges { target: triggerStrip; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter }
                    },
                    State {
                        name: "bottom"
                        AnchorChanges { target: triggerStrip; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
                    },
                    State {
                        name: "left"
                        AnchorChanges { target: triggerStrip; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                    },
                    State {
                        name: "right"
                        AnchorChanges { target: triggerStrip; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
                    }
                ]

                DropArea {
                    id: triggerStripDrop
                    anchors.fill: parent
                }
            }

            Item {
                id: dockContentHost
                anchors.fill: parent

                LazyLoader {
                    id: dockLoader
                    loading: true
                    active: dockRoot.reveal || unloadTimer.running

                    Item {
                        id: wrapper
                        parent: dockContentHost
                        anchors.fill: parent

                        readonly property real slideOffset: (dockRoot.reveal && content.ready) ? 0 : dock.dockThickness
                        readonly property Item mouseArea: dockMouseArea
                        readonly property bool containsMouse: dockMouseArea.containsMouse
                        readonly property string dragState: content.dragState
                        readonly property bool requestDockShow: content.requestDockShow
                        readonly property bool ready: content.ready
                        // Exposed property from DockContent.qml
                        readonly property bool externalDragOver: content.externalDragOver

                        function endDrag() { content.endDrag() }
                        function endFileDrag() { content.endFileDrag() }

                        opacity: (content.ready && !dockRoot.positionChanging) ? 1.0 : 0.0

                        MouseArea {
                            id: dockMouseArea
                            anchors.centerIn: parent
                            hoverEnabled: true
                            width: dock.isVertical
                                ? dock.buttonSlotSize
                                : Math.min(content.implicitWidth, parent.width - Appearance.sizes.hyprlandGapsOut * 2)
                            height: dock.isVertical
                                ? Math.min(content.implicitHeight, parent.height - Appearance.sizes.hyprlandGapsOut * 2)
                                : dock.buttonSlotSize
        
                            Rectangle {
                                id: visualBackground
                                anchors.fill: parent
                                color: Appearance.colors.colLayer0
                                border.width: 1
                                border.color: Appearance.colors.colLayer0Border
                                radius: Appearance.rounding.large

                                StyledRectangularShadow { target: visualBackground }

                                transform: Translate {
                                    y: dock.isVertical ? 0 : (dock.dockEffectivePosition === "bottom" ? wrapper.slideOffset : -wrapper.slideOffset)
                                    x: !dock.isVertical ? 0 : (dock.dockEffectivePosition === "right" ? wrapper.slideOffset : -wrapper.slideOffset)
                                    Behavior on y { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                                    Behavior on x { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                                }

                                DockContent {
                                    id: content
                                    anchors.fill: parent
                                    isPinned: dock.pinned
                                    currentScreen: dockRoot.screen
                                    onTogglePinRequested: dock.pinned = !dock.pinned
                                }

                                DropArea {
                                    id: fileDropArea
                                    anchors.fill: parent
                                    keys: ["text/uri-list"]
                                    enabled: content.dragActive === false
                                    onEntered: (drag) => {
                                        if (!drag.hasUrls) return
                                        const url = drag.urls[0]?.toString() ?? ""
                                        content.externalDragIcon = content.mimeIconFromPath(url)
                                        content.externalDragOver = true
                                    }
                                    onExited: {
                                        content.externalDragIcon = ""
                                        content.externalDragOver = false
                                    }
                                    onDropped: (drop) => {
                                        if (!drop.hasUrls) return
                                        for (let i = 0; i < drop.urls.length; i++)
                                            TaskbarApps.addPinnedFile(drop.urls[i])
                                        drop.accept(Qt.CopyAction)
                                        content.externalDragIcon = ""
                                        content.externalDragOver = false
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