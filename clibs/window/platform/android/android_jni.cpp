#include "android_gesture.h"

#include <jni.h>
#include "game-activity/native_app_glue/android_native_app_glue.h"
#include "game-activity/GameActivity.h"

static android_gesture gesture;

extern "C" JNIEXPORT void JNICALL
Java_com_example_vaststars_GestureHandler_nativeInitialize(JNIEnv *env, jobject, jlong handle) {
    GameActivity* activity = (GameActivity*)handle;
    android_app* app = (android_app*)activity->instance;
    gesture.initialize(app);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_vaststars_GestureHandler_nativeDestroy(JNIEnv *env, jobject, jlong handle) {
    GameActivity* activity = (GameActivity*)handle;
    android_app* app = (android_app*)activity->instance;
    gesture.destroy(app);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_vaststars_GestureHandler_nativeOnTap(JNIEnv *env, jobject, jlong handle, jfloat x, jfloat y) {
    GameActivity* activity = (GameActivity*)handle;
    android_app* app = (android_app*)activity->instance;
    gesture.onTap(app, x, y);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_vaststars_GestureHandler_nativeOnLongPress(JNIEnv *env, jobject, jlong handle, jfloat x, jfloat y) {
    GameActivity* activity = (GameActivity*)handle;
    android_app* app = (android_app*)activity->instance;
    gesture.onLongPress(app, x, y);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_vaststars_GestureHandler_nativeOnPan(JNIEnv *env, jobject, jlong handle, jint state, jfloat x, jfloat y, jfloat dx, jfloat dy) {
    GameActivity* activity = (GameActivity*)handle;
    android_app* app = (android_app*)activity->instance;
    gesture.onPan(app, state, x, y, dx, dy);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_vaststars_GestureHandler_nativeOnPinch(JNIEnv *env, jobject, jlong handle, jint state, jfloat x, jfloat y, jfloat velocity) {
    GameActivity* activity = (GameActivity*)handle;
    android_app* app = (android_app*)activity->instance;
    gesture.onPinch(app, state, x, y, velocity);
}
