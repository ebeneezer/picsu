# Picsu Snapshot

Picsu Snapshot is a Plasma 6 plasmoid for showing a live image snapshot in a KDE panel.
It can read the image either from a local file or directly from an MQTT topic carrying
binary image payloads.

The applet was developed for a vertical Plasma panel on CachyOS, but the QML layout is
not tied to that form factor. The compact panel image keeps the source aspect ratio, and
the enlarged popup can be configured to close on defocus, close on click, or stay above
other windows until clicked.

## Features

- Filesystem source using a watched image path, for example `/dev/shm/picsu/snapshot.jpg`
- Direct MQTT source using QtMqtt
- Configurable broker host, port, topic, username, and password
- Configurable panel scaling and fit/crop behavior
- Live enlarged popup view

## Requirements

- KDE Plasma 6
- Qt 6 with QML support
- QtMqtt development package
- CMake 3.24 or newer
- A C++20 compiler

On CachyOS or Arch Linux, the relevant packages are typically:

```sh
sudo pacman -S cmake qt6-base qt6-declarative qt6-mqtt plasma-sdk
```

`plasma-sdk` is only needed for local viewer tools such as `plasmoidviewer`.

## Build

```sh
cmake -S . -B build
cmake --build build -j$(nproc)
```

The build writes the native QML plugin to:

```text
plasmoid/org.mraus.picsu/contents/imports/org/mraus/picsu/backend/
```

## Install

```sh
kpackagetool6 --type Plasma/Applet --install plasmoid/org.mraus.picsu
```

For an already installed development copy:

```sh
kpackagetool6 --type Plasma/Applet --upgrade plasmoid/org.mraus.picsu
```

Reload Plasma Shell after upgrading if the running instance still shows cached metadata:

```sh
systemctl --user restart plasma-plasmashell.service
```

## Configuration

Open the plasmoid settings from the Plasma panel.

For filesystem mode, choose the image file to watch. The backend avoids reloading the
image when path, modification time, and file size did not change.

For MQTT mode, configure broker host, port, topic, and optional credentials. The topic
payload must be a complete binary image such as JPEG or PNG.

## Support

For help, source inspection, and issue reports, use the GitHub repository:

```text
https://github.com/ebeneezer/picsu
```

Issues can be opened at:

```text
https://github.com/ebeneezer/picsu/issues
```

## Smoke Tests

```sh
plasmawindowed org.mraus.picsu
plasmoidviewer --applet org.mraus.picsu --formfactor vertical --location leftedge --size 120x520
qml6 -I plasmoid/org.mraus.picsu/contents/imports tools/backend-smoke.qml filesystem
qml6 -I plasmoid/org.mraus.picsu/contents/imports tools/backend-smoke.qml mqtt
```

The applet id is `org.mraus.picsu`.
