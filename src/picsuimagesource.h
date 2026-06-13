#pragma once

#include <QByteArray>
#include <QDateTime>
#include <QFileSystemWatcher>
#include <QObject>
#include <QString>
#include <QTimer>

class QMqttClient;

class PicsuImageSource : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString sourceMode READ sourceMode WRITE setSourceMode NOTIFY sourceModeChanged)
    Q_PROPERTY(QString filePath READ filePath WRITE setFilePath NOTIFY filePathChanged)
    Q_PROPERTY(QString mqttHost READ mqttHost WRITE setMqttHost NOTIFY mqttHostChanged)
    Q_PROPERTY(int mqttPort READ mqttPort WRITE setMqttPort NOTIFY mqttPortChanged)
    Q_PROPERTY(QString mqttTopic READ mqttTopic WRITE setMqttTopic NOTIFY mqttTopicChanged)
    Q_PROPERTY(QString mqttUsername READ mqttUsername WRITE setMqttUsername NOTIFY mqttUsernameChanged)
    Q_PROPERTY(QString mqttPassword READ mqttPassword WRITE setMqttPassword NOTIFY mqttPasswordChanged)
    Q_PROPERTY(QString imageUrl READ imageUrl NOTIFY imageUrlChanged)
    Q_PROPERTY(double imageAspectRatio READ imageAspectRatio NOTIFY imageAspectRatioChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

public:
    explicit PicsuImageSource(QObject *parent = nullptr);
    ~PicsuImageSource() override;

    QString sourceMode() const;
    void setSourceMode(const QString &sourceMode);

    QString filePath() const;
    void setFilePath(const QString &filePath);

    QString mqttHost() const;
    void setMqttHost(const QString &mqttHost);

    int mqttPort() const;
    void setMqttPort(int mqttPort);

    QString mqttTopic() const;
    void setMqttTopic(const QString &mqttTopic);

    QString mqttUsername() const;
    void setMqttUsername(const QString &mqttUsername);

    QString mqttPassword() const;
    void setMqttPassword(const QString &mqttPassword);

    QString imageUrl() const;
    double imageAspectRatio() const;
    bool ready() const;
    QString statusText() const;

    Q_INVOKABLE void restart();

Q_SIGNALS:
    void sourceModeChanged();
    void filePathChanged();
    void mqttHostChanged();
    void mqttPortChanged();
    void mqttTopicChanged();
    void mqttUsernameChanged();
    void mqttPasswordChanged();
    void imageUrlChanged();
    void imageAspectRatioChanged();
    void readyChanged();
    void statusTextChanged();

private:
    void scheduleRestart();
    void applyConfiguration();
    void stopMqtt();
    void startMqtt();
    void setupFileWatcher();
    void readFile();
    void setImageData(const QByteArray &data, const QString &statusPrefix);
    void setImageUrl(const QString &imageUrl);
    void setImageAspectRatio(double imageAspectRatio);
    void setReady(bool ready);
    void setStatusText(const QString &statusText);

    static QString normalizedMode(const QString &sourceMode);
    static QString fileUrlWithToken(const QString &path);
    static QString dataUrlForImage(const QByteArray &data);
    static QString mimeTypeForImageData(const QByteArray &data);
    static double imageAspectRatioForData(const QByteArray &data);

    QString m_sourceMode = QStringLiteral("filesystem");
    QString m_filePath = QStringLiteral("/dev/shm/picsu/snapshot.jpg");
    QString m_mqttHost;
    int m_mqttPort = 1883;
    QString m_mqttTopic;
    QString m_mqttUsername;
    QString m_mqttPassword;
    QString m_imageUrl;
    double m_imageAspectRatio = 16.0 / 9.0;
    QString m_statusText = QStringLiteral("Not started");
    bool m_ready = false;
    QString m_lastFilePath;
    QDateTime m_lastFileMtime;
    qint64 m_lastFileSize = -1;

    QFileSystemWatcher m_fileWatcher;
    QTimer m_restartTimer;
    QTimer m_fileDebounceTimer;
    QMqttClient *m_mqttClient = nullptr;
};
