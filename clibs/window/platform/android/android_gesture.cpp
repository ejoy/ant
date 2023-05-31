#include "android_gesture.h"

#include <jni.h>
#include "game-activity/native_app_glue/android_native_app_glue.h"
#include "game-activity/GameActivity.h"
#include "../../window.h"
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <stdlib.h>
#include <cassert>

static_assert(sizeof(struct ant_gesture) < PIPE_BUF);

extern struct ant_window_callback* g_cb;

void android_gesture::queue_push(struct ant_gesture const& gesture) {
    int r;
    do
        r = write(pipe_write, &gesture, sizeof(gesture));
    while (r == -1 && errno == EINTR);
    assert(r == sizeof(gesture));
}

bool android_gesture::queue_pop(struct ant_gesture& gesture) {
    int r = read(pipe_read, &gesture, sizeof(gesture));
    if (r == sizeof(gesture)) return true;
    assert(r <= 0);
    return false;
}

void android_gesture::queue_process() {
    for (;;) {
        struct ant_gesture gesture;
        if (!queue_pop(gesture)) {
            break;
        }
        window_message_gesture(g_cb, gesture);
    }
}

int android_gesture::queue_callback(int fd, int events, void *data) {
    ((android_gesture*)data)->queue_process();
    return 1;
}

void android_gesture::initialize(android_app* app) {
    int sv[2];
    const int ok = ::pipe2(sv, O_CLOEXEC | O_NONBLOCK);
    if (ok < 0) {
        abort();
        return;
    }
    pipe_read = sv[0];
    pipe_write = sv[1];
    ALooper_addFd(app->looper, pipe_read, LOOPER_ID_USER, ALOOPER_EVENT_INPUT, queue_callback, this);
}
void android_gesture::destroy(android_app* app) {
    close(pipe_read);
    close(pipe_write);
    pipe_read = -1;
    pipe_write = -1;
}
void android_gesture::onTap(android_app* app, float x, float y) {
    struct ant_gesture gesture;
    gesture.type = GESTURE_TAP;
    gesture.tap.x = x;
    gesture.tap.y = y;
    queue_push(gesture);
}
void android_gesture::onLongPress(android_app* app, float x, float y) {
    struct ant_gesture gesture;
    gesture.type = GESTURE_LONGPRESS;
    gesture.longpress.x = x;
    gesture.longpress.y = y;
    queue_push(gesture);

}
void android_gesture::onPan(android_app* app, float x, float y, float dx, float dy, float vx, float vy) {
    struct ant_gesture gesture;
    gesture.type = GESTURE_PAN;
    gesture.pan.x = x;
    gesture.pan.y = y;
    gesture.pan.dx = dx;
    gesture.pan.dy = dy;
    gesture.pan.vx = vx;
    gesture.pan.vy = vy;
    queue_push(gesture);
}
void android_gesture::onPinch(android_app* app, int state, float x, float y, float velocity) {
    struct ant_gesture gesture;
    gesture.type = GESTURE_PINCH;
    gesture.pinch.state = state;
    gesture.pinch.x = x;
    gesture.pinch.y = y;
    gesture.pinch.velocity = velocity;
    queue_push(gesture);
}

