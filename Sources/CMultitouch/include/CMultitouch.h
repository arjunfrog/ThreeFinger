#pragma once

#include <stdint.h>

/// One finger on the trackpad. x and y are normalized to 0...1, origin at the bottom-left.
typedef struct {
    int32_t identifier;
    float x;
    float y;
} MTTouchPoint;

typedef void (*MTFrameHandler)(uintptr_t device, const MTTouchPoint *touches, int32_t count, double timestamp);

/// Starts delivering touch frames from every multitouch device to `handler`, on a background thread.
/// Calling it again restarts with the current set of devices.
/// Returns the number of devices, or -1 if the system framework can't be loaded.
int32_t MTListenerStart(MTFrameHandler handler);

void MTListenerStop(void);

/// The height of a device's touch surface in millimetres, or 0 if it isn't known.
float MTListenerDeviceHeight(uintptr_t device);
