/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Controllers

Rectangle {
    id:     _root
    width:  parent.width
    height: ScreenTools.toolbarHeight

    // Standard QGC toolbar background follows Indoor / Outdoor.
    color: qgcPal.toolbarBackground

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property color  _mainStatusBGColor: qgcPal.brandingPurple


    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator();
    }

    QGCPalette { id: qgcPal }

    /// Bottom single pixel divider
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         1
        color:          "black"
        visible:        qgcPal.globalTheme === QGCPalette.Light
        z:              1
    }

    // One continuous status gradient across the complete toolbar, as before.
    // Its width is the same for every state and its endpoint follows the theme.
    Rectangle {
        id: statusColorBackground
        anchors.fill: parent

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: _mainStatusBGColor }
            GradientStop { position: 1; color: _root.color }
        }
    }

    RowLayout {
        id:                     viewButtonRow
        anchors.bottomMargin:   1
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        spacing:                ScreenTools.defaultFontPixelWidth / 2

        QGCToolBarButton {
            id:                     currentButton
            Layout.preferredHeight: viewButtonRow.height
            icon.source:            "/res/PGLogo.png"
            logo:                   true
            onClicked:              mainWindow.showToolSelectDialog()

            // Preserve the native content item's geometry and input behavior.
            // Its small tinted texture is replaced visually by the image below.
            contentItem.opacity: 0

            // The image is inset into one white frame, rather than painted
            // behind a separate outline with a different corner contour.
            Rectangle {
                id: logoFrame
                parent: currentButton
                anchors.centerIn: currentButton.contentItem
                width: ScreenTools.defaultFontPixelHeight * 2
                height: width
                radius: width * 0.20
                color: "white"
                antialiasing: true
                z: 1

                readonly property real frameWidth: Math.max(1.5, width / 24)

                Image {
                    id: logoImage
                    anchors.fill: parent
                    anchors.margins: logoFrame.frameWidth
                    source: currentButton.icon.source
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: false

                    // Decode above the actual display resolution so the
                    // raster logo is not enlarged from a small UI texture.
                    sourceSize.width: Math.ceil(width * Math.max(1, Screen.devicePixelRatio) * 2)
                    sourceSize.height: Math.ceil(height * Math.max(1, Screen.devicePixelRatio) * 2)
                }
            }
        }

        MainStatusIndicator {
            id: mainStatusIndicator

            Layout.preferredHeight: viewButtonRow.height
        }

        QGCButton {
            id:                 disconnectButton
            text:               qsTr("Disconnect")
            onClicked:          _activeVehicle.closeVehicle()
            visible:            _activeVehicle && _communicationLost
        }
    }

    QGCFlickable {
        id:                     toolsFlickable
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * ScreenTools.largeFontPointRatio * 1.5
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth / 2
        anchors.left:           viewButtonRow.right
        anchors.bottomMargin:   1
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.right:          payloadSettingsButton.left
        contentWidth:           toolIndicators.width
        flickableDirection:     Flickable.HorizontalFlick

        FlyViewToolBarIndicators {
            id: toolIndicators

            // Older indicator modules do not expose compactHeader. Avoid a
            // fatal QML property assignment when only this toolbar is updated.
            Component.onCompleted: {
                if (toolIndicators.hasOwnProperty("compactHeader")) {
                    toolIndicators["compactHeader"] = true
                } else {
                    console.info("FlyViewToolBar: compactHeader is unavailable in FlyViewToolBarIndicators.qml; using its standard layout.")
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Settings
    Item {
        id: payloadSettingsButton

        anchors.right:
            brandingLogo.visible
                ? brandingLogo.left
                : parent.right

        anchors.rightMargin:
            ScreenTools.defaultFontPixelWidth

        anchors.verticalCenter: parent.verticalCenter

        width: Math.max(
            36,
            ScreenTools.defaultFontPixelHeight * 2.15
        )

        height: width

        QGCColoredImage {
            anchors.centerIn: parent

            width: parent.width * 0.55
            height: width
            sourceSize.height: height
            source: "/res/gear-black.svg"
            color: qgcPal.text
            fillMode: Image.PreserveAspectFit
            mipmap: true

            opacity:
                payloadSettingsMouseArea.pressed
                    ? 0.72
                    : payloadSettingsMenu.visible
                      || payloadSettingsMouseArea.containsMouse
                        ? 1.0
                        : 0.88

            Behavior on opacity {
                NumberAnimation { duration: 90 }
            }
        }

        MouseArea {
            id: payloadSettingsMouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (payloadSettingsMenu.visible) {
                    payloadSettingsMenu.close()
                } else {
                    payloadSettingsMenu.open()
                }
            }
        }
    }

    PayloadSettingsMenu {
        id: payloadSettingsMenu
        anchorItem: payloadSettingsButton
        widgetSettings: DropWidgetSettings
    }

    //-------------------------------------------------------------------------
    //-- Branding Logo
    Image {
        id:                     brandingLogo
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.margins:        ScreenTools.defaultFontPixelHeight * 0.66
        visible:                _activeVehicle && !_communicationLost && x > (toolsFlickable.x + toolsFlickable.contentWidth + payloadSettingsButton.width + ScreenTools.defaultFontPixelWidth * 2)
        fillMode:               Image.PreserveAspectFit
        source:                 _outdoorPalette ? _brandImageOutdoor : _brandImageIndoor
        mipmap:                 true

        property bool   _outdoorPalette:        qgcPal.globalTheme === QGCPalette.Light
        property bool   _corePluginBranding:    QGroundControl.corePlugin.brandImageIndoor.length != 0
        property string _userBrandImageIndoor:  QGroundControl.settingsManager.brandImageSettings.userBrandImageIndoor.value
        property string _userBrandImageOutdoor: QGroundControl.settingsManager.brandImageSettings.userBrandImageOutdoor.value
        property bool   _userBrandingIndoor:    QGroundControl.settingsManager.brandImageSettings.visible && _userBrandImageIndoor.length != 0
        property bool   _userBrandingOutdoor:   QGroundControl.settingsManager.brandImageSettings.visible && _userBrandImageOutdoor.length != 0
        property string _brandImageIndoor:      brandImageIndoor()
        property string _brandImageOutdoor:     brandImageOutdoor()

        function brandImageIndoor() {
            if (_userBrandingIndoor) {
                return _userBrandImageIndoor
            } else {
                if (_userBrandingOutdoor) {
                    return _userBrandImageOutdoor
                } else {
                    if (_corePluginBranding) {
                        return QGroundControl.corePlugin.brandImageIndoor
                    } else {
                        return _activeVehicle ? _activeVehicle.brandImageIndoor : ""
                    }
                }
            }
        }

        function brandImageOutdoor() {
            if (_userBrandingOutdoor) {
                return _userBrandImageOutdoor
            } else {
                if (_userBrandingIndoor) {
                    return _userBrandImageIndoor
                } else {
                    if (_corePluginBranding) {
                        return QGroundControl.corePlugin.brandImageOutdoor
                    } else {
                        return _activeVehicle ? _activeVehicle.brandImageOutdoor : ""
                    }
                }
            }
        }
    }

    // Small parameter download progress bar
    Rectangle {
        anchors.bottom: parent.bottom
        height:         _root.height * 0.05
        width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
        color:          qgcPal.colorGreen
        visible:        !largeProgressBar.visible
    }

    // Large parameter download progress bar
    Rectangle {
        id:             largeProgressBar
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:         parent.height
        color:          qgcPal.window
        visible:        _showLargeProgress

        property bool _initialDownloadComplete: _activeVehicle ? _activeVehicle.initialConnectComplete : true
        property bool _userHide:                false
        property bool _showLargeProgress:       !_initialDownloadComplete && !_userHide && qgcPal.globalTheme === QGCPalette.Light

        Connections {
            target:                 QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) { largeProgressBar._userHide = false }
        }

        Rectangle {
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
            color:          qgcPal.colorGreen
        }

        QGCLabel {
            anchors.centerIn:   parent
            text:               qsTr("Downloading")
            font.pointSize:     ScreenTools.largeFontPointSize
        }

        QGCLabel {
            anchors.margins:    _margin
            anchors.right:      parent.right
            anchors.bottom:     parent.bottom
            text:               qsTr("Click anywhere to hide")

            property real _margin: ScreenTools.defaultFontPixelWidth / 2
        }

        MouseArea {
            anchors.fill:   parent
            onClicked:      largeProgressBar._userHide = true
        }
    }
}
