import QtQuick

import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Source")
        icon: "network-wired-symbolic"
        source: "config/ConfigSource.qml"
    }
}
