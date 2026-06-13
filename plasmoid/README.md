# Picsu Snapshot Plasmoid

Minimal Plasma 6 applet for showing a live camera snapshot in the panel.

The applet can use either:

- `filesystem`: watch a local image file such as `/dev/shm/picsu/snapshot.jpg`
- `mqtt`: subscribe directly to an MQTT topic with QtMqtt

The panel and popup views use double-buffered QML image loading so the old
image remains visible until the new image has decoded.

## Build Backend

```sh
cmake -S . -B build
cmake --build build -j$(nproc)
```

## Install or Upgrade

```sh
kpackagetool6 --type Plasma/Applet --install plasmoid/org.mraus.picsu
kpackagetool6 --type Plasma/Applet --upgrade plasmoid/org.mraus.picsu
```

## Smoke Test

```sh
plasmawindowed org.mraus.picsu
plasmoidviewer --applet org.mraus.picsu --formfactor horizontal --location bottomedge --size 320x120
qml6 -I plasmoid/org.mraus.picsu/contents/imports tools/backend-smoke.qml filesystem
qml6 -I plasmoid/org.mraus.picsu/contents/imports tools/backend-smoke.qml mqtt
```

The applet id is `org.mraus.picsu`.
