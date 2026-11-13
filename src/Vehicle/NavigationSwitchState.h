#pragma once

#include <cstdint>

// Transport-independent state for a maintained GPS/VisNav switch. Time is
// monotonic milliseconds. A stable live level may synchronize a disarmed
// vehicle; reconnecting to an armed vehicle still requires a physical edge.
class NavigationSwitchState
{
public:
    static constexpr int Unknown = -1;
    static constexpr std::int64_t SampleTimeoutMs = 500;
    static constexpr std::int64_t ConfirmationTimeoutMs = 2500;
    static constexpr std::int64_t InitialStableMs = 300;

    void observeSource(int source, std::int64_t now)
    {
        _source = source == 0 || source == 1 ? source : Unknown;
        _sourceAt = now;
    }

    void resetControl()
    {
        _button = Unknown;
        _level = Unknown;
        _requested = Unknown;
        _sampleAt = -1;
        _requestAt = -1;
        _initialAt = -1;
        _initialSamples = 0;
        _initialSyncAllowed = false;
        _initialRequest = false;
    }

    void resetSession()
    {
        resetControl();
        _source = Unknown;
        _sourceAt = -1;
    }

    void sample(int button, bool pressed, std::int64_t sampledAt,
                std::int64_t now, bool eligible, bool allowInitialSync = false)
    {
        // Reject old queued samples, including ones queued before a link loss.
        if (!eligible || button < 0 || sampledAt > now || now - sampledAt > SampleTimeoutMs) {
            resetControl();
            return;
        }
        if (_sampleAt >= 0 && sampledAt <= _sampleAt) {
            return;
        }
        if (_sampleAt >= 0 && sampledAt - _sampleAt > SampleTimeoutMs) {
            resetControl();
        }
        const int level = pressed ? 1 : 0;
        _sampleAt = sampledAt;
        if (_button != button || _level == Unknown) {
            _button = button;
            _level = level;
            _requested = Unknown;
            _initialAt = sampledAt;
            _initialSamples = 1;
            _initialSyncAllowed = allowInitialSync;
            _initialRequest = false;
            return;
        }
        // Arming during the initial observation cancels automatic takeover.
        // Disarming later does not re-enable it without a new live baseline.
        if (!allowInitialSync) {
            _initialSyncAllowed = false;
        }
        if (_requested == Unknown && _initialSyncAllowed) {
            if (_level != level) {
                _level = level;
                _initialAt = sampledAt;
                _initialSamples = 1;
            } else {
                ++_initialSamples;
            }
            if (_initialSamples >= 3 && sampledAt - _initialAt >= InitialStableMs) {
                _requested = level;
                _requestAt = now;
                _initialSyncAllowed = false;
                _initialRequest = true;
            }
            return;
        }
        if (_level != level) {
            _level = level;
            _requested = level;
            _requestAt = now;
            _initialRequest = false;
        }
    }

    // -1: no ownership; 988/2011: maintain only RC5. Never choose a source from
    // a satellite count, an unvalidated initial button value, or an old request.
    int command(std::int64_t now, bool eligible)
    {
        if (!eligible || _sampleAt < 0 || now - _sampleAt > SampleTimeoutMs) {
            resetControl();
            return Unknown;
        }
        return _requested == Unknown ? Unknown : (_requested == 1 ? 2011 : 988);
    }

    int source() const { return _source; }
    int requested() const { return _requested; }
    bool hasSample() const { return _level != Unknown; }
    bool awaitingInitialSync() const { return _requested == Unknown && _initialSyncAllowed; }
    bool initialSynchronization() const { return awaitingInitialSync() || (_initialRequest && pending()); }
    bool pending() const
    {
        return _requested != Unknown && (_source != _requested || _sourceAt < _requestAt);
    }
    bool confirmationTimedOut(std::int64_t now) const
    {
        return pending() && now - _requestAt >= ConfirmationTimeoutMs;
    }

private:
    int _source = Unknown;
    int _requested = Unknown;
    int _button = Unknown;
    int _level = Unknown;
    std::int64_t _sampleAt = -1;
    std::int64_t _sourceAt = -1;
    std::int64_t _requestAt = -1;
    std::int64_t _initialAt = -1;
    int _initialSamples = 0;
    bool _initialSyncAllowed = false;
    bool _initialRequest = false;
};
