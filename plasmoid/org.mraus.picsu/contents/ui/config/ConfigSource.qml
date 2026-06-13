import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: root

    property string cfg_sourceMode: "filesystem"
    property alias cfg_filePath: filePathField.text
    property alias cfg_mqttHost: mqttHostField.text
    property alias cfg_mqttPort: mqttPortSpin.value
    property alias cfg_mqttTopic: mqttTopicField.text
    property alias cfg_mqttUsername: mqttUsernameField.text
    property alias cfg_mqttPassword: mqttPasswordField.text
    property alias cfg_compactScalePercent: compactScaleSpin.value
    property string cfg_compactFillMode: "fit"
    property string cfg_popupBehavior: "defocus"

    signal configurationChanged

    function syncModeIndex() {
        sourceModeCombo.currentIndex = cfg_sourceMode === "mqtt" ? 1 : 0;
    }

    function syncPopupBehaviorIndex() {
        if (cfg_popupBehavior === "click") {
            popupBehaviorCombo.currentIndex = 1;
        } else if (cfg_popupBehavior === "clickOnTop") {
            popupBehaviorCombo.currentIndex = 2;
        } else {
            popupBehaviorCombo.currentIndex = 0;
        }
    }

    function syncCompactFillModeIndex() {
        compactFillModeCombo.currentIndex = cfg_compactFillMode === "crop" ? 1 : 0;
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.ComboBox {
            id: sourceModeCombo

            Kirigami.FormData.label: i18n("Source:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Filesystem"), value: "filesystem" },
                { text: i18n("MQTT"), value: "mqtt" }
            ]
            onActivated: {
                root.cfg_sourceMode = currentValue;
                root.configurationChanged();
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Image file:")
            visible: root.cfg_sourceMode !== "mqtt"
            enabled: visible

            QQC2.TextField {
                id: filePathField
                Layout.fillWidth: true
                placeholderText: "/dev/shm/picsu/snapshot.jpg"
                onTextEdited: root.configurationChanged()
            }

            QQC2.Button {
                icon.name: "document-open-symbolic"
                text: i18n("Pick")
                onClicked: fileDialog.open()
            }
        }

        QQC2.TextField {
            id: mqttHostField
            Kirigami.FormData.label: i18n("Broker:")
            visible: root.cfg_sourceMode === "mqtt"
            enabled: visible
            placeholderText: "broker.example.org"
            onTextEdited: root.configurationChanged()
        }

        QQC2.SpinBox {
            id: mqttPortSpin
            Kirigami.FormData.label: i18n("Port:")
            visible: root.cfg_sourceMode === "mqtt"
            enabled: visible
            from: 1
            to: 65535
            editable: true
            onValueModified: root.configurationChanged()
        }

        QQC2.TextField {
            id: mqttTopicField
            Kirigami.FormData.label: i18n("Topic:")
            visible: root.cfg_sourceMode === "mqtt"
            enabled: visible
            onTextEdited: root.configurationChanged()
        }

        QQC2.TextField {
            id: mqttUsernameField
            Kirigami.FormData.label: i18n("Username:")
            visible: root.cfg_sourceMode === "mqtt"
            enabled: visible
            onTextEdited: root.configurationChanged()
        }

        QQC2.TextField {
            id: mqttPasswordField
            Kirigami.FormData.label: i18n("Password:")
            visible: root.cfg_sourceMode === "mqtt"
            enabled: visible
            echoMode: TextInput.Password
            onTextEdited: root.configurationChanged()
        }

        QQC2.ComboBox {
            id: popupBehaviorCombo

            Kirigami.FormData.label: i18n("Popup:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Open until defocus"), value: "defocus" },
                { text: i18n("Open until clicked"), value: "click" },
                { text: i18n("Open until clicked on top"), value: "clickOnTop" }
            ]
            onActivated: {
                root.cfg_popupBehavior = currentValue;
                root.configurationChanged();
            }
        }

        QQC2.SpinBox {
            id: compactScaleSpin

            Kirigami.FormData.label: i18n("Panel size:")
            from: 100
            to: 800
            stepSize: 25
            editable: true
            textFromValue: function(value) {
                return value + " %";
            }
            valueFromText: function(text) {
                return Number.fromLocaleString(Qt.locale(), text.replace(/[^0-9]/g, ""));
            }
            onValueModified: root.configurationChanged()
        }

        QQC2.ComboBox {
            id: compactFillModeCombo

            Kirigami.FormData.label: i18n("Panel image:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Fit whole image"), value: "fit" },
                { text: i18n("Fill area and crop"), value: "crop" }
            ]
            onActivated: {
                root.cfg_compactFillMode = currentValue;
                root.configurationChanged();
            }
        }
    }

    QtDialogs.FileDialog {
        id: fileDialog

        title: i18n("Choose snapshot image")
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        fileMode: QtDialogs.FileDialog.OpenFile
        nameFilters: [i18n("Images (*.jpg *.jpeg *.png *.webp *.gif *.bmp)"), i18n("All files (*)")]
        onAccepted: {
            root.cfg_filePath = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""));
            root.configurationChanged();
        }
    }

    Component.onCompleted: {
        syncModeIndex();
        syncPopupBehaviorIndex();
        syncCompactFillModeIndex();
    }
    onCfg_sourceModeChanged: syncModeIndex()
    onCfg_popupBehaviorChanged: syncPopupBehaviorIndex()
    onCfg_compactFillModeChanged: syncCompactFillModeIndex()
}
