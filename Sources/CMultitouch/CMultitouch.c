#include "CMultitouch.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdbool.h>

// MultitouchSupport is private, so it's loaded at runtime. These types match its per-touch
// struct (96 bytes); only `identifier` and `normalized` are read.
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;
typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state;
    int32_t fingerID;
    int32_t handID;
    MTVector normalized;
    float size;
    int32_t unused1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absolute;
    int32_t unused2[2];
    float density;
} MTTouch;

typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef, const MTTouch *, int32_t, double, int32_t);

static CFArrayRef (*pCreateList)(void);
static void (*pRegister)(MTDeviceRef, MTContactCallback);
static void (*pUnregister)(MTDeviceRef, MTContactCallback);
static void (*pStart)(MTDeviceRef, int32_t);
static void (*pStop)(MTDeviceRef);

static CFArrayRef gDevices;
static MTFrameHandler gHandler;

enum { kMaxTouches = 16 };

static bool loadFramework(void) {
    if (pCreateList) return true;

    void *lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!lib) return false;

    void *createList = dlsym(lib, "MTDeviceCreateList");
    void *registerCallback = dlsym(lib, "MTRegisterContactFrameCallback");
    void *unregisterCallback = dlsym(lib, "MTUnregisterContactFrameCallback");
    void *start = dlsym(lib, "MTDeviceStart");
    void *stop = dlsym(lib, "MTDeviceStop");
    if (!createList || !registerCallback || !unregisterCallback || !start || !stop) return false;

    pRegister = registerCallback;
    pUnregister = unregisterCallback;
    pStart = start;
    pStop = stop;
    pCreateList = createList;
    return true;
}

static int contactCallback(MTDeviceRef device, const MTTouch *touches, int32_t count, double timestamp, int32_t frame) {
    MTFrameHandler handler = gHandler;
    if (!handler) return 0;

    MTTouchPoint points[kMaxTouches];
    int32_t n = count < kMaxTouches ? count : kMaxTouches;
    for (int32_t i = 0; i < n; i++) {
        points[i].identifier = touches[i].identifier;
        points[i].x = touches[i].normalized.position.x;
        points[i].y = touches[i].normalized.position.y;
    }
    handler((uintptr_t)device, points, n, timestamp);
    return 0;
}

int32_t MTListenerStart(MTFrameHandler handler) {
    if (!loadFramework()) return -1;

    MTListenerStop();
    gHandler = handler;
    gDevices = pCreateList();
    if (!gDevices) return 0;

    CFIndex count = CFArrayGetCount(gDevices);
    for (CFIndex i = 0; i < count; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(gDevices, i);
        pRegister(device, contactCallback);
        pStart(device, 0);
    }
    return (int32_t)count;
}

void MTListenerStop(void) {
    if (!gDevices) return;

    CFIndex count = CFArrayGetCount(gDevices);
    for (CFIndex i = 0; i < count; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(gDevices, i);
        pUnregister(device, contactCallback);
        pStop(device);
    }
    CFRelease(gDevices);
    gDevices = NULL;
}
