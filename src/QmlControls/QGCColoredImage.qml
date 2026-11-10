import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import QGroundControl.Palette

Item {
    property color color: "white"   // Image color

    // Compatibility with existing callers; the explicit color is always respected.
    property bool useToolbarIconColor: true

    // Brand images retain their original colors in every shared control.
    // Existing SVG-named resource aliases remain valid for older callers.
    readonly property bool _preserveBrandColors: {
        const resourcePath = image.source.toString().replace(/^qrc:/, "")
        return resourcePath === "/res/PGLogo.png"
            || /^\/res\/QGCLogo(?:Full|Black|White)(?:\.svg)?$/.test(resourcePath)
    }


    property alias asynchronous:        image.asynchronous
    property alias cache:               image.cache
    property alias fillMode:            image.fillMode
    property alias horizontalAlignment: image.horizontalAlignment
    property alias mirror:              image.mirror
    property alias paintedHeight:       image.paintedHeight
    property alias paintedWidth:        image.paintedWidth
    property alias progress:            image.progress
    property alias mipmap:              image.mipmap
    property alias source:              image.source
    property alias sourceSize:          image.sourceSize
    property alias status:              image.status
    property alias verticalAlignment:   image.verticalAlignment

    width:  image.width
    height: image.height

    Image {
        id:                 image
        smooth:             true
        mipmap:             true
        antialiasing:       true
        visible:            parent._preserveBrandColors
        fillMode:           Image.PreserveAspectFit
        anchors.fill:       parent
        sourceSize.height:  height
    }

    ColorOverlay {
        visible:            !parent._preserveBrandColors
        anchors.fill:       image
        source:             image
        color:              parent.color
    }
}
