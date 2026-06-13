#include "picsuimagesource.h"

#include <QMqttClient>
#include <QMqttTopicFilter>

#include <QBuffer>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QMimeDatabase>
#include <QUrl>

#include <algorithm>
#include <cmath>

PicsuImageSource::PicsuImageSource(QObject *parent)
    : QObject(parent)
{
    m_restartTimer.setSingleShot(true);
    m_restartTimer.setInterval(0);
    connect(&m_restartTimer, &QTimer::timeout, this, &PicsuImageSource::applyConfiguration);

    m_fileDebounceTimer.setSingleShot(true);
    m_fileDebounceTimer.setInterval(80);
    connect(&m_fileDebounceTimer, &QTimer::timeout, this, &PicsuImageSource::readFile);

    connect(&m_fileWatcher, &QFileSystemWatcher::fileChanged, this, [this]() {
        setupFileWatcher();
        m_fileDebounceTimer.start();
    });
    connect(&m_fileWatcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        setupFileWatcher();
        m_fileDebounceTimer.start();
    });
}

PicsuImageSource::~PicsuImageSource()
{
    stopMqtt();
}

QString PicsuImageSource::sourceMode() const
{
    return m_sourceMode;
}

void PicsuImageSource::setSourceMode(const QString &sourceMode)
{
    const QString mode = normalizedMode(sourceMode);
    if (m_sourceMode == mode) {
        return;
    }
    m_sourceMode = mode;
    Q_EMIT sourceModeChanged();
    scheduleRestart();
}

QString PicsuImageSource::filePath() const
{
    return m_filePath;
}

void PicsuImageSource::setFilePath(const QString &filePath)
{
    QString path = filePath;
    if (path.startsWith(QLatin1String("file://"))) {
        path = QUrl(path).toLocalFile();
    }
    if (m_filePath == path) {
        return;
    }
    m_filePath = path;
    Q_EMIT filePathChanged();
    scheduleRestart();
}

QString PicsuImageSource::mqttHost() const
{
    return m_mqttHost;
}

void PicsuImageSource::setMqttHost(const QString &mqttHost)
{
    if (m_mqttHost == mqttHost) {
        return;
    }
    m_mqttHost = mqttHost;
    Q_EMIT mqttHostChanged();
    scheduleRestart();
}

int PicsuImageSource::mqttPort() const
{
    return m_mqttPort;
}

void PicsuImageSource::setMqttPort(int mqttPort)
{
    const int boundedPort = std::clamp(mqttPort, 1, 65535);
    if (m_mqttPort == boundedPort) {
        return;
    }
    m_mqttPort = boundedPort;
    Q_EMIT mqttPortChanged();
    scheduleRestart();
}

QString PicsuImageSource::mqttTopic() const
{
    return m_mqttTopic;
}

void PicsuImageSource::setMqttTopic(const QString &mqttTopic)
{
    if (m_mqttTopic == mqttTopic) {
        return;
    }
    m_mqttTopic = mqttTopic;
    Q_EMIT mqttTopicChanged();
    scheduleRestart();
}

QString PicsuImageSource::mqttUsername() const
{
    return m_mqttUsername;
}

void PicsuImageSource::setMqttUsername(const QString &mqttUsername)
{
    if (m_mqttUsername == mqttUsername) {
        return;
    }
    m_mqttUsername = mqttUsername;
    Q_EMIT mqttUsernameChanged();
    scheduleRestart();
}

QString PicsuImageSource::mqttPassword() const
{
    return m_mqttPassword;
}

void PicsuImageSource::setMqttPassword(const QString &mqttPassword)
{
    if (m_mqttPassword == mqttPassword) {
        return;
    }
    m_mqttPassword = mqttPassword;
    Q_EMIT mqttPasswordChanged();
    scheduleRestart();
}

QString PicsuImageSource::imageUrl() const
{
    return m_imageUrl;
}

double PicsuImageSource::imageAspectRatio() const
{
    return m_imageAspectRatio;
}

bool PicsuImageSource::ready() const
{
    return m_ready;
}

QString PicsuImageSource::statusText() const
{
    return m_statusText;
}

void PicsuImageSource::restart()
{
    scheduleRestart();
}

void PicsuImageSource::scheduleRestart()
{
    m_restartTimer.start();
}

void PicsuImageSource::applyConfiguration()
{
    stopMqtt();
    m_fileWatcher.removePaths(m_fileWatcher.files());
    m_fileWatcher.removePaths(m_fileWatcher.directories());
    if (m_sourceMode == QLatin1String("mqtt")) {
        m_lastFilePath.clear();
        m_lastFileMtime = {};
        m_lastFileSize = -1;
    }

    if (m_sourceMode == QLatin1String("mqtt")) {
        startMqtt();
        return;
    }

    setupFileWatcher();
    readFile();
}

void PicsuImageSource::stopMqtt()
{
    if (!m_mqttClient) {
        return;
    }
    m_mqttClient->disconnectFromHost();
    m_mqttClient->deleteLater();
    m_mqttClient = nullptr;
}

void PicsuImageSource::startMqtt()
{
    if (m_mqttHost.isEmpty() || m_mqttTopic.isEmpty()) {
        setReady(false);
        setStatusText(QStringLiteral("MQTT host or topic is empty"));
        return;
    }

    m_mqttClient = new QMqttClient(this);
    m_mqttClient->setHostname(m_mqttHost);
    m_mqttClient->setPort(static_cast<quint16>(m_mqttPort));
    m_mqttClient->setUsername(m_mqttUsername);
    m_mqttClient->setPassword(m_mqttPassword);
    m_mqttClient->setClientId(QStringLiteral("picsu-plasmoid-%1").arg(QCoreApplication::applicationPid()));

    connect(m_mqttClient, &QMqttClient::connected, this, [this]() {
        setStatusText(QStringLiteral("MQTT connected"));
        auto *subscription = m_mqttClient->subscribe(QMqttTopicFilter(m_mqttTopic), 0);
        if (!subscription) {
            setStatusText(QStringLiteral("MQTT subscription failed"));
            setReady(false);
        }
    });

    connect(m_mqttClient, &QMqttClient::disconnected, this, [this]() {
        if (m_sourceMode == QLatin1String("mqtt")) {
            setStatusText(QStringLiteral("MQTT disconnected"));
        }
    });

    connect(m_mqttClient,
            &QMqttClient::messageReceived,
            this,
            [this](const QByteArray &message, const QMqttTopicName &) {
                setImageData(message, QStringLiteral("MQTT image"));
            });

    connect(m_mqttClient, &QMqttClient::errorChanged, this, [this](QMqttClient::ClientError error) {
        if (error != QMqttClient::NoError) {
            setStatusText(QStringLiteral("MQTT error %1").arg(static_cast<int>(error)));
            setReady(false);
        }
    });

    setStatusText(QStringLiteral("MQTT connecting"));
    setReady(false);
    m_mqttClient->connectToHost();
}

void PicsuImageSource::setupFileWatcher()
{
    m_fileWatcher.removePaths(m_fileWatcher.files());
    m_fileWatcher.removePaths(m_fileWatcher.directories());

    if (m_filePath.isEmpty()) {
        return;
    }

    const QFileInfo fileInfo(m_filePath);
    const QString directory = fileInfo.absolutePath();
    if (!directory.isEmpty() && QFileInfo::exists(directory)) {
        m_fileWatcher.addPath(directory);
    }
    if (fileInfo.exists()) {
        m_fileWatcher.addPath(fileInfo.absoluteFilePath());
    }
}

void PicsuImageSource::readFile()
{
    if (m_filePath.isEmpty()) {
        m_lastFilePath.clear();
        m_lastFileMtime = {};
        m_lastFileSize = -1;
        setReady(false);
        setStatusText(QStringLiteral("No snapshot path configured"));
        return;
    }

    const QFileInfo fileInfo(m_filePath);
    if (m_lastFilePath == fileInfo.absoluteFilePath()
        && m_lastFileMtime == fileInfo.lastModified()
        && m_lastFileSize == fileInfo.size()) {
        return;
    }

    QFile file(m_filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        setReady(false);
        setStatusText(QStringLiteral("Cannot read %1").arg(m_filePath));
        return;
    }

    const QByteArray data = file.readAll();
    if (data.isEmpty()) {
        setReady(false);
        setStatusText(QStringLiteral("Snapshot file is empty"));
        return;
    }

    setImageAspectRatio(imageAspectRatioForData(data));
    setImageUrl(fileUrlWithToken(m_filePath));
    m_lastFilePath = fileInfo.absoluteFilePath();
    m_lastFileMtime = fileInfo.lastModified();
    m_lastFileSize = fileInfo.size();
    setReady(true);
    setStatusText(QStringLiteral("Filesystem image"));
}

void PicsuImageSource::setImageData(const QByteArray &data, const QString &statusPrefix)
{
    if (data.isEmpty()) {
        setReady(false);
        setStatusText(statusPrefix + QStringLiteral(" is empty"));
        return;
    }
    setImageAspectRatio(imageAspectRatioForData(data));
    setImageUrl(dataUrlForImage(data));
    setReady(true);
    setStatusText(QStringLiteral("%1: %2 bytes").arg(statusPrefix).arg(data.size()));
}

void PicsuImageSource::setImageUrl(const QString &imageUrl)
{
    if (m_imageUrl == imageUrl) {
        return;
    }
    m_imageUrl = imageUrl;
    Q_EMIT imageUrlChanged();
}

void PicsuImageSource::setImageAspectRatio(double imageAspectRatio)
{
    if (!std::isfinite(imageAspectRatio) || imageAspectRatio <= 0.0) {
        imageAspectRatio = 16.0 / 9.0;
    }
    imageAspectRatio = std::clamp(imageAspectRatio, 0.1, 10.0);
    if (qFuzzyCompare(m_imageAspectRatio, imageAspectRatio)) {
        return;
    }
    m_imageAspectRatio = imageAspectRatio;
    Q_EMIT imageAspectRatioChanged();
}

void PicsuImageSource::setReady(bool ready)
{
    if (m_ready == ready) {
        return;
    }
    m_ready = ready;
    Q_EMIT readyChanged();
}

void PicsuImageSource::setStatusText(const QString &statusText)
{
    if (m_statusText == statusText) {
        return;
    }
    m_statusText = statusText;
    Q_EMIT statusTextChanged();
}

QString PicsuImageSource::normalizedMode(const QString &sourceMode)
{
    const QString mode = sourceMode.trimmed().toLower();
    return mode == QLatin1String("mqtt") ? QStringLiteral("mqtt") : QStringLiteral("filesystem");
}

QString PicsuImageSource::fileUrlWithToken(const QString &path)
{
    const QFileInfo info(path);
    QUrl url = QUrl::fromLocalFile(info.absoluteFilePath());
    url.setQuery(QStringLiteral("mtime=%1&size=%2")
                     .arg(info.lastModified().toMSecsSinceEpoch())
                     .arg(info.size()));
    return url.toString();
}

QString PicsuImageSource::dataUrlForImage(const QByteArray &data)
{
    return QStringLiteral("data:%1;base64,%2").arg(mimeTypeForImageData(data),
                                                   QString::fromLatin1(data.toBase64()));
}

QString PicsuImageSource::mimeTypeForImageData(const QByteArray &data)
{
    QBuffer buffer;
    buffer.setData(data);
    buffer.open(QIODevice::ReadOnly);

    QImageReader reader(&buffer);
    const QByteArray format = reader.format().toLower();
    if (format == "jpg" || format == "jpeg") {
        return QStringLiteral("image/jpeg");
    }
    if (format == "png") {
        return QStringLiteral("image/png");
    }
    if (format == "webp") {
        return QStringLiteral("image/webp");
    }
    if (format == "gif") {
        return QStringLiteral("image/gif");
    }
    if (format == "bmp") {
        return QStringLiteral("image/bmp");
    }

    QMimeDatabase mimeDatabase;
    const QString mimeName = mimeDatabase.mimeTypeForData(data).name();
    return mimeName.startsWith(QLatin1String("image/")) ? mimeName : QStringLiteral("image/jpeg");
}

double PicsuImageSource::imageAspectRatioForData(const QByteArray &data)
{
    QBuffer buffer;
    buffer.setData(data);
    buffer.open(QIODevice::ReadOnly);

    QImageReader reader(&buffer);
    const QSize encodedSize = reader.size();
    reader.setAutoTransform(true);

    const QImage image = reader.read();
    const QSize size = image.isNull() ? encodedSize : image.size();
    if (!size.isValid() || size.height() <= 0) {
        return 16.0 / 9.0;
    }

    return static_cast<double>(size.width()) / static_cast<double>(size.height());
}
