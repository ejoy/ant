#pragma once

struct android_app;
struct ant_gesture;

struct android_gesture {
public:
    void initialize(android_app* app);
    void destroy(android_app* app);
    void onTap(android_app* app, float x, float y);
    void onLongPress(android_app* app, float x, float y);
    void onPan(android_app* app, float x, float y, float dx, float dy, float vx, float vy);
    void onPinch(android_app* app, int state, float x, float y, float velocity);
private:
    void queue_push(struct ant_gesture const& gesture);
    bool queue_pop(struct ant_gesture& gesture);
    void queue_process();
    static int queue_callback(int fd, int events, void *data);
    int pipe_read = -1;
    int pipe_write = -1;
};
