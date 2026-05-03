import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        anchors.margins: sidebarPadding
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        focus: true
 
        StyledText {
            anchors.centerIn: parent
            text: Translation.tr("Enjoy your empty sidebar...")
            color: Appearance.colors.colSubtext
        }
    }
}
