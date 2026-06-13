#include "picsuimagesource.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class PicsuBackendPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<PicsuImageSource>(uri, 1, 0, "ImageSource");
    }
};

#include "picsubackendplugin.moc"
