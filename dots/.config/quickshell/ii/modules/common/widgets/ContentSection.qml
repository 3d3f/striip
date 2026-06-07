import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ColumnLayout {
    id: root
    property string title
    property string icon: ""
    property string settingKey: ""

    default property alias contentData: sectionContent.data

    Layout.fillWidth: true
    spacing: 0

    readonly property bool isHighlighted: {
        const h = settingKey !== "" && SettingsSearchService.highlightSection === settingKey;
        return h;
    }

    function findParentFlickable() {
        let p = root.parent;
        while (p) {
            if (p.hasOwnProperty("contentY") && p.hasOwnProperty("contentItem"))
                return p;
            p = p.parent;
        }
        return null;
    }

    Component.onCompleted: {
        if (!settingKey) return;
        const key = settingKey;
        Qt.callLater(() => {
            if (!root.parent) return;
            const flickable = findParentFlickable();
            if (flickable)
                SettingsSearchService.registerCard(key, root, flickable);
        });
    }

    Component.onDestruction: {
        if (settingKey)
            SettingsSearchService.unregisterCard(settingKey);
    }

    // Item wrapper so retangle can use anchors freely (not managed by Layout)
    Item {
        Layout.fillWidth: true
        implicitHeight: contentCol.implicitHeight
        implicitWidth: contentCol.implicitWidth

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: -8
            anchors.leftMargin: -18
            anchors.rightMargin: -18
            anchors.bottomMargin: -26
            color: "transparent"
            radius: Appearance.rounding.normal
            border.width: 2
            border.color: root.isHighlighted ? Appearance.colors.colPrimary : "transparent"
            Behavior on border.color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        ColumnLayout {
            id: contentCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: 8
            }
            spacing: 6

            RowLayout {
                spacing: 6
                OptionalMaterialSymbol {
                    icon: root.icon
                    iconSize: Appearance.font.pixelSize.hugeass
                }
                StyledText {
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            ColumnLayout {
                id: sectionContent
                Layout.fillWidth: true
                spacing: 4
            }
        }
    }
}
