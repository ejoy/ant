#pragma once

struct android_app;

namespace ant::window {
    struct msg;
}

struct android_gesture {
public:
    void initialize(android_app* app);
    void destroy(android_app* app);
    void onTap(android_app* app, float x, float y);
    void onLongPress(android_app* app, float x, float y);
    void onPan(android_app* app, int state, float x, float y, float dx, float dy);
    void onPinch(android_app* app, int state, float x, float y, float velocity);
private:
    void queue_push(struct ant::window::msg const& msg);
    bool queue_pop(struct ant::window::msg& msg);
    void queue_process();
    static int queue_callback(int fd, int events, void *data);
    int pipe_read = -1;
    int pipe_write = -1;
};
