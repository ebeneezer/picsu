import QtQuick

import org.mraus.picsu.backend as Picsu

Item {
    id: root

    property int timeoutMs: 6000
    property string mode: Qt.application.arguments.length > 1 ? Qt.application.arguments[1] : "filesystem"
    property string filePath: "/dev/shm/picsu/snapshot.jpg"
    property string mqttHost: "broker.example.org"
    property int mqttPort: 1883
    property string mqttTopic: "picsu/snapshot"
    property string mqttUsername: ""
    property string mqttPassword: ""

    Picsu.ImageSource {
        id: imageSource

        sourceMode: root.mode
        filePath: root.filePath
        mqttHost: root.mqttHost
        mqttPort: root.mqttPort
        mqttTopic: root.mqttTopic
        mqttUsername: root.mqttUsername
        mqttPassword: root.mqttPassword

        onImageUrlChanged: console.log("imageUrl", imageUrl.length)
        onReadyChanged: console.log("ready", ready)
        onStatusTextChanged: console.log("status", statusText)

        Component.onCompleted: restart()
    }

    Timer {
        interval: root.timeoutMs
        running: true
        repeat: false
        onTriggered: {
            console.log("final", imageSource.ready, imageSource.statusText, imageSource.imageUrl.length);
            Qt.exit(imageSource.ready ? 0 : 2);
        }
    }
}
