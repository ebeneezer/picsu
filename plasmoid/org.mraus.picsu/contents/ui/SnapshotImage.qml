pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami

Item {
    id: root

    required property string imageUrl
    property url fallbackSource: ""
    property int fillMode: Image.PreserveAspectCrop
    property bool showFrame: true
    property bool showingA: true
    property bool pendingA: false
    property bool pendingB: false
    readonly property bool ready: showingA
        ? imageA.status === Image.Ready
        : imageB.status === Image.Ready
    readonly property real activePaintedWidth: showingA ? imageA.paintedWidth : imageB.paintedWidth
    readonly property real activePaintedHeight: showingA ? imageA.paintedHeight : imageB.paintedHeight
    readonly property real activeSourceWidth: showingA ? imageA.sourceSize.width : imageB.sourceSize.width
    readonly property real activeSourceHeight: showingA ? imageA.sourceSize.height : imageB.sourceSize.height
    readonly property real intrinsicAspectRatio: activeSourceWidth > 0 && activeSourceHeight > 0
        ? activeSourceWidth / activeSourceHeight
        : 0

    function requestImage(url) {
        if (url.length === 0) {
            return;
        }

        if (imageA.source.toString() === url || imageB.source.toString() === url) {
            return;
        }

        if (showingA) {
            pendingB = true;
            imageB.source = url;
        } else {
            pendingA = true;
            imageA.source = url;
        }
    }

    Image {
        id: imageA

        anchors.fill: parent
        cache: false
        asynchronous: true
        autoTransform: true
        fillMode: root.fillMode
        smooth: true
        mipmap: true
        visible: root.showingA && status === Image.Ready

        onStatusChanged: {
            if (root.pendingA && status === Image.Ready) {
                root.pendingA = false;
                root.showingA = true;
            }
        }
    }

    Image {
        id: imageB

        anchors.fill: parent
        cache: false
        asynchronous: true
        autoTransform: true
        fillMode: root.fillMode
        smooth: true
        mipmap: true
        visible: !root.showingA && status === Image.Ready

        onStatusChanged: {
            if (root.pendingB && status === Image.Ready) {
                root.pendingB = false;
                root.showingA = false;
            }
        }
    }

    onImageUrlChanged: requestImage(imageUrl)

    Rectangle {
        anchors.centerIn: parent
        width: root.activePaintedWidth > 0 ? root.activePaintedWidth : parent.width
        height: root.activePaintedHeight > 0 ? root.activePaintedHeight : parent.height
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1
        radius: 3
        visible: root.showFrame && root.ready
    }

    Image {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.62
        height: width
        source: root.fallbackSource
        autoTransform: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        opacity: 0.65
        visible: !root.ready && source.toString().length > 0
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.62
        height: width
        source: "kayda"
        opacity: 0.65
        visible: !root.ready && root.fallbackSource.toString().length === 0
    }

    Component.onCompleted: {
        if (imageUrl.length > 0) {
            pendingA = true;
            imageA.source = imageUrl;
        }
    }
}
