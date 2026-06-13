pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../imports/org/mraus/picsu/backend" as PicsuBackend

PlasmoidItem {
    id: root

    Plasmoid.title: i18n("Picsu Snapshot")
    Plasmoid.icon: Qt.resolvedUrl("../images/kayda.jpeg")
    Plasmoid.status: imageSource.ready
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.PassiveStatus

    readonly property string popupBehavior: Plasmoid.configuration.popupBehavior || "defocus"

    hideOnWindowDeactivate: popupBehavior === "defocus"
    activationTogglesExpanded: false
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    toolTipMainText: Plasmoid.title
    toolTipSubText: imageSource.statusText

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar
        ? fullRepresentation
        : compactRepresentation

    function toggleLargeView() {
        if (popupBehavior === "defocus") {
            root.expanded = !root.expanded;
            return;
        }

        root.expanded = false;
        externalDialog.visible = !externalDialog.visible;
        if (externalDialog.visible) {
            externalDialog.raise();
            externalDialog.requestActivate();
        }
    }

    PicsuBackend.ImageSource {
        id: imageSource

        sourceMode: Plasmoid.configuration.sourceMode
        filePath: Plasmoid.configuration.filePath
        mqttHost: Plasmoid.configuration.mqttHost
        mqttPort: Plasmoid.configuration.mqttPort
        mqttTopic: Plasmoid.configuration.mqttTopic
        mqttUsername: Plasmoid.configuration.mqttUsername
        mqttPassword: Plasmoid.configuration.mqttPassword

        Component.onCompleted: restart()
    }

    compactRepresentation: Item {
        id: compactRoot

        readonly property real panelExtent: Math.max(
            Kirigami.Units.iconSizes.smallMedium,
            horizontalPanel ? root.height : (verticalPanel ? root.width : Math.min(root.width, root.height))
        )
        readonly property real imageAspectRatio: Math.max(0.1, imageSource.imageAspectRatio)
        readonly property real compactScale: Math.max(1, (Plasmoid.configuration.compactScalePercent || 300) / 100)
        readonly property bool compactCrop: Plasmoid.configuration.compactFillMode === "crop"
        readonly property bool horizontalPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
        readonly property bool verticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property real horizontalLength: panelExtent * imageAspectRatio * (compactCrop ? compactScale : 1)
        readonly property real verticalLength: panelExtent / imageAspectRatio * (compactCrop ? compactScale : 1)

        Layout.minimumWidth: horizontalPanel ? horizontalLength : Kirigami.Units.iconSizes.medium
        Layout.minimumHeight: verticalPanel ? verticalLength : Kirigami.Units.iconSizes.medium
        Layout.preferredWidth: horizontalPanel ? horizontalLength : panelExtent
        Layout.preferredHeight: verticalPanel ? verticalLength : panelExtent
        Layout.fillWidth: verticalPanel
        Layout.fillHeight: horizontalPanel
        Layout.maximumWidth: horizontalPanel ? Kirigami.Units.iconSizes.enormous * 8 : Kirigami.Units.iconSizes.enormous
        Layout.maximumHeight: verticalPanel ? Kirigami.Units.iconSizes.enormous * 8 : Kirigami.Units.iconSizes.enormous

        SnapshotImage {
            anchors.fill: parent
            imageUrl: imageSource.imageUrl
            fallbackSource: Qt.resolvedUrl("../images/kayda.jpeg")
            fillMode: compactRoot.compactCrop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            showFrame: false
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: root.toggleLargeView()
        }
    }

    fullRepresentation: Item {
        id: fullRoot

        readonly property real imageAspectRatio: Math.max(0.1, imageSource.imageAspectRatio)
        readonly property real preferredImageWidth: Kirigami.Units.gridUnit * 36
        readonly property real minimumImageWidth: Kirigami.Units.gridUnit * 16
        readonly property real effectiveImageWidth: width > 0 ? width : preferredImageWidth
        readonly property real effectiveImageHeight: effectiveImageWidth / imageAspectRatio

        Layout.minimumWidth: minimumImageWidth
        Layout.minimumHeight: minimumImageWidth / imageAspectRatio
        Layout.preferredWidth: preferredImageWidth
        Layout.preferredHeight: effectiveImageHeight
        Layout.maximumHeight: effectiveImageHeight

        SnapshotImage {
            anchors.fill: parent
            imageUrl: imageSource.imageUrl
            fallbackSource: Qt.resolvedUrl("../images/kayda.jpeg")
            fillMode: Image.PreserveAspectFit
            showFrame: true
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Kirigami.Units.smallSpacing
            text: imageSource.statusText
            color: Kirigami.Theme.textColor
            font: Kirigami.Theme.defaultFont
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            visible: !imageSource.ready
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            visible: false
        }
    }

    PlasmaCore.Dialog {
        id: externalDialog

        visualParent: root.compactRepresentationItem
        location: Plasmoid.location
        type: root.popupBehavior === "clickOnTop"
            ? PlasmaCore.Dialog.OnScreenDisplay
            : PlasmaCore.Dialog.DialogWindow
        hideOnWindowDeactivate: false
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.FramelessWindowHint | (root.popupBehavior === "clickOnTop" ? Qt.WindowStaysOnTopHint : 0)
        visible: false
        Component.onCompleted: {
            margins.left = Kirigami.Units.largeSpacing;
            margins.right = Kirigami.Units.largeSpacing;
            margins.top = Kirigami.Units.largeSpacing;
            margins.bottom = Kirigami.Units.largeSpacing;
        }

        mainItem: Item {
            id: externalDialogItem

            readonly property real imageAspectRatio: Math.max(0.1, imageSource.imageAspectRatio)
            readonly property real preferredImageWidth: Kirigami.Units.gridUnit * 36
            readonly property real edgePadding: Kirigami.Units.gridUnit

            width: preferredImageWidth + edgePadding * 2
            height: preferredImageWidth / imageAspectRatio + edgePadding * 2

            SnapshotImage {
                anchors.fill: parent
                anchors.margins: externalDialogItem.edgePadding
                imageUrl: imageSource.imageUrl
                fallbackSource: Qt.resolvedUrl("../images/kayda.jpeg")
                fillMode: Image.PreserveAspectFit
                showFrame: true
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Kirigami.Units.smallSpacing
                text: imageSource.statusText
                color: Kirigami.Theme.textColor
                font: Kirigami.Theme.defaultFont
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                visible: !imageSource.ready
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: externalDialog.visible = false
            }
        }
    }
}
