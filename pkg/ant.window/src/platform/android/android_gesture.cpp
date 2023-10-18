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

static_assert(sizeof(struct ant::window::msg) < PIPE_BUF);

extern struct ant_window_callback* g_cb;

void android_gesture::queue_push(struct ant::window::msg const& msg) {
    int r;
    do
        r = write(pipe_write, &msg, sizeof(msg));
    while (r == -1 && errno == EINTR);
    assert(r == sizeof(msg));
}

bool android_gesture::queue_pop(struct ant::window::msg& msg) {
    int r = read(pipe_read, &msg, sizeof(msg));
    if (r == sizeof(msg)) return true;
    assert(r <= 0);
    return false;
}

void android_gesture::queue_process() {
    for (;;) {
        struct ant::window::msg msg;
        if (!queue_pop(msg)) {
            break;
        }
        ant::window::input_message(g_cb, msg);
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
    struct ant::window::msg msg;
    msg.type = ant::window::msg_type::gesture_tap;
    msg.tap.x = x;
    msg.tap.y = y;
    queue_push(msg);
}
void android_gesture::onLongPress(android_app* app, float x, float y) {
    struct ant::window::msg msg;
    msg.type = ant::window::msg_type::gesture_longpress;
    msg.state = 0; //TODO
    msg.longpress.x = x;
    msg.longpress.y = y;
    queue_push(msg);

}
void android_gesture::onPan(android_app* app, int state, float x, float y, float dx, float dy) {
    struct ant::window::msg msg;
    msg.type = ant::window::msg_type::gesture_pan;
    msg.pinch.state = state;
    msg.pan.x = x;
    msg.pan.y = y;
    msg.pan.dx = dx;
    msg.pan.dy = dy;
    queue_push(msg);
}
void android_gesture::onPinch(android_app* app, int state, float x, float y, float velocity) {
    struct ant::window::msg msg;
    msg.type = ant::window::msg_type::gesture_pinch;
    msg.pinch.state = state;
    msg.pinch.x = x;
    msg.pinch.y = y;
    msg.pinch.velocity = velocity;
    queue_push(msg);
}

