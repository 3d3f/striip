import QtQuick
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Taken from ii-vynx fork:
// https://github.com/vaguesyntax/ii-vynx/blob/main/dots/.config/quickshell/ii/modules/common/widgets/TransitionImage.qml

Item {
    id: root

    required property string imageSource

    readonly property var availableTypes: ["radial", "crossfade", "wipe", "diamond", "slash", "outer", "wave"]
    property string transitionType: Config.options.background.transitionType ?? "radial"
    property string resolvedTransitionType: "radial"
    property string lastUsedTransitionType: ""

    property int animationDuration: resolvedTransitionType === "radial" ? 1100 : 1000
    property var fillMode: Image.PreserveAspectCrop
    property bool animated: Config.options.background.animateWallpaperChanges

    property var sourceSize: Qt.size(0, 0)
    property bool cache: false
    property bool antialiasing: true
    property bool asynchronous: true
    property bool smooth: true
    property bool mipmap: true

    property bool transitionActive: false
    property bool ready: false

    property bool imgAIsBack: true
    property Item backImg: imgAIsBack ? imgA : imgB
    property Item frontImg: imgAIsBack ? imgB : imgA

    property int status: (imgA.status === Image.Ready || imgB.status === Image.Ready) ? Image.Ready : frontImg.status

    Component.onCompleted: {
        let cfgType = Config.options.background.transitionType ?? "radial"
        resolvedTransitionType = (cfgType === "random")
            ? availableTypes[Math.floor(Math.random() * availableTypes.length)]
            : cfgType
        ready = true
    }

    onImageSourceChanged: fadeTo(imageSource)

    property string currentWallpaper: ""

    function resolveType() {
        let cfgType = Config.options.background.transitionType ?? "radial"
        if (cfgType === "random") {
            let choices = availableTypes.filter(t => t !== root.lastUsedTransitionType)
            let picked = choices[Math.floor(Math.random() * choices.length)]
            root.lastUsedTransitionType = picked
            root.resolvedTransitionType = picked
        } else {
            root.lastUsedTransitionType = ""
            root.resolvedTransitionType = cfgType
        }
    }

    function fadeTo(newSrc) {
        if (!newSrc || newSrc === currentWallpaper) return

        let hasWallpaper = (currentWallpaper !== "")

        resolveType()

        if (root.animated && ready && root.width > 0 && root.height > 0 && hasWallpaper) {
            cleanupTransition()

            root.imgAIsBack = !root.imgAIsBack

            root.transitionActive = true
            frontImg.source = newSrc
            currentWallpaper = newSrc

            let wait = effectLoader.item ? effectLoader.item.waitForReady !== false : true

            if (!wait || frontImg.status === Image.Ready) {
                startTransition()
            }
        } else {
            cleanupTransition()
            root.imgAIsBack       = !root.imgAIsBack
            frontImg.source       = newSrc
            currentWallpaper      = newSrc
            root.transitionActive = false
        }
    }

    function startTransition() {
        if (effectLoader.item && typeof effectLoader.item.start === "function") {
            effectLoader.item.start()
        } else {
            cleanupTransition()
        }
    }

    function cleanupTransition() {
        root.transitionActive = false
        if (effectLoader.item && typeof effectLoader.item.cleanup === "function") {
            effectLoader.item.cleanup()
        }
    }

    Image {
        id: imgA
        anchors.fill: parent
        visible: root.imgAIsBack || (!root.transitionActive || !effectLoader.item || effectLoader.item.hideFront === false)
        layer.enabled: !visible && root.transitionActive
        z: root.imgAIsBack ? 0 : 1

        fillMode:     root.fillMode
        sourceSize:   root.sourceSize
        cache: root.cache; antialiasing: root.antialiasing
        asynchronous: root.asynchronous; smooth: root.smooth; mipmap: root.mipmap

        onStatusChanged: {
            let wait = effectLoader.item ? effectLoader.item.waitForReady !== false : true
            if (wait) {
                if (status === Image.Ready && root.transitionActive && !root.imgAIsBack) {
                    root.startTransition()
                } else if (status === Image.Error && root.transitionActive && !root.imgAIsBack) {
                    root.cleanupTransition()
                }
            }
        }
    }

    Image {
        id: imgB
        anchors.fill: parent
        visible: !root.imgAIsBack || (!root.transitionActive || !effectLoader.item || effectLoader.item.hideFront === false)
        layer.enabled: !visible && root.transitionActive
        z: !root.imgAIsBack ? 0 : 1

        fillMode:     root.fillMode
        sourceSize:   root.sourceSize
        cache: root.cache; antialiasing: root.antialiasing
        asynchronous: root.asynchronous; smooth: root.smooth; mipmap: root.mipmap

        onStatusChanged: {
            let wait = effectLoader.item ? effectLoader.item.waitForReady !== false : true
            if (wait) {
                if (status === Image.Ready && root.transitionActive && root.imgAIsBack) {
                    root.startTransition()
                } else if (status === Image.Error && root.transitionActive && root.imgAIsBack) {
                    root.cleanupTransition()
                }
            }
        }
    }

    Loader {
        id: effectLoader
        anchors.fill: parent
        source: "transitions/" + (root.resolvedTransitionType.charAt(0).toUpperCase() + root.resolvedTransitionType.slice(1)) + ".qml"

        onLoaded: {
            item.frontImg = Qt.binding(function() { return root.frontImg })
            item.backImg  = Qt.binding(function() { return root.backImg })
            item.duration = Qt.binding(function() { return root.animationDuration })
        }

        Connections {
            target: effectLoader.item
            function onFinished() {
                root.cleanupTransition()
            }
        }
    }
}