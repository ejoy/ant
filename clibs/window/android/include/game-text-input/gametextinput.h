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
 * @defgroup game_text_input Game Text Input
 * The interface to use GameTextInput.
 * @{
 */

#pragma once

#include <android/rect.h>
#include <jni.h>
#include <stdint.h>

#include "gamecommon.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * This struct holds a span within a region of text from start (inclusive) to
 * end (exclusive). An empty span or cursor position is specified with
 * start==end. An undefined span is specified with start = end = SPAN_UNDEFINED.
 */
typedef struct GameTextInputSpan {
    /** The start of the region (inclusive). */
    int32_t start;
    /** The end of the region (exclusive). */
    int32_t end;
} GameTextInputSpan;

/**
 * Values with special meaning in a GameTextInputSpan.
 */
enum GameTextInputSpanFlag { SPAN_UNDEFINED = -1 };

/**
 * This struct holds the state of an editable section of text.
 * The text can have a selection and a composing region defined on it.
 * A composing region is used by IMEs that allow input using multiple steps to
 * compose a glyph or word. Use functions GameTextInput_getState and
 * GameTextInput_setState to read and modify the state that an IME is editing.
 */
typedef struct GameTextInputState {
    /**
     * Text owned by the state, as a modified UTF-8 string. Null-terminated.
     * https://en.wikipedia.org/wiki/UTF-8#Modified_UTF-8
     */
    const char *text_UTF8;
    /**
     * Length in bytes of text_UTF8, *not* including the null at end.
     */
    int32_t text_length;
    /**
     * A selection defined on the text.
     */
    GameTextInputSpan selection;
    /**
     * A composing region defined on the text.
     */
    GameTextInputSpan composingRegion;
} GameTextInputState;

/**
 * A callback called by GameTextInput_getState.
 * @param context User-defined context.
 * @param state State, owned by the library, that will be valid for the duration
 * of the callback.
 */
typedef void (*GameTextInputGetStateCallback)(
    void *context, const struct GameTextInputState *state);

/**
 * Opaque handle to the GameTextInput API.
 */
typedef struct GameTextInput GameTextInput;

/**
 * Initialize the GameTextInput library.
 * If called twice without GameTextInput_destroy being called, the same pointer
 * will be returned and a warning will be issued.
 * @param env A JNI env valid on the calling thread.
 * @param max_string_size The maximum length of a string that can be edited. If
 * zero, the maximum defaults to 65536 bytes. A buffer of this size is allocated
 * at initialization.
 * @return A handle to the library.
 */
GameTextInput *GameTextInput_init(JNIEnv *env, uint32_t max_string_size);

/**
 * When using GameTextInput, you need to create a gametextinput.InputConnection
 * on the Java side and pass it using this function to the library, unless using
 * GameActivity in which case this will be done for you. See the GameActivity
 * source code or GameTextInput samples for examples of usage.
 * @param input A valid GameTextInput library handle.
 * @param inputConnection A gametextinput.InputConnection object.
 */
void GameTextInput_setInputConnection(GameTextInput *input,
                                      jobject inputConnection);

/**
 * Unless using GameActivity, it is required to call this function from your
 * Java gametextinput.Listener.stateChanged method to convert eventState and
 * trigger any event callbacks. When using GameActivity, this does not need to
 * be called as event processing is handled by the Activity.
 * @param input A valid GameTextInput library handle.
 * @param eventState A Java gametextinput.State object.
 */
void GameTextInput_processEvent(GameTextInput *input, jobject eventState);

/**
 * Free any resources owned by the GameTextInput library.
 * Any subsequent calls to the library will fail until GameTextInput_init is
 * called again.
 * @param input A valid GameTextInput library handle.
 */
void GameTextInput_destroy(GameTextInput *input);

/**
 * Flags to be passed to GameTextInput_showIme.
 */
enum ShowImeFlags {
    SHOW_IME_UNDEFINED = 0,  // Default value.
    SHOW_IMPLICIT =
        1,  // Indicates that the user has forced the input method open so it
            // should not be closed until they explicitly do so.
    SHOW_FORCED = 2  // Indicates that this is an implicit request to show the
                     // input window, not as the result of a direct request by
                     // the user. The window may not be shown in this case.
};

/**
 * Show the IME. Calls InputMethodManager.showSoftInput().
 * @param input A valid GameTextInput library handle.
 * @param flags Defined in ShowImeFlags above. For more information see:
 * https://developer.android.com/reference/android/view/inputmethod/InputMethodManager
 */
void GameTextInput_showIme(GameTextInput *input, uint32_t flags);

/**
 * Flags to be passed to GameTextInput_hideIme.
 */
enum HideImeFlags {
    HIDE_IME_UNDEFINED = 0,  // Default value.
    HIDE_IMPLICIT_ONLY =
        1,  // Indicates that the soft input window should only be hidden if it
            // was not explicitly shown by the user.
    HIDE_NOT_ALWAYS =
        2,  // Indicates that the soft input window should normally be hidden,
            // unless it was originally shown with SHOW_FORCED.
};

/**
 * Show the IME. Calls InputMethodManager.hideSoftInputFromWindow().
 * @param input A valid GameTextInput library handle.
 * @param flags Defined in HideImeFlags above. For more information see:
 * https://developer.android.com/reference/android/view/inputmethod/InputMethodManager
 */
void GameTextInput_hideIme(GameTextInput *input, uint32_t flags);

/**
 * Call a callback with the current GameTextInput state, which may have been
 * modified by changes in the IME and calls to GameTextInput_setState. We use a
 * callback rather than returning the state in order to simplify ownership of
 * text_UTF8 strings. These strings are only valid during the calling of the
 * callback.
 * @param input A valid GameTextInput library handle.
 * @param callback A function that will be called with valid state.
 * @param context Context used by the callback.
 */
void GameTextInput_getState(GameTextInput *input,
                            GameTextInputGetStateCallback callback,
                            void *context);

/**
 * Set the current GameTextInput state. This state is reflected to any active
 * IME.
 * @param input A valid GameTextInput library handle.
 * @param state The state to set. Ownership is maintained by the caller and must
 * remain valid for the duration of the call.
 */
void GameTextInput_setState(GameTextInput *input,
                            const GameTextInputState *state);

/**
 * Type of the callback needed by GameTextInput_setEventCallback that will be
 * called every time the IME state changes.
 * @param context User-defined context set in GameTextInput_setEventCallback.
 * @param current_state Current IME state, owned by the library and valid during
 * the callback.
 */
typedef void (*GameTextInputEventCallback)(
    void *context, const GameTextInputState *current_state);

/**
 * Optionally set a callback to be called whenever the IME state changes.
 * Not necessary if you are using GameActivity, which handles these callbacks
 * for you.
 * @param input A valid GameTextInput library handle.
 * @param callback Called by the library when the IME state changes.
 * @param context Context passed as first argument to the callback.
 */
void GameTextInput_setEventCallback(GameTextInput *input,
                                    GameTextInputEventCallback callback,
                                    void *context);

/**
 * Type of the callback needed by GameTextInput_setImeInsetsCallback that will
 * be called every time the IME window insets change.
 * @param context User-defined context set in
 * GameTextInput_setImeWIndowInsetsCallback.
 * @param current_insets Current IME insets, owned by the library and valid
 * during the callback.
 */
typedef void (*GameTextInputImeInsetsCallback)(void *context,
                                               const ARect *current_insets);

/**
 * Optionally set a callback to be called whenever the IME insets change.
 * Not necessary if you are using GameActivity, which handles these callbacks
 * for you.
 * @param input A valid GameTextInput library handle.
 * @param callback Called by the library when the IME insets change.
 * @param context Context passed as first argument to the callback.
 */
void GameTextInput_setImeInsetsCallback(GameTextInput *input,
                                        GameTextInputImeInsetsCallback callback,
                                        void *context);

/**
 * Get the current window insets for the IME.
 * @param input A valid GameTextInput library handle.
 * @param insets Filled with the current insets by this function.
 */
void GameTextInput_getImeInsets(const GameTextInput *input, ARect *insets);

/**
 * Unless using GameActivity, it is required to call this function from your
 * Java gametextinput.Listener.onImeInsetsChanged method to
 * trigger any event callbacks. When using GameActivity, this does not need to
 * be called as insets processing is handled by the Activity.
 * @param input A valid GameTextInput library handle.
 * @param eventState A Java gametextinput.State object.
 */
void GameTextInput_processImeInsets(GameTextInput *input, const ARect *insets);

/**
 * Convert a GameTextInputState struct to a Java gametextinput.State object.
 * Don't forget to delete the returned Java local ref when you're done.
 * @param input A valid GameTextInput library handle.
 * @param state Input state to convert.
 * @return A Java object of class gametextinput.State. The caller is required to
 * delete this local reference.
 */
jobject GameTextInputState_toJava(const GameTextInput *input,
                                  const GameTextInputState *state);

/**
 * Convert from a Java gametextinput.State object into a C GameTextInputState
 * struct.
 * @param input A valid GameTextInput library handle.
 * @param state A Java gametextinput.State object.
 * @param callback A function called with the C struct, valid for the duration
 * of the call.
 * @param context Context passed to the callback.
 */
void GameTextInputState_fromJava(const GameTextInput *input, jobject state,
                                 GameTextInputGetStateCallback callback,
                                 void *context);

#ifdef __cplusplus
}
#endif

/** @} */
