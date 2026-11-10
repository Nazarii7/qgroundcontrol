#include "widgetpanelcontroller.h"

#include <QTimer>
#include <QtQml/qqml.h>

#include <algorithm>
#include <cmath>

namespace {
bool finitePoint(const QPointF& point)
{
    return std::isfinite(point.x()) && std::isfinite(point.y());
}
}

WidgetPanelController::WidgetPanelController(QObject* parent)
    : QObject(parent)
{
}

void WidgetPanelController::registerQmlType()
{
    static const int typeId = qmlRegisterType<WidgetPanelController>(
        "QGroundControl.FlightDisplay", 1, 0, "WidgetPanelController");
    Q_UNUSED(typeId)
}

void WidgetPanelController::setBounds(const QRectF& value)
{
    if (_bounds == value) {
        return;
    }
    _bounds = value;
    emit geometryChanged();
    scheduleGeometryUpdate();
}

void WidgetPanelController::setPanelSize(const QSizeF& value)
{
    if (_panelSize == value) {
        return;
    }
    _panelSize = value;
    emit geometryChanged();
    scheduleGeometryUpdate();
}

void WidgetPanelController::setDefaultPosition(const QPointF& value)
{
    if (_defaultPosition == value) {
        return;
    }
    _defaultPosition = value;
    emit geometryChanged();
    scheduleGeometryUpdate();
}

void WidgetPanelController::setSavedPosition(const QPointF& value)
{
    if (_savedPosition == value) {
        return;
    }
    _savedPosition = value;
    emit geometryChanged();
    scheduleGeometryUpdate();
}

void WidgetPanelController::setUseSavedPosition(bool value)
{
    if (_useSavedPosition == value) {
        return;
    }
    _useSavedPosition = value;
    emit geometryChanged();
    scheduleGeometryUpdate();
}

void WidgetPanelController::setFollowDefault(bool value)
{
    if (_followDefault == value) {
        return;
    }
    _followDefault = value;
    emit geometryChanged();
    scheduleGeometryUpdate();
}

void WidgetPanelController::setEnabled(bool value)
{
    if (_enabled == value) {
        return;
    }
    _enabled = value;
    if (!_enabled) {
        finishDrag();
    }
    emit enabledChanged();
    scheduleGeometryUpdate();
}

void WidgetPanelController::setLocked(bool value)
{
    if (_locked == value) {
        return;
    }
    _locked = value;
    if (_locked) {
        finishDrag();
    }
    emit lockedChanged();
}

void WidgetPanelController::setPanelX(qreal value)
{
    setPosition(value, panelY());
}

void WidgetPanelController::setPanelY(qreal value)
{
    setPosition(panelX(), value);
}

bool WidgetPanelController::hasValidGeometry() const
{
    return _enabled && finitePoint(_bounds.topLeft())
    && std::isfinite(_bounds.width()) && std::isfinite(_bounds.height())
        && _bounds.width() >= 0 && _bounds.height() >= 0
        && std::isfinite(_panelSize.width()) && std::isfinite(_panelSize.height())
        && _panelSize.width() > 0 && _panelSize.height() > 0;
}

QPointF WidgetPanelController::boundedPosition(qreal x, qreal y) const
{
    if (!hasValidGeometry() || !std::isfinite(x) || !std::isfinite(y)) {
        return _position;
    }
    const qreal maxX = std::max(_bounds.left(), _bounds.right() - _panelSize.width());
    const qreal maxY = std::max(_bounds.top(), _bounds.bottom() - _panelSize.height());
    return QPointF(std::clamp(x, _bounds.left(), maxX),
                   std::clamp(y, _bounds.top(), maxY));
}

void WidgetPanelController::applyPosition(const QPointF& position)
{
    if (!hasValidGeometry() || !finitePoint(position)) {
        return;
    }
    const QPointF bounded = boundedPosition(position.x(), position.y());
    if (_position != bounded) {
        _position = bounded;
        emit positionChanged();
    }
    if (!_ready) {
        _ready = true;
        emit readyChanged();
    }
}

void WidgetPanelController::setPosition(qreal x, qreal y)
{
    applyPosition(QPointF(x, y));
}

void WidgetPanelController::scheduleGeometryUpdate()
{
    if (_geometryUpdatePending) {
        return;
    }
    _geometryUpdatePending = true;
    // Coalesce QML layout updates so width, height and saved coordinates settle
    // before clamping. Auto-layout changes never write persistent positions.
    QTimer::singleShot(0, this, [this]() {
        _geometryUpdatePending = false;
        updateGeometry();
    });
}

void WidgetPanelController::updateGeometry()
{
    if (_dragging || !hasValidGeometry()) {
        return;
    }
    if (!_manuallyPositioned && _useSavedPosition
        && finitePoint(_savedPosition) && _savedPosition.x() >= 0 && _savedPosition.y() >= 0) {
        applyPosition(_savedPosition);
    } else if (!_ready || (_followDefault && !_manuallyPositioned)) {
        applyPosition(_defaultPosition);
    } else {
        keepInBounds();
    }
}

void WidgetPanelController::initializePosition()
{
    updateGeometry();
}

void WidgetPanelController::refreshDefaultPosition()
{
    if (_followDefault && !_manuallyPositioned) {
        updateGeometry();
    }
}

void WidgetPanelController::keepInBounds()
{
    if (_ready && !_dragging) {
        applyPosition(_position);
    }
}

bool WidgetPanelController::beginDrag(qreal pointerX, qreal pointerY)
{
    if (_locked || _dragging || !_ready || !hasValidGeometry()
        || !std::isfinite(pointerX) || !std::isfinite(pointerY)) {
        return false;
    }
    _dragStartPointer = QPointF(pointerX, pointerY);
    _dragStartPosition = _position;
    if (!_manuallyPositioned) {
        _manuallyPositioned = true;
        emit manuallyPositionedChanged();
    }
    _dragging = true;
    emit draggingChanged();
    return true;
}

void WidgetPanelController::dragTo(qreal pointerX, qreal pointerY)
{
    if (!_dragging || !std::isfinite(pointerX) || !std::isfinite(pointerY)) {
        return;
    }
    applyPosition(_dragStartPosition + QPointF(pointerX, pointerY) - _dragStartPointer);
}

void WidgetPanelController::endDrag(qreal pointerX, qreal pointerY)
{
    if (!_dragging) {
        return;
    }
    dragTo(pointerX, pointerY);
    finishDrag();
}

void WidgetPanelController::finishDrag()
{
    if (!_dragging) {
        return;
    }
    _dragging = false;
    emit draggingChanged();
    keepInBounds();
    emit positionCommitted(panelX(), panelY());
}

void WidgetPanelController::cancelDrag()
{
    // Match release: keep the last bounded position and commit exactly once.
    finishDrag();
}
