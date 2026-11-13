#pragma once

#include "QGCMAVLink.h"

#include <cmath>
#include <cstring>
#include <limits>

namespace NavigationMavlink {

// Vehicle::mavlinkMessageReceived is AFTER APMFirmwarePlugin converts ArduPilot
// C-cast parameters to QGC's bytewise representation. Do not read param_value
// directly as a float for integer parameters, or GPS_PRIMARY=1 becomes ~1e-45.
inline double parameterValue(const mavlink_param_value_t &value)
{
    mavlink_param_union_t raw{};
    raw.param_float = value.param_value;
    switch (value.param_type) {
    case MAV_PARAM_TYPE_UINT8:  return raw.param_uint8;
    case MAV_PARAM_TYPE_INT8:   return raw.param_int8;
    case MAV_PARAM_TYPE_UINT16: return raw.param_uint16;
    case MAV_PARAM_TYPE_INT16:  return raw.param_int16;
    case MAV_PARAM_TYPE_UINT32: return raw.param_uint32;
    case MAV_PARAM_TYPE_INT32:  return raw.param_int32;
    case MAV_PARAM_TYPE_REAL32:return raw.param_float;
    default: return std::numeric_limits<double>::quiet_NaN();
    }
}

inline mavlink_message_t rc5Override(uint8_t senderSystem, uint8_t senderComponent,
                                    uint8_t channel, uint8_t targetSystem,
                                    uint8_t targetComponent, uint16_t pwm)
{
    constexpr uint16_t Ignore = std::numeric_limits<uint16_t>::max();
    mavlink_message_t message{};
    mavlink_msg_rc_channels_override_pack_chan(
        senderSystem, senderComponent, channel, &message, targetSystem, targetComponent,
        Ignore, Ignore, Ignore, Ignore, pwm, Ignore, Ignore, Ignore,
        Ignore, Ignore, Ignore, Ignore, Ignore, Ignore, Ignore, Ignore, Ignore, Ignore);
    return message;
}

inline mavlink_message_t parameterRead(uint8_t senderSystem, uint8_t senderComponent,
                                      uint8_t channel, uint8_t targetSystem,
                                      uint8_t targetComponent, const char *name)
{
    char parameterId[16]{};
    std::strncpy(parameterId, name, sizeof(parameterId) - 1);
    mavlink_message_t message{};
    mavlink_msg_param_request_read_pack_chan(senderSystem, senderComponent, channel,
        &message, targetSystem, targetComponent, parameterId, -1);
    return message;
}
}
