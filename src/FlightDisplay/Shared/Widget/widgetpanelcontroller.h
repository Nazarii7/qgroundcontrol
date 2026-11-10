#pragma once

#include <QObject>
#include <QPointF>
#include <QRectF>
#include <QSizeF>

// Presentation state only. This class never sends vehicle or joystick commands.
class WidgetPanelController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QRectF bounds READ bounds WRITE setBounds NOTIFY geometryChanged)
    Q_PROPERTY(QSizeF panelSize READ panelSize WRITE setPanelSize NOTIFY geometryChanged)
    Q_PROPERTY(QPointF defaultPosition READ defaultPosition WRITE setDefaultPosition NOTIFY geometryChanged)
    Q_PROPERTY(QPointF savedPosition READ savedPosition WRITE setSavedPosition NOTIFY geometryChanged)
    Q_PROPERTY(bool useSavedPosition READ useSavedPosition WRITE setUseSavedPosition NOTIFY geometryChanged)
    Q_PROPERTY(bool followDefault READ followDefault WRITE setFollowDefault NOTIFY geometryChanged)
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool locked READ isLocked WRITE setLocked NOTIFY lockedChanged)
    Q_PROPERTY(qreal panelX READ panelX WRITE setPanelX NOTIFY positionChanged)
    Q_PROPERTY(qreal panelY READ panelY WRITE setPanelY NOTIFY positionChanged)
    Q_PROPERTY(bool ready READ isReady NOTIFY readyChanged)
    Q_PROPERTY(bool dragging READ isDragging NOTIFY draggingChanged)
    Q_PROPERTY(bool manuallyPositioned READ isManuallyPositioned NOTIFY manuallyPositionedChanged)

   public:
    explicit WidgetPanelController(QObject* parent = nullptr);
    static void registerQmlType();

    QRectF bounds() const { return _bounds; }
    QSizeF panelSize() const { return _panelSize; }
    QPointF defaultPosition() const { return _defaultPosition; }
    QPointF savedPosition() const { return _savedPosition; }
    bool useSavedPosition() const { return _useSavedPosition; }
    bool followDefault() const { return _followDefault; }
    bool isEnabled() const { return _enabled; }
    bool isLocked() const { return _locked; }
    qreal panelX() const { return _position.x(); }
    qreal panelY() const { return _position.y(); }
    bool isReady() const { return _ready; }
    bool isDragging() const { return _dragging; }
    bool isManuallyPositioned() const { return _manuallyPositioned; }

    void setBounds(const QRectF& value);
    void setPanelSize(const QSizeF& value);
    void setDefaultPosition(const QPointF& value);
    void setSavedPosition(const QPointF& value);
    void setUseSavedPosition(bool value);
    void setFollowDefault(bool value);
    void setEnabled(bool value);
    void setLocked(bool value);
    void setPanelX(qreal value);
    void setPanelY(qreal value);

    Q_INVOKABLE QPointF boundedPosition(qreal x, qreal y) const;
    Q_INVOKABLE void setPosition(qreal x, qreal y);
    Q_INVOKABLE void initializePosition();
    Q_INVOKABLE void refreshDefaultPosition();
    Q_INVOKABLE void keepInBounds();
    Q_INVOKABLE bool beginDrag(qreal pointerX, qreal pointerY);
    Q_INVOKABLE void dragTo(qreal pointerX, qreal pointerY);
    Q_INVOKABLE void endDrag(qreal pointerX, qreal pointerY);
    Q_INVOKABLE void cancelDrag();

   signals:
    void geometryChanged();
    void enabledChanged();
    void lockedChanged();
    void positionChanged();
    void readyChanged();
    void draggingChanged();
    void manuallyPositionedChanged();
    void positionCommitted(qreal x, qreal y);

   private:
    bool hasValidGeometry() const;
    void scheduleGeometryUpdate();
    void updateGeometry();
    void applyPosition(const QPointF& position);
    void finishDrag();

    QRectF _bounds;
    QSizeF _panelSize;
    QPointF _defaultPosition;
    QPointF _savedPosition = QPointF(-1, -1);
    QPointF _position = QPointF(-1, -1);
    QPointF _dragStartPointer;
    QPointF _dragStartPosition;
    bool _useSavedPosition = false;
    bool _followDefault = false;
    bool _enabled = true;
    bool _locked = true;
    bool _ready = false;
    bool _dragging = false;
    bool _manuallyPositioned = false;
    bool _geometryUpdatePending = false;
};
