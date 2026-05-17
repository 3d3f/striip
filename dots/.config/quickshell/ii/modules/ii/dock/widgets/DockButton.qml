import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root

    property real buttonSize: dock.buttonSize
    
    width: buttonSize
    height: buttonSize
    buttonRadius: Appearance.rounding.normal
    background.implicitWidth: buttonSize
    background.implicitHeight: buttonSize
    padding: 0

    rippleEnabled: false
    colBackground: "transparent"
    colBackgroundHover: "transparent"
    colBackgroundToggled: "transparent"
    colBackgroundToggledHover: "transparent"
}
