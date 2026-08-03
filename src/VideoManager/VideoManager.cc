/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "VideoManager.h"
#include "AppSettings.h"
#include "MultiVehicleManager.h"
#include "QGCApplication.h"
#include "QGCCameraManager.h"
#include "QGCCorePlugin.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"
#include "SubtitleWriter.h"
#include "Vehicle.h"
#include "VideoReceiver.h"
#include "VideoSettings.h"
#ifdef QGC_GST_STREAMING
#include "GStreamer.h"
#else
#include "VideoItemStub.h"
#endif
#include "QtMultimediaReceiver.h"
#include "UVCReceiver.h"

#include <QtCore/qapplicationstatic.h>
#include <QtCore/QDir>
#include <QtQml/QQmlEngine>
#include <QtQuick/QQuickItem>
#include <QtQuick/QQuickWindow>
#include <QtCore/QTimer>

QGC_LOGGING_CATEGORY(VideoManagerLog, "qgc.videomanager.videomanager")

static constexpr const char *kFileExtension[VideoReceiver::FILE_FORMAT_MAX + 1] = {
    "mkv",
    "mov",
    "mp4"
};

Q_APPLICATION_STATIC(VideoManager, _videoManagerInstance);

VideoManager::VideoManager(QObject *parent)
    : QObject(parent)
      , _subtitleWriter(new SubtitleWriter(this))
      , _videoSettings(SettingsManager::instance()->videoSettings())
{
    // qCDebug(VideoManagerLog) << this;

    (void) qRegisterMetaType<VideoReceiver::STATUS>("STATUS");

#ifdef QGC_GST_STREAMING
    if (!GStreamer::initialize()) {
        qCCritical(VideoManagerLog) << "Failed To Initialize GStreamer";
    }
#endif
}

VideoManager::~VideoManager()
{
   // qCDebug(VideoManagerLog) << this;
}

VideoManager *VideoManager::instance()
{
    return _videoManagerInstance();
}

void VideoManager::registerQmlTypes()
{
    (void) qmlRegisterUncreatableType<VideoManager>("QGroundControl.VideoManager", 1, 0, "VideoManager", "Reference only");
    (void) qmlRegisterUncreatableType<VideoReceiver>("QGroundControl", 1, 0, "VideoReceiver","Reference only");
#ifndef QGC_GST_STREAMING
    (void) qmlRegisterType<VideoItemStub>("org.freedesktop.gstreamer.Qt6GLVideoItem", 1, 0, "GstGLQt6VideoItem");
#endif
}

void VideoManager::init(QQuickWindow *window)
{
    if (_initialized) {
        return;
    }

    if (!window) {
        qCCritical(VideoManagerLog) << "Failed To Init Video Manager - window is NULL";
        return;
    }

            // TODO: VideoSettings _configChanged/streamConfiguredChanged
    (void) connect(_videoSettings->videoSource(), &Fact::rawValueChanged, this, &VideoManager::_videoSourceChanged);
    (void) connect(_videoSettings->streamEnabled(), &Fact::rawValueChanged, this, &VideoManager::_videoSourceChanged);
    (void) connect(_videoSettings->udpUrl(), &Fact::rawValueChanged, this, &VideoManager::_videoSourceChanged);
    (void) connect(_videoSettings->rtspUrl(), &Fact::rawValueChanged, this, &VideoManager::_videoSourceChanged);
    (void) connect(_videoSettings->tcpUrl(), &Fact::rawValueChanged, this, &VideoManager::_videoSourceChanged);
    (void) connect(_videoSettings->aspectRatio(), &Fact::rawValueChanged, this, &VideoManager::aspectRatioChanged);
    (void) connect(_videoSettings->lowLatencyMode(), &Fact::rawValueChanged, this, [this](const QVariant &value) { Q_UNUSED(value); _restartAllVideos(); });
    (void) connect(MultiVehicleManager::instance(), &MultiVehicleManager::activeVehicleChanged, this, &VideoManager::_setActiveVehicle);

    (void) connect(this, &VideoManager::autoStreamConfiguredChanged, this, &VideoManager::_videoSourceChanged);

    static const QStringList videoStreamList = {
        "videoContent",
        "thermalVideo"
    };
    for (const QString &streamName : videoStreamList) {
        VideoReceiver *receiver = QGCCorePlugin::instance()->createVideoReceiver(this);
        if (!receiver) {
            continue;
        }
        receiver->setName(streamName);

        _initVideoReceiver(receiver, window);
    }

    window->scheduleRenderJob(new FinishVideoInitialization(), QQuickWindow::BeforeSynchronizingStage);

    _initialized = true;
}

void VideoManager::cleanup()
{
    for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
        QGCCorePlugin::instance()->releaseVideoSink(receiver->sink());
    }

    if (_pgrDetachedVideoReceiver && _pgrDetachedVideoReceiver->sink()) {
        QGCCorePlugin::instance()->releaseVideoSink(
            _pgrDetachedVideoReceiver->sink()
            );
    }
}

void VideoManager::_cleanupOldVideos()
{
    if (!SettingsManager::instance()->videoSettings()->enableStorageLimit()->rawValue().toBool()) {
        return;
    }

    const QString savePath = SettingsManager::instance()->appSettings()->videoSavePath();
    QDir videoDir = QDir(savePath);
    videoDir.setFilter(QDir::Files | QDir::Readable | QDir::NoSymLinks | QDir::Writable);
    videoDir.setSorting(QDir::Time);

    QStringList nameFilters;
    for (size_t i = 0; i < std::size(kFileExtension); i++) {
        nameFilters << QStringLiteral("*.") + kFileExtension[i];
    }

    videoDir.setNameFilters(nameFilters);
    QFileInfoList vidList = videoDir.entryInfoList();
    if (vidList.isEmpty()) {
        return;
    }

    uint64_t total = 0;
    for (const QFileInfo &video : std::as_const(vidList)) {
        total += video.size();
    }

    const uint64_t maxSize = SettingsManager::instance()->videoSettings()->maxVideoSize()->rawValue().toUInt() * qPow(1024, 2);
    while ((total >= maxSize) && !vidList.isEmpty()) {
        const QFileInfo info = vidList.takeLast();
        total -= info.size();
        const QString path = info.filePath();
        qCDebug(VideoManagerLog) << "Removing old video file:" << path;
        (void) QFile::remove(path);
    }
}

void VideoManager::startRecording(const QString &videoFile)
{
    const VideoReceiver::FILE_FORMAT fileFormat = static_cast<VideoReceiver::FILE_FORMAT>(_videoSettings->recordingFormat()->rawValue().toInt());
    if (!VideoReceiver::isValidFileFormat(fileFormat)) {
        qgcApp()->showAppMessage(tr("Invalid video format defined."));
        return;
    }

    _cleanupOldVideos();

    const QString savePath = SettingsManager::instance()->appSettings()->videoSavePath();
    if (savePath.isEmpty()) {
        qgcApp()->showAppMessage(tr("Unabled to record video. Video save path must be specified in Settings."));
        return;
    }

    const QString videoFileUrl = videoFile.isEmpty() ? QDateTime::currentDateTime().toString("yyyy-MM-dd_hh.mm.ss") : videoFile;
    const QString ext = kFileExtension[fileFormat];

    const QString videoFileNameTemplate = savePath + "/" + videoFileUrl + ".%1" + ext;

    for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
        if (!receiver->started()) {
            qCDebug(VideoManagerLog) << "Video receiver is not ready.";
            continue;
        }
        const QString streamName = (receiver->name() == QStringLiteral("videoContent")) ? "" : (receiver->name() + ".");
        const QString videoFileName = videoFileNameTemplate.arg(streamName);
        receiver->startRecording(videoFileName, fileFormat);
    }
}

void VideoManager::stopRecording()
{
    for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
        receiver->stopRecording();
    }
}

void VideoManager::grabImage(const QString &imageFile)
{
    if (imageFile.isEmpty()) {
        _imageFile = SettingsManager::instance()->appSettings()->photoSavePath();
        _imageFile += QStringLiteral("/") + QDateTime::currentDateTime().toString("yyyy-MM-dd_hh.mm.ss.zzz") + QStringLiteral(".jpg");
    } else {
        _imageFile = imageFile;
    }

    emit imageFileChanged(_imageFile);

    for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
        receiver->takeScreenshot(_imageFile);
        // QSharedPointer<QQuickItemGrabResult> result = receiver->widget()->grabToImage(const QSize &targetSize = QSize())
    }
}

double VideoManager::aspectRatio() const
{
    for (VideoReceiver *receiver : _videoReceivers) {
        QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
        if (!receiver->isThermal() && pInfo && !pInfo->isThermal()) {
            return pInfo->aspectRatio();
        }
    }

            // FIXME: use _videoReceiver->videoSize() to calculate AR (if AR is not specified in the settings?)
    return _videoSettings->aspectRatio()->rawValue().toDouble();
}

double VideoManager::thermalAspectRatio() const
{
    for (VideoReceiver *receiver : _videoReceivers) {
        QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
        if (receiver->isThermal() && pInfo && pInfo->isThermal()) {
            return pInfo->aspectRatio();
        }
    }

    return hasPgrZt6Substream() ? (640.0 / 512.0) : 1.0;
}

double VideoManager::hfov() const
{
    for (VideoReceiver *receiver : _videoReceivers) {
        QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
        if (!receiver->isThermal() && pInfo && !pInfo->isThermal()) {
            return pInfo->hfov();
        }
    }

    return 1.0;
}

double VideoManager::thermalHfov() const
{
    for (VideoReceiver *receiver : _videoReceivers) {
        QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
        if (receiver->isThermal() && pInfo && pInfo->isThermal()) {
            return pInfo->hfov();
        }
    }

    return _videoSettings->aspectRatio()->rawValue().toDouble();
}

bool VideoManager::hasThermal() const
{
    for (VideoReceiver *receiver : _videoReceivers) {
        QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
        if (receiver->isThermal() && pInfo && pInfo->isThermal()) {
            return true;
        }
    }

    return hasPgrZt6Substream();
}

bool VideoManager::hasPgrZt6Substream() const
{
    return !_pgrZt6SubstreamUri().isEmpty();
}

void VideoManager::setPgrZt6SubstreamEnabled(bool enabled)
{
    if (_pgrZt6SubstreamEnabled == enabled) {
        return;
    }

    _pgrZt6SubstreamEnabled = enabled;
    emit pgrZt6SubstreamEnabledChanged();

    for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
        if (!receiver || !receiver->isThermal()) {
            continue;
        }

        if (!enabled) {
            qCDebug(VideoManagerLog) << "PGR ZT6 substream disabled";

                    // Clear URI before stopping so onStopComplete cannot restart video2.
            _updateVideoUri(receiver, QString());
            _stopReceiver(receiver);

            if (_pgrZt6SubstreamDecoding) {
                _pgrZt6SubstreamDecoding = false;
                emit pgrZt6SubstreamDecodingChanged();
            }
        } else {
            qCDebug(VideoManagerLog) << "PGR ZT6 substream enabled";

            if (!hasPgrZt6Substream()) {
                // A8/main.264 and other single-stream cameras do not have video2.
                // Keep the thermal/sub receiver passive.
                _updateVideoUri(receiver, QString());
                return;
            }

            _updateSettings(receiver);
            _restartVideo(receiver);
        }

        break;
    }
}

bool VideoManager::hasVideo() const
{
    return (_videoSettings->streamEnabled()->rawValue().toBool() && _videoSettings->streamConfigured());
}

bool VideoManager::isUvc() const
{
    return (!_uvcVideoSourceID.isEmpty() && uvcEnabled() && hasVideo());
}

bool VideoManager::gstreamerEnabled()
{
#ifdef QGC_GST_STREAMING
    return true;
#else
    return false;
#endif
}

bool VideoManager::uvcEnabled()
{
    return UVCReceiver::enabled();
}

bool VideoManager::qtmultimediaEnabled()
{
    return QtMultimediaReceiver::enabled();
}

void VideoManager::setfullScreen(bool on)
{
    if (on) {
        if (!_activeVehicle || _activeVehicle->vehicleLinkManager()->communicationLost()) {
            on = false;
        }
    }

    if (on != _fullScreen) {
        _fullScreen = on;
        emit fullScreenChanged();
    }
}

bool VideoManager::isStreamSource() const
{
    static const QStringList videoSourceList = {
        VideoSettings::videoSourceUDPH264,
        VideoSettings::videoSourceUDPH265,
        VideoSettings::videoSourceRTSP,
        VideoSettings::videoSourceTCP,
        VideoSettings::videoSourceMPEGTS,
        VideoSettings::videoSource3DRSolo,
        VideoSettings::videoSourceParrotDiscovery,
        VideoSettings::videoSourceYuneecMantisG,
        VideoSettings::videoSourceHerelinkAirUnit,
        VideoSettings::videoSourceHerelinkHotspot,
    };
    const QString videoSource = _videoSettings->videoSource()->rawValue().toString();
    return (videoSourceList.contains(videoSource) || autoStreamConfigured());
}

void VideoManager::_videoSourceChanged()
{
    bool changed = false;
    if (_activeVehicle) {
        QGCCameraManager* camMgr = _activeVehicle->cameraManager();
        for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
            QGCVideoStreamInfo* info = nullptr;
            if (receiver->isThermal()) {
                info = camMgr ? camMgr->thermalStreamInstance() : nullptr;
            } else {
                info = camMgr ? camMgr->currentStreamInstance() : nullptr;
            }
            // Assign stream info
            receiver->setVideoStreamInfo(info);
            changed |= _updateSettings(receiver);
        }
    } else {
        for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
            receiver->setVideoStreamInfo(nullptr);
            changed |= _updateSettings(receiver);
        }
    }

    if (changed) {
        emit hasVideoChanged();
        emit hasThermalChanged();
        emit isStreamSourceChanged();
        emit isAutoStreamChanged();

        if (hasVideo()) {
            _restartAllVideos();
        } else {
            stopVideo();
        }

        qCDebug(VideoManagerLog) << "New Video Source:" << _videoSettings->videoSource()->rawValue().toString();

        if (_pgrDetachedRequested) {
            QTimer::singleShot(0, this, [this]() {
                _startRequestedPgrDetachedStream();
            });
        }
    }
}

bool VideoManager::_updateUVC(VideoReceiver *receiver)
{
    bool result = false;

    const QString oldUvcVideoSrcID = _uvcVideoSourceID;

    if (!uvcEnabled() || !hasVideo() || isStreamSource()) {
        _uvcVideoSourceID = QString();
    } else {
        _uvcVideoSourceID = UVCReceiver::getSourceId();
    }

    if (oldUvcVideoSrcID != _uvcVideoSourceID) {
        qCDebug(VideoManagerLog) << "UVC changed from [" << oldUvcVideoSrcID << "] to [" << _uvcVideoSourceID << "]";
        if (!_uvcVideoSourceID.isEmpty()) {
            UVCReceiver::checkPermission();
        }
        result = true;
        emit uvcVideoSourceIDChanged();
        emit isUvcChanged();
    }

    return result;
}

bool VideoManager::autoStreamConfigured() const
{
    for (VideoReceiver *receiver : _videoReceivers) {
        QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
        if (!receiver->isThermal() && pInfo && !pInfo->isThermal()) {
            return !pInfo->uri().isEmpty();
        }
    }

    return false;
}

bool VideoManager::_updateAutoStream(VideoReceiver *receiver)
{
    const QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
    if (!pInfo) {
        return false;
    }

    qCDebug(VideoManagerLog) << QString("Configure stream (%1):").arg(receiver->name()) << pInfo->uri();

    QString source, url;
    switch (pInfo->type()) {
        case VIDEO_STREAM_TYPE_RTSP:
            source = VideoSettings::videoSourceRTSP;
            url = pInfo->uri();
            if (source == VideoSettings::videoSourceRTSP) {
                _videoSettings->rtspUrl()->setRawValue(url);
            }
            break;
        case VIDEO_STREAM_TYPE_TCP_MPEG:
            source = VideoSettings::videoSourceTCP;
            url = pInfo->uri();
            break;
        case VIDEO_STREAM_TYPE_RTPUDP:
            if (pInfo->encoding() == VIDEO_STREAM_ENCODING_H265) {
                source = VideoSettings::videoSourceUDPH265;
                url = pInfo->uri().contains("udp265://") ? pInfo->uri() : QStringLiteral("udp265://0.0.0.0:%1").arg(pInfo->uri());
            } else {
                source = VideoSettings::videoSourceUDPH264;
                url = pInfo->uri().contains("udp://") ? pInfo->uri() : QStringLiteral("udp://0.0.0.0:%1").arg(pInfo->uri());
            }
            break;
        case VIDEO_STREAM_TYPE_MPEG_TS:
            source = VideoSettings::videoSourceMPEGTS;
            url = pInfo->uri().contains("mpegts://") ? pInfo->uri() : QStringLiteral("mpegts://0.0.0.0:%1").arg(pInfo->uri());
            break;
        default:
            qCWarning(VideoManagerLog) << "Unknown VIDEO_STREAM_TYPE";
            source = VideoSettings::videoSourceNoVideo;
            url = pInfo->uri();
            break;
    }

    const bool settingsChanged = _updateVideoUri(receiver, url);
    if (settingsChanged) {
        if (!receiver->isThermal()) {
            _videoSettings->videoSource()->setRawValue(source);
        }

        emit autoStreamConfiguredChanged();
    }

    return settingsChanged;
}

bool VideoManager::_updateVideoUri(VideoReceiver *receiver, const QString &uri)
{
    if (!receiver) {
        qCDebug(VideoManagerLog) << "VideoReceiver is NULL";
        return false;
    }

    if ((uri == receiver->uri()) && !receiver->uri().isNull()) {
        return false;
    }

    qCDebug(VideoManagerLog) << "New Video URI" << uri;

    receiver->setUri(uri);

    return true;
}

QString VideoManager::_pgrZt6SubstreamUri() const
{
    if (!_videoSettings || !_videoSettings->streamEnabled()->rawValue().toBool()) {
        return QString();
    }

    QString mainUrl = _videoSettings->rtspUrl()->rawValue().toString().trimmed();
    if (mainUrl.isEmpty() || !mainUrl.startsWith(QStringLiteral("rtsp://"), Qt::CaseInsensitive)) {
        return QString();
    }

    if (mainUrl.endsWith(QStringLiteral("/video1"), Qt::CaseInsensitive)) {
        mainUrl.chop(QStringLiteral("/video1").size());
        return mainUrl + QStringLiteral("/video2");
    }

    if (mainUrl.endsWith(QStringLiteral("/video1/"), Qt::CaseInsensitive)) {
        mainUrl.chop(QStringLiteral("/video1/").size());
        return mainUrl + QStringLiteral("/video2");
    }

    return QString();
}

bool VideoManager::_updateSettings(VideoReceiver *receiver)
{
    if (!receiver) {
        qCDebug(VideoManagerLog) << "VideoReceiver is NULL";
        return false;
    }

    bool settingsChanged = false;

    const bool lowLatency = _videoSettings->lowLatencyMode()->rawValue().toBool();
    if (lowLatency != receiver->lowLatency()) {
        receiver->setLowLatency(lowLatency);
        settingsChanged = true;
    }

    if (receiver->isThermal()) {
        const QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
        const bool hasRealThermalStream = pInfo && pInfo->isThermal() && !pInfo->uri().isEmpty();

                // For normal QGC thermal streams, keep the original stream info URI.
                // For PGR/ZT6, use derived /video2 only when it actually exists.
                // For A8/main.264 and other single-stream cameras, keep thermal receiver disabled.
        const QString thermalUri = hasRealThermalStream
                                       ? pInfo->uri()
                                       : (_pgrZt6SubstreamEnabled ? _pgrZt6SubstreamUri() : QString());

        if (thermalUri.isEmpty()) {
            settingsChanged |= _updateVideoUri(receiver, QString());

            if (_pgrZt6SubstreamDecoding) {
                _pgrZt6SubstreamDecoding = false;
                emit pgrZt6SubstreamDecodingChanged();
            }

            return settingsChanged;
        }

        settingsChanged |= _updateVideoUri(receiver, thermalUri);

        qCDebug(VideoManagerLog) << "Thermal/PGR substream URI:" << thermalUri;

        return settingsChanged;
    }

    settingsChanged |= _updateUVC(receiver);
    settingsChanged |= _updateAutoStream(receiver);

    const QString source = _videoSettings->videoSource()->rawValue().toString();
    if (source == VideoSettings::videoSourceUDPH264) {
        settingsChanged |= _updateVideoUri(receiver, QStringLiteral("udp://%1").arg(_videoSettings->udpUrl()->rawValue().toString()));
    } else if (source == VideoSettings::videoSourceUDPH265) {
        settingsChanged |= _updateVideoUri(receiver, QStringLiteral("udp265://%1").arg(_videoSettings->udpUrl()->rawValue().toString()));
    } else if (source == VideoSettings::videoSourceMPEGTS) {
        settingsChanged |= _updateVideoUri(receiver, QStringLiteral("mpegts://%1").arg(_videoSettings->udpUrl()->rawValue().toString()));
    } else if (source == VideoSettings::videoSourceRTSP) {
        QString rtspUrl = _videoSettings->rtspUrl()->rawValue().toString().trimmed();

        if (rtspUrl.startsWith(QStringLiteral("rtsp:/"), Qt::CaseInsensitive)
            && !rtspUrl.startsWith(QStringLiteral("rtsp://"), Qt::CaseInsensitive)) {
            rtspUrl = QStringLiteral("rtsp://") + rtspUrl.mid(QStringLiteral("rtsp:/").size());
            qCWarning(VideoManagerLog) << "Normalized invalid RTSP URL to:" << rtspUrl;
        }

        settingsChanged |= _updateVideoUri(receiver, rtspUrl);
    } else if (source == VideoSettings::videoSourceTCP) {
        settingsChanged |= _updateVideoUri(receiver, QStringLiteral("tcp://%1").arg(_videoSettings->tcpUrl()->rawValue().toString()));
    } else if (source == VideoSettings::videoSource3DRSolo) {
        settingsChanged |= _updateVideoUri(receiver, QStringLiteral("udp://0.0.0.0:5600"));
    } else if (source == VideoSettings::videoSourceParrotDiscovery) {
        settingsChanged |= _updateVideoUri(receiver, QStringLiteral("udp://0.0.0.0:8888"));
    } else if (source == VideoSettings::videoSourceYuneecMantisG) {
        settingsChanged |= _updateVideoUri(receiver, QStringLiteral("rtsp://192.168.42.1:554/live"));
    } else if (source == VideoSettings::videoSourceHerelinkAirUnit) {
        settingsChanged |= _updateVideoUri(receiver, QStringLiteral("rtsp://192.168.0.10:8554/H264Video"));
    } else if (source == VideoSettings::videoSourceHerelinkHotspot) {
        settingsChanged |= _updateVideoUri(receiver, QStringLiteral("rtsp://192.168.43.1:8554/fpv_stream"));
    } else if ((source == VideoSettings::videoDisabled) || (source == VideoSettings::videoSourceNoVideo)) {
        settingsChanged |= _updateVideoUri(receiver, QString());
    } else {
        settingsChanged |= _updateVideoUri(receiver, QString());
        if (!isUvc()) {
            qCCritical(VideoManagerLog) << "Video source URI \"" << source << "\" is not supported. Please add support!";
        }
    }

    qCDebug(VideoManagerLog)
        << "VIDEO SETTINGS"
        << "receiver:" << receiver->name()
        << "thermal:" << receiver->isThermal()
        << "source:" << source
        << "rtsp:" << _videoSettings->rtspUrl()->rawValue().toString()
        << "uri:" << receiver->uri();

    return settingsChanged;
}

void VideoManager::_setActiveVehicle(Vehicle *vehicle)
{
    qCDebug(VideoManagerLog) << Q_FUNC_INFO << "new vehicle" << vehicle << "old active vehicle" << _activeVehicle;

    if (_activeVehicle) {
        (void) disconnect(_activeVehicle->vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged, this, &VideoManager::_communicationLostChanged);
        auto cameraManager = _activeVehicle->cameraManager();
        if (cameraManager) {
            MavlinkCameraControl *pCamera = cameraManager->currentCameraInstance();
            if (pCamera) {
                pCamera->stopStream();
            }
            (void) disconnect(cameraManager, &QGCCameraManager::streamChanged, this, &VideoManager::_videoSourceChanged);
        }

        for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
            // disconnect(receiver->videoStreamInfo(), &QGCVideoStreamInfo::infoChanged, ))
            receiver->setVideoStreamInfo(nullptr);
        }
    }

    _activeVehicle = vehicle;
    if (_activeVehicle) {
        (void) connect(_activeVehicle->vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged, this, &VideoManager::_communicationLostChanged);
        if (_activeVehicle->cameraManager()) {
            (void) connect(_activeVehicle->cameraManager(), &QGCCameraManager::streamChanged, this, &VideoManager::_videoSourceChanged);
            MavlinkCameraControl *pCamera = _activeVehicle->cameraManager()->currentCameraInstance();
            if (pCamera) {
                pCamera->resumeStream();
            }
        }

        for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
            if (_activeVehicle->cameraManager()) {
                if (receiver->isThermal()) {
                    receiver->setVideoStreamInfo(_activeVehicle->cameraManager()->thermalStreamInstance());
                } else {
                    receiver->setVideoStreamInfo(_activeVehicle->cameraManager()->currentStreamInstance());
                }
            } else {
                receiver->setVideoStreamInfo(nullptr);
            }
            // connect(receiver->videoStreamInfo(), &QGCVideoStreamInfo::infoChanged, ))
        }
    } else {
        setfullScreen(false);
    }
}

void VideoManager::_communicationLostChanged(bool connectionLost)
{
    if (connectionLost) {
        setfullScreen(false);
    }
}

void VideoManager::_restartAllVideos()
{
    for (VideoReceiver *videoReceiver : std::as_const(_videoReceivers)) {
        _restartVideo(videoReceiver);
    }
}

void VideoManager::_restartVideo(VideoReceiver *receiver)
{
    if (!receiver) {
        qCDebug(VideoManagerLog) << "VideoReceiver is NULL";
        return;
    }

    if (receiver->isThermal()) {
        const QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
        const bool hasRealThermalStream = pInfo && pInfo->isThermal() && !pInfo->uri().isEmpty();

        if (!hasRealThermalStream && (!_pgrZt6SubstreamEnabled || !hasPgrZt6Substream())) {
            qCDebug(VideoManagerLog) << "No active thermal/PGR substream. Thermal receiver will not restart.";
            _updateVideoUri(receiver, QString());
            _stopReceiver(receiver);
            return;
        }
    }

    qCDebug(VideoManagerLog) << "Restart video receiver" << receiver->name();

    if (receiver->started()) {
        _stopReceiver(receiver);
        // onStopComplete Signal Will Restart It
    } else {
        _startReceiver(receiver);
    }
}

void VideoManager::_restartPgrZt6SubstreamLater()
{
    if (_pgrZt6SubstreamRetryPending || !_pgrZt6SubstreamEnabled || !hasPgrZt6Substream()) {
        return;
    }

    _pgrZt6SubstreamRetryPending = true;

    QTimer::singleShot(3000, this, [this]() {
        _pgrZt6SubstreamRetryPending = false;

        if (!_pgrZt6SubstreamEnabled || !hasPgrZt6Substream() || _pgrZt6SubstreamDecoding) {
            return;
        }

        for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
            if (receiver && receiver->isThermal()) {
                qCDebug(VideoManagerLog) << "PGR ZT6 delayed substream retry" << receiver->uri();
                _updateSettings(receiver);
                _restartVideo(receiver);
            }
        }
    });
}

void VideoManager::_stopReceiver(VideoReceiver *receiver)
{
    if (!receiver) {
        qCDebug(VideoManagerLog) << "VideoReceiver is NULL";
        return;
    }

    if (receiver->started()) {
        receiver->stop();
    }
}

void VideoManager::stopVideo()
{
    for (VideoReceiver *receiver : std::as_const(_videoReceivers)) {
        _stopReceiver(receiver);
    }
}

VideoReceiver *VideoManager::_receiverByName(const QString &name) const
{
    for (VideoReceiver *receiver : _videoReceivers) {
        if (receiver && receiver->name() == name) {
            return receiver;
        }
    }

    return nullptr;
}

bool VideoManager::_isPgrSharedSourceUri(const QString &uri) const
{
    return uri.startsWith(QStringLiteral("udp://"), Qt::CaseInsensitive)
    || uri.startsWith(QStringLiteral("udp265://"), Qt::CaseInsensitive)
        || uri.startsWith(QStringLiteral("mpegts://"), Qt::CaseInsensitive);
}

VideoReceiver *VideoManager::_pgrDetachedRequestedReceiver() const
{
    return _receiverByName(
        _pgrDetachedRequestedSubStream
            ? QStringLiteral("thermalVideo")
            : QStringLiteral("videoContent"));
}

void VideoManager::_setPgrDetachedStreamDecoding(bool active)
{
    if (_pgrDetachedStreamDecoding == active) {
        return;
    }

    _pgrDetachedStreamDecoding = active;
    emit pgrDetachedStreamDecodingChanged();

    qCDebug(VideoManagerLog)
        << "Detached PGR decoding changed, active:"
        << (active ? "yes" : "no");
}

void VideoManager::_startRequestedPgrDetachedStream()
{
    if (!_pgrDetachedRequested || !_pgrDetachedVideoReceiver) {
        return;
    }

    VideoReceiver *sourceReceiver = _pgrDetachedRequestedReceiver();
    if (!sourceReceiver || sourceReceiver->uri().isEmpty()) {
        qCWarning(VideoManagerLog)
        << "Unable to start detached PGR stream: source URI unavailable"
        << (_pgrDetachedRequestedSubStream ? "SUB" : "MAIN");
        return;
    }

    const QString requestedUri = sourceReceiver->uri();
    const bool useSourceBranch = _isPgrSharedSourceUri(requestedUri);

    _pgrDetachedVideoReceiver->setLowLatency(sourceReceiver->lowLatency());

    if (_pgrDetachedUsesSourceBranch) {
        const bool sameBranch =
            _pgrDetachedSourceReceiver == sourceReceiver
            && _pgrDetachedRequestedUri == requestedUri
            && useSourceBranch;

        if (sameBranch) {
            return;
        }

        _pgrDetachedRequestedUri = requestedUri;
        _pgrDetachedRestartAfterStop = true;

        if (_pgrDetachedSourceReceiver) {
            _pgrDetachedSourceReceiver->stopDetachedDecoding();
        }
        return;
    }

    if (_pgrDetachedVideoReceiver->started()) {
        const bool sameDedicatedReceiver =
            !useSourceBranch
            && _pgrDetachedVideoReceiver->uri() == requestedUri;

        if (sameDedicatedReceiver) {
            return;
        }

        _pgrDetachedRequestedUri = requestedUri;
        _pgrDetachedRestartAfterStop = true;
        _stopReceiver(_pgrDetachedVideoReceiver);
        return;
    }

    _pgrDetachedRequestedUri = requestedUri;
    _pgrDetachedRestartAfterStop = false;
    _setPgrDetachedStreamDecoding(false);

    if (useSourceBranch && !sourceReceiver->started()) {
        qCDebug(VideoManagerLog)
        << "Waiting for source receiver before starting detached branch"
        << sourceReceiver->name()
        << requestedUri;
        return;
    }

    if (useSourceBranch) {
        _pgrDetachedUsesSourceBranch = true;
        _pgrDetachedSourceReceiver = sourceReceiver;

        qCWarning(VideoManagerLog)
            << "Start shared-source detached PGR branch"
            << (_pgrDetachedRequestedSubStream ? "SUB" : "MAIN")
            << requestedUri;

        sourceReceiver->startDetachedDecoding(
            _pgrDetachedVideoReceiver->sink(),
            _pgrDetachedVideoReceiver->widget());
        return;
    }

    _pgrDetachedVideoReceiver->setUri(requestedUri);

    qCWarning(VideoManagerLog)
        << "Start dedicated detached PGR receiver"
        << (_pgrDetachedRequestedSubStream ? "SUB" : "MAIN")
        << requestedUri;

    _startReceiver(_pgrDetachedVideoReceiver);
}

bool VideoManager::_initPgrDetachedVideoReceiver(QObject *videoItem)
{
    QQuickItem *widget = qobject_cast<QQuickItem*>(videoItem);
    if (!widget) {
        qCWarning(VideoManagerLog)
        << "Unable to initialize detached PGR receiver: invalid video item"
        << videoItem;
        return false;
    }

    if (_pgrDetachedVideoReceiver) {
        if (_pgrDetachedVideoReceiver->widget() != widget) {
            qCWarning(VideoManagerLog)
            << "Detached PGR video item changed unexpectedly";
            return false;
        }
        return true;
    }

    VideoReceiver *receiver =
        QGCCorePlugin::instance()->createVideoReceiver(this);
    if (!receiver) {
        qCCritical(VideoManagerLog)
        << "Unable to create detached PGR video receiver";
        return false;
    }

    receiver->setName(QStringLiteral("detachedVideo"));
    receiver->setWidget(widget);

    void *sink =
        QGCCorePlugin::instance()->createVideoSink(widget, receiver);
    if (!sink) {
        qCCritical(VideoManagerLog)
        << "Unable to create detached PGR video sink";
        receiver->deleteLater();
        return false;
    }

    receiver->setSink(sink);
    _pgrDetachedVideoReceiver = receiver;

    (void) connect(
        receiver,
        &VideoReceiver::onStartComplete,
        this,
        [this, receiver](VideoReceiver::STATUS status) {
            qCDebug(VideoManagerLog)
            << "Detached PGR receiver start complete, status:" << status;

            if (status != VideoReceiver::STATUS_OK) {
                receiver->setStarted(false);
                _setPgrDetachedStreamDecoding(false);
                return;
            }

            receiver->setStarted(true);
            receiver->startDecoding(receiver->sink());
        }
        );

    (void) connect(
        receiver,
        &VideoReceiver::onStopComplete,
        this,
        [this, receiver](VideoReceiver::STATUS status) {
            qCDebug(VideoManagerLog)
            << "Detached PGR receiver stop complete, status:" << status;

            receiver->setStarted(false);
            _setPgrDetachedStreamDecoding(false);

            if (_pgrDetachedRestartAfterStop && _pgrDetachedRequested) {
                _pgrDetachedRestartAfterStop = false;
                QTimer::singleShot(0, this, [this]() {
                    _startRequestedPgrDetachedStream();
                });
            }
        }
        );

    (void) connect(
        receiver,
        &VideoReceiver::decodingChanged,
        this,
        [this](bool active) {
            if (_pgrDetachedUsesSourceBranch) {
                return;
            }

            _setPgrDetachedStreamDecoding(active);
        }
        );

    (void) connect(
        receiver,
        &VideoReceiver::timeout,
        this,
        [this, receiver]() {
            qCWarning(VideoManagerLog)
            << "Detached PGR receiver timeout" << receiver->uri();
            _pgrDetachedRestartAfterStop = false;
            _stopReceiver(receiver);
        }
        );

    return true;
}

void VideoManager::startPgrDetachedStream(
    bool subStream,
    QObject *videoItem)
{
    if (!_initPgrDetachedVideoReceiver(videoItem)) {
        return;
    }

    _pgrDetachedRequested = true;
    _pgrDetachedRequestedSubStream = subStream;

    _startRequestedPgrDetachedStream();
}

void VideoManager::stopPgrDetachedStream()
{
    _pgrDetachedRequested = false;
    _pgrDetachedRestartAfterStop = false;
    _pgrDetachedRequestedUri.clear();

    if (_pgrDetachedUsesSourceBranch && _pgrDetachedSourceReceiver) {
        qCWarning(VideoManagerLog)
        << "Stop shared-source detached PGR branch"
        << _pgrDetachedSourceReceiver->uri();

        _pgrDetachedSourceReceiver->stopDetachedDecoding();
        return;
    }

    if (_pgrDetachedVideoReceiver && _pgrDetachedVideoReceiver->started()) {
        qCWarning(VideoManagerLog)
        << "Stop dedicated detached PGR receiver"
        << _pgrDetachedVideoReceiver->uri();

        _stopReceiver(_pgrDetachedVideoReceiver);
        return;
    }

    _setPgrDetachedStreamDecoding(false);
}


void VideoManager::_startReceiver(VideoReceiver *receiver)
{
    if (!receiver) {
        qCDebug(VideoManagerLog) << "VideoReceiver is NULL";
        return;
    }

    if (receiver->started()) {
        qCDebug(VideoManagerLog) << "VideoReceiver is already started" << receiver->name();
        return;
    }

    if (receiver->isThermal()) {
        const QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
        const bool hasRealThermalStream = pInfo && pInfo->isThermal() && !pInfo->uri().isEmpty();

        if (!hasRealThermalStream && (!_pgrZt6SubstreamEnabled || !hasPgrZt6Substream())) {
            qCDebug(VideoManagerLog) << "No active thermal/PGR substream. Thermal receiver will not start.";
            return;
        }
    }

    if (receiver->uri().isEmpty()) {
        qCDebug(VideoManagerLog) << "VideoUri is NULL" << receiver->name();
        return;
    }

    const QString source = _videoSettings->videoSource()->rawValue().toString();
    /* The gstreamer rtsp source will switch to tcp if udp is not available after 5 seconds.
       So we should allow for some negotiation time for rtsp */

    const bool receiverUsesRtsp = receiver->uri().startsWith(QStringLiteral("rtsp://"), Qt::CaseInsensitive);
    const uint32_t timeout = ((source == VideoSettings::videoSourceRTSP || receiverUsesRtsp) ? _videoSettings->rtspTimeout()->rawValue().toUInt() : 3);

    qCWarning(VideoManagerLog)
        << "VIDEO START"
        << "receiver:" << receiver->name()
        << "thermal:" << receiver->isThermal()
        << "uri:" << receiver->uri()
        << "widget:" << receiver->widget()
        << "sink:" << receiver->sink()
        << "timeout:" << timeout;

    receiver->start(timeout);
}

void VideoManager::_initVideoReceiver(VideoReceiver *receiver, QQuickWindow *window)
{
    if (_videoReceivers.contains(receiver)) {
        qCWarning(VideoManagerLog) << "Receiver already initialized";
    }

    QQuickItem *widget = window->findChild<QQuickItem*>(receiver->name());
    if (!widget) {
        qCCritical(VideoManagerLog) << "stream widget not found" << receiver->name();
        return;
    }
    receiver->setWidget(widget);

    void *sink = QGCCorePlugin::instance()->createVideoSink(receiver->widget(), receiver);
    if (!sink) {
        qCCritical(VideoManagerLog) << "createVideoSink() failed" << receiver->name();
        return;
    }
    receiver->setSink(sink);

    (void) connect(receiver, &VideoReceiver::onStartComplete, this, [this, receiver](VideoReceiver::STATUS status) {
        if (!receiver) {
            return;
        }

        qCDebug(VideoManagerLog) << "Video" << receiver->name() << "Start complete, status:" << status;
        switch (status) {
            case VideoReceiver::STATUS_OK:
                receiver->setStarted(true);
                if (receiver->sink()) {
                    receiver->startDecoding(receiver->sink());
                }

                if (_pgrDetachedRequested
                    && _pgrDetachedRequestedReceiver() == receiver) {
                    QTimer::singleShot(0, this, [this]() {
                        _startRequestedPgrDetachedStream();
                    });
                }
                break;
            case VideoReceiver::STATUS_INVALID_URL:
            case VideoReceiver::STATUS_INVALID_STATE:
                break;
            default:
                _restartVideo(receiver);
                break;
        }
    });

    (void) connect(receiver, &VideoReceiver::onStopComplete, this, [this, receiver](VideoReceiver::STATUS status) {
        qCDebug(VideoManagerLog) << "Stop complete" << receiver->name() << receiver->uri()  << ", status:" << status;
        receiver->setStarted(false);

        if (_pgrDetachedUsesSourceBranch
            && _pgrDetachedSourceReceiver == receiver) {
            _pgrDetachedUsesSourceBranch = false;
            _pgrDetachedSourceReceiver = nullptr;
            _setPgrDetachedStreamDecoding(false);
        }

        if (status == VideoReceiver::STATUS_INVALID_URL) {
            qCDebug(VideoManagerLog) << "Invalid video URL. Not restarting";
            return;
        }

        if (receiver->isThermal()) {
            const QGCVideoStreamInfo *pInfo = receiver->videoStreamInfo();
            const bool hasRealThermalStream = pInfo && pInfo->isThermal() && !pInfo->uri().isEmpty();

            if (!hasRealThermalStream && (!_pgrZt6SubstreamEnabled || !hasPgrZt6Substream() || receiver->uri().isEmpty())) {
                qCDebug(VideoManagerLog) << "No active thermal/PGR substream. Not restarting thermal receiver.";
                return;
            }
        }

        QTimer::singleShot(1000, receiver, [this, receiver]() {
            qCDebug(VideoManagerLog) << "Restarting video receiver" << receiver->name() << receiver->uri();
            _startReceiver(receiver);
        });
    });

    (void) connect(receiver, &VideoReceiver::streamingChanged, this, [this, receiver](bool active) {
        qCDebug(VideoManagerLog) << "Video" << receiver->name() << "streaming changed, active:" << (active ? "yes" : "no");
        if (!receiver->isThermal()) {
            _streaming = active;
            emit streamingChanged();
        }
    });

    (void) connect(receiver, &VideoReceiver::decodingChanged, this, [this, receiver](bool active) {
        qCDebug(VideoManagerLog) << "Video" << receiver->name() << "decoding changed, active:" << (active ? "yes" : "no");
        if (!receiver->isThermal()) {
            _decoding = active;
            emit decodingChanged();

            if (active && _pgrZt6SubstreamEnabled && hasPgrZt6Substream()) {
                _restartPgrZt6SubstreamLater();
            }
        } else {
            if (_pgrZt6SubstreamDecoding != active) {
                _pgrZt6SubstreamDecoding = active;
                emit pgrZt6SubstreamDecodingChanged();
            }
        }


    });

    (void) connect(
        receiver,
        &VideoReceiver::detachedDecodingChanged,
        this,
        [this, receiver](bool active) {
            if (_pgrDetachedUsesSourceBranch
                && _pgrDetachedSourceReceiver == receiver) {
                _setPgrDetachedStreamDecoding(active);
            }
        });

    (void) connect(
        receiver,
        &VideoReceiver::onStartDetachedDecodingComplete,
        this,
        [this, receiver](VideoReceiver::STATUS status) {
            if (!_pgrDetachedUsesSourceBranch
                || _pgrDetachedSourceReceiver != receiver) {
                return;
            }

            qCDebug(VideoManagerLog)
                << "Shared-source detached decoding start complete"
                << receiver->name()
                << status;

            if (status != VideoReceiver::STATUS_OK) {
                _pgrDetachedUsesSourceBranch = false;
                _pgrDetachedSourceReceiver = nullptr;
                _setPgrDetachedStreamDecoding(false);
            }
        });

    (void) connect(
        receiver,
        &VideoReceiver::onStopDetachedDecodingComplete,
        this,
        [this, receiver](VideoReceiver::STATUS status) {
            if (_pgrDetachedSourceReceiver != receiver) {
                return;
            }

            qCDebug(VideoManagerLog)
                << "Shared-source detached decoding stop complete"
                << receiver->name()
                << status;

            _pgrDetachedUsesSourceBranch = false;
            _pgrDetachedSourceReceiver = nullptr;
            _setPgrDetachedStreamDecoding(false);

            if (_pgrDetachedRestartAfterStop && _pgrDetachedRequested) {
                _pgrDetachedRestartAfterStop = false;
                QTimer::singleShot(0, this, [this]() {
                    _startRequestedPgrDetachedStream();
                });
            }
        });

    (void) connect(receiver, &VideoReceiver::recordingChanged, this, [this, receiver](bool active) {
        qCDebug(VideoManagerLog) << "Video" << receiver->name() << "recording changed, active:" << (active ? "yes" : "no");
        if (!receiver->isThermal()) {
            _recording = active;
            if (!active) {
                _subtitleWriter->stopCapturingTelemetry();
            }
            emit recordingChanged();
        }
    });

    (void) connect(receiver, &VideoReceiver::recordingStarted, this, [this, receiver](const QString &filename) {
        qCDebug(VideoManagerLog) << "Video" << receiver->name() << "recording started";
        if (!receiver->isThermal()) {
            _subtitleWriter->startCapturingTelemetry(filename, videoSize());
        }
    });

    (void) connect(receiver, &VideoReceiver::videoSizeChanged, this, [this, receiver](QSize size) {
        qCDebug(VideoManagerLog) << "Video" << receiver->name() << "resized. New resolution:" << size.width() << "x" << size.height();
        if (!receiver->isThermal()) {
            _videoSize = size;
            emit videoSizeChanged();
        }
    });

    (void) connect(receiver, &VideoReceiver::onTakeScreenshotComplete, this, [receiver](VideoReceiver::STATUS status) {
        if (status == VideoReceiver::STATUS_OK) {
            qCDebug(VideoManagerLog) << "Video" << receiver->name() << "screenshot taken";
        } else {
            qCWarning(VideoManagerLog) << "Video" << receiver->name() << "screenshot failed";
        }
    });

    (void) connect(receiver, &VideoReceiver::videoStreamInfoChanged, this, [this, receiver]() {
        const QGCVideoStreamInfo *videoStreamInfo = receiver->videoStreamInfo();
        qCDebug(VideoManagerLog) << "Video" << receiver->name() << "stream info:" << (videoStreamInfo ? "received" : "lost");

        (void) _updateAutoStream(receiver);
    });

    (void) _updateSettings(receiver);

    _videoReceivers.append(receiver);

    if (hasVideo()) {
        _startReceiver(receiver);
    }
}

void VideoManager::startVideo()
{
    if (!hasVideo()) {
        qCDebug(VideoManagerLog) << "Stream not enabled/configured";
        return;
    }

    _restartAllVideos();
}

/*===========================================================================*/

FinishVideoInitialization::FinishVideoInitialization()
    : QRunnable()
{
   // qCDebug(VideoManagerLog) << this;
}

FinishVideoInitialization::~FinishVideoInitialization()
{
   // qCDebug(VideoManagerLog) << this;
}

void FinishVideoInitialization::run()
{
    VideoManager::instance()->startVideo();
}