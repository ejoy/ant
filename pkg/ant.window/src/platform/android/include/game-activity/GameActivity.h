/*
 * Copyright (C) 2021 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @addtogroup GameActivity Game Activity
 * The interface to use GameActivity.
 * @{
 */

/**
 * @file GameActivity.h
 */

#ifndef ANDROID_GAME_SDK_GAME_ACTIVITY_H
#define ANDROID_GAME_SDK_GAME_ACTIVITY_H

#include <android/asset_manager.h>
#include <android/input.h>
#include <android/native_window.h>
#include <android/rect.h>
#include <jni.h>
#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>

#include "game-text-input/gametextinput.h"

#ifdef __cplusplus
extern "C" {
#endif

#define GAMEACTIVITY_MAJOR_VERSION 1
#define GAMEACTIVITY_MINOR_VERSION 2
#define GAMEACTIVITY_BUGFIX_VERSION 2

#define GAMEACTIVITY_PACKED_VERSION                                           \
    ((GAMEACTIVITY_MAJOR_VERSION << 16) | (GAMEACTIVITY_MINOR_VERSION << 8) | \
     (GAMEACTIVITY_BUGFIX_VERSION))

/**
 * {@link GameActivityCallbacks}
 */
struct GameActivityCallbacks;

/**
 * This structure defines the native side of an android.app.GameActivity.
 * It is created by the framework, and handed to the application's native
 * code as it is being launched.
 */
typedef struct GameActivity {
    /**
     * Pointer to the callback function table of the native application.
     * You can set the functions here to your own callbacks.  The callbacks
     * pointer itself here should not be changed; it is allocated and managed
     * for you by the framework.
     */
    struct GameActivityCallbacks* callbacks;

    /**
     * The global handle on the process's Java VM.
     */
    JavaVM* vm;

    /**
     * JNI context for the main thread of the app.  Note that this field
     * can ONLY be used from the main thread of the process; that is, the
     * thread that calls into the GameActivityCallbacks.
     */
    JNIEnv* env;

    /**
     * The GameActivity object handle.
     */
    jobject javaGameActivity;

    /**
     * Path to this application's internal data directory.
     */
    const char* internalDataPath;

    /**
     * Path to this application's external (removable/mountable) data directory.
     */
    const char* externalDataPath;

    /**
     * The platform's SDK version code.
     */
    int32_t sdkVersion;

    /**
     * This is the native instance of the application.  It is not used by
     * the framework, but can be set by the application to its own instance
     * state.
     */
    void* instance;

    /**
     * Pointer to the Asset Manager instance for the application.  The
     * application uses this to access binary assets bundled inside its own .apk
     * file.
     */
    AAssetManager* assetManager;

    /**
     * Available starting with Honeycomb: path to the directory containing
     * the application's OBB files (if any).  If the app doesn't have any
     * OBB files, this directory may not exist.
     */
    const char* obbPath;
} GameActivity;

/**
 * The maximum number of axes supported in an Android MotionEvent.
 * See https://developer.android.com/ndk/reference/group/input.
 */
#define GAME_ACTIVITY_POINTER_INFO_AXIS_COUNT 48

/**
 * \brief Describe information about a pointer, found in a
 * GameActivityMotionEvent.
 *
 * You can read values directly from this structure, or use helper functions
 * (`GameActivityPointerAxes_getX`, `GameActivityPointerAxes_getY` and
 * `GameActivityPointerAxes_getAxisValue`).
 *
 * The X axis and Y axis are enabled by default but any other axis that you want
 * to read **must** be enabled first, using
 * `GameActivityPointerAxes_enableAxis`.
 *
 * \see GameActivityMotionEvent
 */
typedef struct GameActivityPointerAxes {
    int32_t id;
    int32_t toolType;
    float axisValues[GAME_ACTIVITY_POINTER_INFO_AXIS_COUNT];
    float rawX;
    float rawY;
} GameActivityPointerAxes;

/** \brief Get the toolType of the pointer. */
inline int32_t GameActivityPointerAxes_getToolType(
    const GameActivityPointerAxes* pointerInfo) {
    return pointerInfo->toolType;
}

/** \brief Get the current X coordinate of the pointer. */
inline float GameActivityPointerAxes_getX(
    const GameActivityPointerAxes* pointerInfo) {
    return pointerInfo->axisValues[AMOTION_EVENT_AXIS_X];
}

/** \brief Get the current Y coordinate of the pointer. */
inline float GameActivityPointerAxes_getY(
    const GameActivityPointerAxes* pointerInfo) {
    return pointerInfo->axisValues[AMOTION_EVENT_AXIS_Y];
}

/**
 * \brief Enable the specified axis, so that its value is reported in the
 * GameActivityPointerAxes structures stored in a motion event.
 *
 * You must enable any axis that you want to read, apart from
 * `AMOTION_EVENT_AXIS_X` and `AMOTION_EVENT_AXIS_Y` that are enabled by
 * default.
 *
 * If the axis index is out of range, nothing is done.
 */
void GameActivityPointerAxes_enableAxis(int32_t axis);

/**
 * \brief Disable the specified axis. Its value won't be reported in the
 * GameActivityPointerAxes structures stored in a motion event anymore.
 *
 * Apart from X and Y, any axis that you want to read **must** be enabled first,
 * using `GameActivityPointerAxes_enableAxis`.
 *
 * If the axis index is out of range, nothing is done.
 */
void GameActivityPointerAxes_disableAxis(int32_t axis);

/**
 * \brief Get the value of the requested axis.
 *
 * Apart from X and Y, any axis that you want to read **must** be enabled first,
 * using `GameActivityPointerAxes_enableAxis`.
 *
 * Find the valid enums for the axis (`AMOTION_EVENT_AXIS_X`,
 * `AMOTION_EVENT_AXIS_Y`, `AMOTION_EVENT_AXIS_PRESSURE`...)
 * in https://developer.android.com/ndk/reference/group/input.
 *
 * @param pointerInfo The structure containing information about the pointer,
 * obtained from GameActivityMotionEvent.
 * @param axis The axis to get the value from
 * @return The value of the axis, or 0 if the axis is invalid or was not
 * enabled.
 */
float GameActivityPointerAxes_getAxisValue(
    const GameActivityPointerAxes* pointerInfo, int32_t axis);

inline float GameActivityPointerAxes_getPressure(
    const GameActivityPointerAxes* pointerInfo) {
    return GameActivityPointerAxes_getAxisValue(pointerInfo,
                                                AMOTION_EVENT_AXIS_PRESSURE);
}

inline float GameActivityPointerAxes_getSize(
    const GameActivityPointerAxes* pointerInfo) {
    return GameActivityPointerAxes_getAxisValue(pointerInfo,
                                                AMOTION_EVENT_AXIS_SIZE);
}

inline float GameActivityPointerAxes_getTouchMajor(
    const GameActivityPointerAxes* pointerInfo) {
    return GameActivityPointerAxes_getAxisValue(pointerInfo,
                                                AMOTION_EVENT_AXIS_TOUCH_MAJOR);
}

inline float GameActivityPointerAxes_getTouchMinor(
    const GameActivityPointerAxes* pointerInfo) {
    return GameActivityPointerAxes_getAxisValue(pointerInfo,
                                                AMOTION_EVENT_AXIS_TOUCH_MINOR);
}

inline float GameActivityPointerAxes_getToolMajor(
    const GameActivityPointerAxes* pointerInfo) {
    return GameActivityPointerAxes_getAxisValue(pointerInfo,
                                                AMOTION_EVENT_AXIS_TOOL_MAJOR);
}

inline float GameActivityPointerAxes_getToolMinor(
    const GameActivityPointerAxes* pointerInfo) {
    return GameActivityPointerAxes_getAxisValue(pointerInfo,
                                                AMOTION_EVENT_AXIS_TOOL_MINOR);
}

inline float GameActivityPointerAxes_getOrientation(
    const GameActivityPointerAxes* pointerInfo) {
    return GameActivityPointerAxes_getAxisValue(pointerInfo,
                                                AMOTION_EVENT_AXIS_ORIENTATION);
}

/**
 * The maximum number of pointers returned inside a motion event.
 */
#if (defined GAMEACTIVITY_MAX_NUM_POINTERS_IN_MOTION_EVENT_OVERRIDE)
#define GAMEACTIVITY_MAX_NUM_POINTERS_IN_MOTION_EVENT \
    GAMEACTIVITY_MAX_NUM_POINTERS_IN_MOTION_EVENT_OVERRIDE
#else
#define GAMEACTIVITY_MAX_NUM_POINTERS_IN_MOTION_EVENT 8
#endif

/**
 * \brief Describe a motion event that happened on the GameActivity SurfaceView.
 *
 * This is 1:1 mapping to the information contained in a Java `MotionEvent`
 * (see https://developer.android.com/reference/android/view/MotionEvent).
 */
typedef struct GameActivityMotionEvent {
    int32_t deviceId;
    int32_t source;
    int32_t action;

    int64_t eventTime;
    int64_t downTime;

    int32_t flags;
    int32_t metaState;

    int32_t actionButton;
    int32_t buttonState;
    int32_t classification;
    int32_t edgeFlags;

    uint32_t pointerCount;
    GameActivityPointerAxes
        pointers[GAMEACTIVITY_MAX_NUM_POINTERS_IN_MOTION_EVENT];

    int historySize;
    long* historicalEventTimes;
    float* historicalAxisValues;

    float precisionX;
    float precisionY;
} GameActivityMotionEvent;

/**
 * \brief Describe a key event that happened on the GameActivity SurfaceView.
 *
 * This is 1:1 mapping to the information contained in a Java `KeyEvent`
 * (see https://developer.android.com/reference/android/view/KeyEvent).
 */
typedef struct GameActivityKeyEvent {
    int32_t deviceId;
    int32_t source;
    int32_t action;

    int64_t eventTime;
    int64_t downTime;

    int32_t flags;
    int32_t metaState;

    int32_t modifiers;
    int32_t repeatCount;
    int32_t keyCode;
    int32_t scanCode;
    int32_t unicodeChar;
} GameActivityKeyEvent;

float GameActivityMotionEvent_getHistoricalAxisValue(
    const GameActivityMotionEvent* event, int axis, int pointerIndex,
    int historyPos);

inline int GameActivityMotionEvent_getHistorySize(
    const GameActivityMotionEvent* event) {
    return event->historySize;
}

inline float GameActivityMotionEvent_getHistoricalX(
    const GameActivityMotionEvent* event, int pointerIndex, int historyPos) {
    return GameActivityMotionEvent_getHistoricalAxisValue(
        event, AMOTION_EVENT_AXIS_X, pointerIndex, historyPos);
}

inline float GameActivityMotionEvent_getHistoricalY(
    const GameActivityMotionEvent* event, int pointerIndex, int historyPos) {
    return GameActivityMotionEvent_getHistoricalAxisValue(
        event, AMOTION_EVENT_AXIS_Y, pointerIndex, historyPos);
}

inline float GameActivityMotionEvent_getHistoricalPressure(
    const GameActivityMotionEvent* event, int pointerIndex, int historyPos) {
    return GameActivityMotionEvent_getHistoricalAxisValue(
        event, AMOTION_EVENT_AXIS_PRESSURE, pointerIndex, historyPos);
}

inline float GameActivityMotionEvent_getHistoricalSize(
    const GameActivityMotionEvent* event, int pointerIndex, int historyPos) {
    return GameActivityMotionEvent_getHistoricalAxisValue(
        event, AMOTION_EVENT_AXIS_SIZE, pointerIndex, historyPos);
}

inline float GameActivityMotionEvent_getHistoricalTouchMajor(
    const GameActivityMotionEvent* event, int pointerIndex, int historyPos) {
    return GameActivityMotionEvent_getHistoricalAxisValue(
        event, AMOTION_EVENT_AXIS_TOUCH_MAJOR, pointerIndex, historyPos);
}

inline float GameActivityMotionEvent_getHistoricalTouchMinor(
    const GameActivityMotionEvent* event, int pointerIndex, int historyPos) {
    return GameActivityMotionEvent_getHistoricalAxisValue(
        event, AMOTION_EVENT_AXIS_TOUCH_MINOR, pointerIndex, historyPos);
}

inline float GameActivityMotionEvent_getHistoricalToolMajor(
    const GameActivityMotionEvent* event, int pointerIndex, int historyPos) {
    return GameActivityMotionEvent_getHistoricalAxisValue(
        event, AMOTION_EVENT_AXIS_TOOL_MAJOR, pointerIndex, historyPos);
}

inline float GameActivityMotionEvent_getHistoricalToolMinor(
    const GameActivityMotionEvent* event, int pointerIndex, int historyPos) {
    return GameActivityMotionEvent_getHistoricalAxisValue(
        event, AMOTION_EVENT_AXIS_TOOL_MINOR, pointerIndex, historyPos);
}

inline float GameActivityMotionEvent_getHistoricalOrientation(
    const GameActivityMotionEvent* event, int pointerIndex, int historyPos) {
    return GameActivityMotionEvent_getHistoricalAxisValue(
        event, AMOTION_EVENT_AXIS_ORIENTATION, pointerIndex, historyPos);
}

/**
 * A function the user should call from their callback with the data, its length
 * and the library- supplied context.
 */
typedef void (*SaveInstanceStateRecallback)(const char* bytes, int len,
                                            void* context);

/**
 * These are the callbacks the framework makes into a native application.
 * All of these callbacks happen on the main thread of the application.
 * By default, all callbacks are NULL; set to a pointer to your own function
 * to have it called.
 */
typedef struct GameActivityCallbacks {
    /**
     * GameActivity has started.  See Java documentation for Activity.onStart()
     * for more information.
     */
    void (*onStart)(GameActivity* activity);

    /**
     * GameActivity has resumed.  See Java documentation for Activity.onResume()
     * for more information.
     */
    void (*onResume)(GameActivity* activity);

    /**
     * The framework is asking GameActivity to save its current instance state.
     * See the Java documentation for Activity.onSaveInstanceState() for more
     * information. The user should call the recallback with their data, its
     * length and the provided context; they retain ownership of the data. Note
     * that the saved state will be persisted, so it can not contain any active
     * entities (pointers to memory, file descriptors, etc).
     */
    void (*onSaveInstanceState)(GameActivity* activity,
                                SaveInstanceStateRecallback recallback,
                                void* context);

    /**
     * GameActivity has paused.  See Java documentation for Activity.onPause()
     * for more information.
     */
    void (*onPause)(GameActivity* activity);

    /**
     * GameActivity has stopped.  See Java documentation for Activity.onStop()
     * for more information.
     */
    void (*onStop)(GameActivity* activity);

    /**
     * GameActivity is being destroyed.  See Java documentation for
     * Activity.onDestroy() for more information.
     */
    void (*onDestroy)(GameActivity* activity);

    /**
     * Focus has changed in this GameActivity's window.  This is often used,
     * for example, to pause a game when it loses input focus.
     */
    void (*onWindowFocusChanged)(GameActivity* activity, bool hasFocus);

    /**
     * The drawing window for this native activity has been created.  You
     * can use the given native window object to start drawing.
     */
    void (*onNativeWindowCreated)(GameActivity* activity,
                                  ANativeWindow* window);

    /**
     * The drawing window for this native activity has been resized.  You should
     * retrieve the new size from the window and ensure that your rendering in
     * it now matches.
     */
    void (*onNativeWindowResized)(GameActivity* activity, ANativeWindow* window,
                                  int32_t newWidth, int32_t newHeight);

    /**
     * The drawing window for this native activity needs to be redrawn.  To
     * avoid transient artifacts during screen changes (such resizing after
     * rotation), applications should not return from this function until they
     * have finished drawing their window in its current state.
     */
    void (*onNativeWindowRedrawNeeded)(GameActivity* activity,
                                       ANativeWindow* window);

    /**
     * The drawing window for this native activity is going to be destroyed.
     * You MUST ensure that you do not touch the window object after returning
     * from this function: in the common case of drawing to the window from
     * another thread, that means the implementation of this callback must
     * properly synchronize with the other thread to stop its drawing before
     * returning from here.
     */
    void (*onNativeWindowDestroyed)(GameActivity* activity,
                                    ANativeWindow* window);

    /**
     * The current device AConfiguration has changed.  The new configuration can
     * be retrieved from assetManager.
     */
    void (*onConfigurationChanged)(GameActivity* activity);

    /**
     * The system is running low on memory.  Use this callback to release
     * resources you do not need, to help the system avoid killing more
     * important processes.
     */
    void (*onTrimMemory)(GameActivity* activity, int level);

    /**
     * Callback called for every MotionEvent done on the GameActivity
     * SurfaceView. Ownership of `event` is maintained by the library and it is
     * only valid during the callback.
     */
    bool (*onTouchEvent)(GameActivity* activity,
                         const GameActivityMotionEvent* event);

    /**
     * Callback called for every key down event on the GameActivity SurfaceView.
     * Ownership of `event` is maintained by the library and it is only valid
     * during the callback.
     */
    bool (*onKeyDown)(GameActivity* activity,
                      const GameActivityKeyEvent* event);

    /**
     * Callback called for every key up event on the GameActivity SurfaceView.
     * Ownership of `event` is maintained by the library and it is only valid
     * during the callback.
     */
    bool (*onKeyUp)(GameActivity* activity, const GameActivityKeyEvent* event);

    /**
     * Callback called for every soft-keyboard text input event.
     * Ownership of `state` is maintained by the library and it is only valid
     * during the callback.
     */
    void (*onTextInputEvent)(GameActivity* activity,
                             const GameTextInputState* state);

    /**
     * Callback called when WindowInsets of the main app window have changed.
     * Call GameActivity_getWindowInsets to retrieve the insets themselves.
     */
    void (*onWindowInsetsChanged)(GameActivity* activity);
} GameActivityCallbacks;

/** \brief Handle the freeing of the GameActivityMotionEvent struct. */
void GameActivityMotionEvent_destroy(GameActivityMotionEvent* c_event);

/**
 * \brief Convert a Java `MotionEvent` to a `GameActivityMotionEvent`.
 *
 * This is done automatically by the GameActivity: see `onTouchEvent` to set
 * a callback to consume the received events.
 * This function can be used if you re-implement events handling in your own
 * activity.
 * Ownership of out_event is maintained by the caller.
 */
void GameActivityMotionEvent_fromJava(JNIEnv* env, jobject motionEvent,
                                      GameActivityMotionEvent* out_event);

/**
 * \brief Convert a Java `KeyEvent` to a `GameActivityKeyEvent`.
 *
 * This is done automatically by the GameActivity: see `onKeyUp` and `onKeyDown`
 * to set a callback to consume the received events.
 * This function can be used if you re-implement events handling in your own
 * activity.
 * Ownership of out_event is maintained by the caller.
 */
void GameActivityKeyEvent_fromJava(JNIEnv* env, jobject motionEvent,
                                   GameActivityKeyEvent* out_event);

/**
 * This is the function that must be in the native code to instantiate the
 * application's native activity.  It is called with the activity instance (see
 * above); if the code is being instantiated from a previously saved instance,
 * the savedState will be non-NULL and point to the saved data.  You must make
 * any copy of this data you need -- it will be released after you return from
 * this function.
 */
typedef void GameActivity_createFunc(GameActivity* activity, void* savedState,
                                     size_t savedStateSize);

/**
 * The name of the function that NativeInstance looks for when launching its
 * native code.  This is the default function that is used, you can specify
 * "android.app.func_name" string meta-data in your manifest to use a different
 * function.
 */
extern GameActivity_createFunc GameActivity_onCreate;

/**
 * Finish the given activity.  Its finish() method will be called, causing it
 * to be stopped and destroyed.  Note that this method can be called from
 * *any* thread; it will send a message to the main thread of the process
 * where the Java finish call will take place.
 */
void GameActivity_finish(GameActivity* activity);

/**
 * Flags for GameActivity_setWindowFlags,
 * as per the Java API at android.view.WindowManager.LayoutParams.
 */
enum GameActivitySetWindowFlags {
    /**
     * As long as this window is visible to the user, allow the lock
     * screen to activate while the screen is on.  This can be used
     * independently, or in combination with {@link
     * GAMEACTIVITY_FLAG_KEEP_SCREEN_ON} and/or {@link
     * GAMEACTIVITY_FLAG_SHOW_WHEN_LOCKED}
     */
    GAMEACTIVITY_FLAG_ALLOW_LOCK_WHILE_SCREEN_ON = 0x00000001,
    /** Everything behind this window will be dimmed. */
    GAMEACTIVITY_FLAG_DIM_BEHIND = 0x00000002,
    /**
     * Blur everything behind this window.
     * @deprecated Blurring is no longer supported.
     */
    GAMEACTIVITY_FLAG_BLUR_BEHIND = 0x00000004,
    /**
     * This window won't ever get key input focus, so the
     * user can not send key or other button events to it.  Those will
     * instead go to whatever focusable window is behind it.  This flag
     * will also enable {@link GAMEACTIVITY_FLAG_NOT_TOUCH_MODAL} whether or not
     * that is explicitly set.
     *
     * Setting this flag also implies that the window will not need to
     * interact with
     * a soft input method, so it will be Z-ordered and positioned
     * independently of any active input method (typically this means it
     * gets Z-ordered on top of the input method, so it can use the full
     * screen for its content and cover the input method if needed.  You
     * can use {@link GAMEACTIVITY_FLAG_ALT_FOCUSABLE_IM} to modify this
     * behavior.
     */
    GAMEACTIVITY_FLAG_NOT_FOCUSABLE = 0x00000008,
    /** This window can never receive touch events. */
    GAMEACTIVITY_FLAG_NOT_TOUCHABLE = 0x00000010,
    /**
     * Even when this window is focusable (its
     * {@link GAMEACTIVITY_FLAG_NOT_FOCUSABLE} is not set), allow any pointer
     * events outside of the window to be sent to the windows behind it.
     * Otherwise it will consume all pointer events itself, regardless of
     * whether they are inside of the window.
     */
    GAMEACTIVITY_FLAG_NOT_TOUCH_MODAL = 0x00000020,
    /**
     * When set, if the device is asleep when the touch
     * screen is pressed, you will receive this first touch event.  Usually
     * the first touch event is consumed by the system since the user can
     * not see what they are pressing on.
     *
     * @deprecated This flag has no effect.
     */
    GAMEACTIVITY_FLAG_TOUCHABLE_WHEN_WAKING = 0x00000040,
    /**
     * As long as this window is visible to the user, keep
     * the device's screen turned on and bright.
     */
    GAMEACTIVITY_FLAG_KEEP_SCREEN_ON = 0x00000080,
    /**
     * Place the window within the entire screen, ignoring
     * decorations around the border (such as the status bar).  The
     * window must correctly position its contents to take the screen
     * decoration into account.
     */
    GAMEACTIVITY_FLAG_LAYOUT_IN_SCREEN = 0x00000100,
    /** Allows the window to extend outside of the screen. */
    GAMEACTIVITY_FLAG_LAYOUT_NO_LIMITS = 0x00000200,
    /**
     * Hide all screen decorations (such as the status
     * bar) while this window is displayed.  This allows the window to
     * use the entire display space for itself -- the status bar will
     * be hidden when an app window with this flag set is on the top
     * layer. A fullscreen window will ignore a value of {@link
     * GAMEACTIVITY_SOFT_INPUT_ADJUST_RESIZE}; the window will stay
     * fullscreen and will not resize.
     */
    GAMEACTIVITY_FLAG_FULLSCREEN = 0x00000400,
    /**
     * Override {@link GAMEACTIVITY_FLAG_FULLSCREEN} and force the
     * screen decorations (such as the status bar) to be shown.
     */
    GAMEACTIVITY_FLAG_FORCE_NOT_FULLSCREEN = 0x00000800,
    /**
     * Turn on dithering when compositing this window to
     * the screen.
     * @deprecated This flag is no longer used.
     */
    GAMEACTIVITY_FLAG_DITHER = 0x00001000,
    /**
     * Treat the content of the window as secure, preventing
     * it from appearing in screenshots or from being viewed on non-secure
     * displays.
     */
    GAMEACTIVITY_FLAG_SECURE = 0x00002000,
    /**
     * A special mode where the layout parameters are used
     * to perform scaling of the surface when it is composited to the
     * screen.
     */
    GAMEACTIVITY_FLAG_SCALED = 0x00004000,
    /**
     * Intended for windows that will often be used when the user is
     * holding the screen against their face, it will aggressively
     * filter the event stream to prevent unintended presses in this
     * situation that may not be desired for a particular window, when
     * such an event stream is detected, the application will receive
     * a {@link AMOTION_EVENT_ACTION_CANCEL} to indicate this so
     * applications can handle this accordingly by taking no action on
     * the event until the finger is released.
     */
    GAMEACTIVITY_FLAG_IGNORE_CHEEK_PRESSES = 0x00008000,
    /**
     * A special option only for use in combination with
     * {@link GAMEACTIVITY_FLAG_LAYOUT_IN_SCREEN}.  When requesting layout in
     * the screen your window may appear on top of or behind screen decorations
     * such as the status bar.  By also including this flag, the window
     * manager will report the inset rectangle needed to ensure your
     * content is not covered by screen decorations.
     */
    GAMEACTIVITY_FLAG_LAYOUT_INSET_DECOR = 0x00010000,
    /**
     * Invert the state of {@link GAMEACTIVITY_FLAG_NOT_FOCUSABLE} with
     * respect to how this window interacts with the current method.
     * That is, if FLAG_NOT_FOCUSABLE is set and this flag is set,
     * then the window will behave as if it needs to interact with the
     * input method and thus be placed behind/away from it; if {@link
     * GAMEACTIVITY_FLAG_NOT_FOCUSABLE} is not set and this flag is set,
     * then the window will behave as if it doesn't need to interact
     * with the input method and can be placed to use more space and
     * cover the input method.
     */
    GAMEACTIVITY_FLAG_ALT_FOCUSABLE_IM = 0x00020000,
    /**
     * If you have set {@link GAMEACTIVITY_FLAG_NOT_TOUCH_MODAL}, you
     * can set this flag to receive a single special MotionEvent with
     * the action
     * {@link AMOTION_EVENT_ACTION_OUTSIDE} for
     * touches that occur outside of your window.  Note that you will not
     * receive the full down/move/up gesture, only the location of the
     * first down as an {@link AMOTION_EVENT_ACTION_OUTSIDE}.
     */
    GAMEACTIVITY_FLAG_WATCH_OUTSIDE_TOUCH = 0x00040000,
    /**
     * Special flag to let windows be shown when the screen
     * is locked. This will let application windows take precedence over
     * key guard or any other lock screens. Can be used with
     * {@link GAMEACTIVITY_FLAG_KEEP_SCREEN_ON} to turn screen on and display
     * windows directly before showing the key guard window.  Can be used with
     * {@link GAMEACTIVITY_FLAG_DISMISS_KEYGUARD} to automatically fully
     * dismisss non-secure keyguards.  This flag only applies to the top-most
     * full-screen window.
     */
    GAMEACTIVITY_FLAG_SHOW_WHEN_LOCKED = 0x00080000,
    /**
     * Ask that the system wallpaper be shown behind
     * your window.  The window surface must be translucent to be able
     * to actually see the wallpaper behind it; this flag just ensures
     * that the wallpaper surface will be there if this window actually
     * has translucent regions.
     */
    GAMEACTIVITY_FLAG_SHOW_WALLPAPER = 0x00100000,
    /**
     * When set as a window is being added or made
     * visible, once the window has been shown then the system will
     * poke the power manager's user activity (as if the user had woken
     * up the device) to turn the screen on.
     */
    GAMEACTIVITY_FLAG_TURN_SCREEN_ON = 0x00200000,
    /**
     * When set the window will cause the keyguard to
     * be dismissed, only if it is not a secure lock keyguard.  Because such
     * a keyguard is not needed for security, it will never re-appear if
     * the user navigates to another window (in contrast to
     * {@link GAMEACTIVITY_FLAG_SHOW_WHEN_LOCKED}, which will only temporarily
     * hide both secure and non-secure keyguards but ensure they reappear
     * when the user moves to another UI that doesn't hide them).
     * If the keyguard is currently active and is secure (requires an
     * unlock pattern) than the user will still need to confirm it before
     * seeing this window, unless {@link GAMEACTIVITY_FLAG_SHOW_WHEN_LOCKED} has
     * also been set.
     */
    GAMEACTIVITY_FLAG_DISMISS_KEYGUARD = 0x00400000,
};

/**
 * Change the window flags of the given activity.  Calls getWindow().setFlags()
 * of the given activity.
 * Note that some flags must be set before the window decoration is created,
 * see
 * https://developer.android.com/reference/android/view/Window#setFlags(int,%20int).
 * Note also that this method can be called from
 * *any* thread; it will send a message to the main thread of the process
 * where the Java finish call will take place.
 */
void GameActivity_setWindowFlags(GameActivity* activity, uint32_t addFlags,
                                 uint32_t removeFlags);

/**
 * Flags for GameActivity_showSoftInput; see the Java InputMethodManager
 * API for documentation.
 */
enum GameActivityShowSoftInputFlags {
    /**
     * Implicit request to show the input window, not as the result
     * of a direct request by the user.
     */
    GAMEACTIVITY_SHOW_SOFT_INPUT_IMPLICIT = 0x0001,

    /**
     * The user has forced the input method open (such as by
     * long-pressing menu) so it should not be closed until they
     * explicitly do so.
     */
    GAMEACTIVITY_SHOW_SOFT_INPUT_FORCED = 0x0002,
};

/**
 * Show the IME while in the given activity.  Calls
 * InputMethodManager.showSoftInput() for the given activity.  Note that this
 * method can be called from *any* thread; it will send a message to the main
 * thread of the process where the Java call will take place.
 */
void GameActivity_showSoftInput(GameActivity* activity, uint32_t flags);

/**
 * Set the text entry state (see documentation of the GameTextInputState struct
 * in the Game Text Input library reference).
 *
 * Ownership of the state is maintained by the caller.
 */
void GameActivity_setTextInputState(GameActivity* activity,
                                    const GameTextInputState* state);

/**
 * Get the last-received text entry state (see documentation of the
 * GameTextInputState struct in the Game Text Input library reference).
 *
 */
void GameActivity_getTextInputState(GameActivity* activity,
                                    GameTextInputGetStateCallback callback,
                                    void* context);

/**
 * Get a pointer to the GameTextInput library instance.
 */
GameTextInput* GameActivity_getTextInput(const GameActivity* activity);

/**
 * Flags for GameActivity_hideSoftInput; see the Java InputMethodManager
 * API for documentation.
 */
enum GameActivityHideSoftInputFlags {
    /**
     * The soft input window should only be hidden if it was not
     * explicitly shown by the user.
     */
    GAMEACTIVITY_HIDE_SOFT_INPUT_IMPLICIT_ONLY = 0x0001,
    /**
     * The soft input window should normally be hidden, unless it was
     * originally shown with {@link GAMEACTIVITY_SHOW_SOFT_INPUT_FORCED}.
     */
    GAMEACTIVITY_HIDE_SOFT_INPUT_NOT_ALWAYS = 0x0002,
};

/**
 * Hide the IME while in the given activity.  Calls
 * InputMethodManager.hideSoftInput() for the given activity.  Note that this
 * method can be called from *any* thread; it will send a message to the main
 * thread of the process where the Java finish call will take place.
 */
void GameActivity_hideSoftInput(GameActivity* activity, uint32_t flags);

/**
 * Get the current window insets of the particular component. See
 * https://developer.android.com/reference/androidx/core/view/WindowInsetsCompat.Type
 * for more details.
 * You can use these insets to influence what you show on the screen.
 */
void GameActivity_getWindowInsets(GameActivity* activity,
                                  GameCommonInsetsType type, ARect* insets);

/**
 * Set options on how the IME behaves when it is requested for text input.
 * See
 * https://developer.android.com/reference/android/view/inputmethod/EditorInfo
 * for the meaning of inputType, actionId and imeOptions.
 *
 * Note that this function will attach the current thread to the JVM if it is
 * not already attached, so the caller must detach the thread from the JVM
 * before the thread is destroyed using DetachCurrentThread.
 */
void GameActivity_setImeEditorInfo(GameActivity* activity, int inputType,
                                   int actionId, int imeOptions);

#ifdef __cplusplus
}
#endif

/** @} */

#endif  // ANDROID_GAME_SDK_GAME_ACTIVITY_H
