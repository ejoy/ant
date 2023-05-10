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
#include "game-text-input/gametextinput.h"

#include <android/log.h>
#include <jni.h>
#include <stdlib.h>
#include <string.h>

#include <algorithm>
#include <memory>
#include <vector>

#define LOG_TAG "GameTextInput"

static constexpr int32_t DEFAULT_MAX_STRING_SIZE = 1 << 16;

// Cache of field ids in the Java GameTextInputState class
struct StateClassInfo {
    jfieldID text;
    jfieldID selectionStart;
    jfieldID selectionEnd;
    jfieldID composingRegionStart;
    jfieldID composingRegionEnd;
};

// Main GameTextInput object.
struct GameTextInput {
   public:
    GameTextInput(JNIEnv *env, uint32_t max_string_size);
    ~GameTextInput();
    void setState(const GameTextInputState &state);
    const GameTextInputState &getState() const { return currentState_; }
    void setInputConnection(jobject inputConnection);
    void processEvent(jobject textInputEvent);
    void showIme(uint32_t flags);
    void hideIme(uint32_t flags);
    void setEventCallback(GameTextInputEventCallback callback, void *context);
    jobject stateToJava(const GameTextInputState &state) const;
    void stateFromJava(jobject textInputEvent,
                       GameTextInputGetStateCallback callback,
                       void *context) const;
    void setImeInsetsCallback(GameTextInputImeInsetsCallback callback,
                              void *context);
    void processImeInsets(const ARect *insets);
    const ARect &getImeInsets() const { return currentInsets_; }

   private:
    // Copy string and set other fields
    void setStateInner(const GameTextInputState &state);
    static void processCallback(void *context, const GameTextInputState *state);
    JNIEnv *env_ = nullptr;
    // Cached at initialization from
    // com/google/androidgamesdk/gametextinput/State.
    jclass stateJavaClass_ = nullptr;
    // The latest text input update.
    GameTextInputState currentState_ = {};
    // An instance of gametextinput.InputConnection.
    jclass inputConnectionClass_ = nullptr;
    jobject inputConnection_ = nullptr;
    jmethodID inputConnectionSetStateMethod_;
    jmethodID setSoftKeyboardActiveMethod_;
    void (*eventCallback_)(void *context,
                           const struct GameTextInputState *state) = nullptr;
    void *eventCallbackContext_ = nullptr;
    void (*insetsCallback_)(void *context,
                            const struct ARect *insets) = nullptr;
    ARect currentInsets_ = {};
    void *insetsCallbackContext_ = nullptr;
    StateClassInfo stateClassInfo_ = {};
    // Constant-sized buffer used to store state text.
    std::vector<char> stateStringBuffer_;
};

std::unique_ptr<GameTextInput> s_gameTextInput;

extern "C" {

///////////////////////////////////////////////////////////
/// GameTextInputState C Functions
///////////////////////////////////////////////////////////

// Convert to a Java structure.
jobject currentState_toJava(const GameTextInput *gameTextInput,
                            const GameTextInputState *state) {
    if (state == nullptr) return NULL;
    return gameTextInput->stateToJava(*state);
}

// Convert from Java structure.
void currentState_fromJava(const GameTextInput *gameTextInput,
                           jobject textInputEvent,
                           GameTextInputGetStateCallback callback,
                           void *context) {
    gameTextInput->stateFromJava(textInputEvent, callback, context);
}

///////////////////////////////////////////////////////////
/// GameTextInput C Functions
///////////////////////////////////////////////////////////

struct GameTextInput *GameTextInput_init(JNIEnv *env,
                                         uint32_t max_string_size) {
    if (s_gameTextInput.get() != nullptr) {
        __android_log_print(ANDROID_LOG_WARN, LOG_TAG,
                            "Warning: called GameTextInput_init twice without "
                            "calling GameTextInput_destroy");
        return s_gameTextInput.get();
    }
    // Don't use make_unique, for C++11 compatibility
    s_gameTextInput =
        std::unique_ptr<GameTextInput>(new GameTextInput(env, max_string_size));
    return s_gameTextInput.get();
}

void GameTextInput_destroy(GameTextInput *input) {
    if (input == nullptr || s_gameTextInput.get() == nullptr) return;
    s_gameTextInput.reset();
}

void GameTextInput_setState(GameTextInput *input,
                            const GameTextInputState *state) {
    if (state == nullptr) return;
    input->setState(*state);
}

void GameTextInput_getState(GameTextInput *input,
                            GameTextInputGetStateCallback callback,
                            void *context) {
    callback(context, &input->getState());
}

void GameTextInput_setInputConnection(GameTextInput *input,
                                      jobject inputConnection) {
    input->setInputConnection(inputConnection);
}

void GameTextInput_processEvent(GameTextInput *input, jobject textInputEvent) {
    input->processEvent(textInputEvent);
}

void GameTextInput_processImeInsets(GameTextInput *input, const ARect *insets) {
    input->processImeInsets(insets);
}

void GameTextInput_showIme(struct GameTextInput *input, uint32_t flags) {
    input->showIme(flags);
}

void GameTextInput_hideIme(struct GameTextInput *input, uint32_t flags) {
    input->hideIme(flags);
}

void GameTextInput_setEventCallback(struct GameTextInput *input,
                                    GameTextInputEventCallback callback,
                                    void *context) {
    input->setEventCallback(callback, context);
}

void GameTextInput_setImeInsetsCallback(struct GameTextInput *input,
                                        GameTextInputImeInsetsCallback callback,
                                        void *context) {
    input->setImeInsetsCallback(callback, context);
}

void GameTextInput_getImeInsets(const GameTextInput *input, ARect *insets) {
    *insets = input->getImeInsets();
}

}  // extern "C"

///////////////////////////////////////////////////////////
/// GameTextInput C++ class Implementation
///////////////////////////////////////////////////////////

GameTextInput::GameTextInput(JNIEnv *env, uint32_t max_string_size)
    : env_(env),
      stateStringBuffer_(max_string_size == 0 ? DEFAULT_MAX_STRING_SIZE
                                              : max_string_size) {
    stateJavaClass_ = (jclass)env_->NewGlobalRef(
        env_->FindClass("com/google/androidgamesdk/gametextinput/State"));
    inputConnectionClass_ = (jclass)env_->NewGlobalRef(env_->FindClass(
        "com/google/androidgamesdk/gametextinput/InputConnection"));
    inputConnectionSetStateMethod_ =
        env_->GetMethodID(inputConnectionClass_, "setState",
                          "(Lcom/google/androidgamesdk/gametextinput/State;)V");
    setSoftKeyboardActiveMethod_ = env_->GetMethodID(
        inputConnectionClass_, "setSoftKeyboardActive", "(ZI)V");

    stateClassInfo_.text =
        env_->GetFieldID(stateJavaClass_, "text", "Ljava/lang/String;");
    stateClassInfo_.selectionStart =
        env_->GetFieldID(stateJavaClass_, "selectionStart", "I");
    stateClassInfo_.selectionEnd =
        env_->GetFieldID(stateJavaClass_, "selectionEnd", "I");
    stateClassInfo_.composingRegionStart =
        env_->GetFieldID(stateJavaClass_, "composingRegionStart", "I");
    stateClassInfo_.composingRegionEnd =
        env_->GetFieldID(stateJavaClass_, "composingRegionEnd", "I");
}

GameTextInput::~GameTextInput() {
    if (stateJavaClass_ != NULL) {
        env_->DeleteGlobalRef(stateJavaClass_);
        stateJavaClass_ = NULL;
    }
    if (inputConnectionClass_ != NULL) {
        env_->DeleteGlobalRef(inputConnectionClass_);
        inputConnectionClass_ = NULL;
    }
    if (inputConnection_ != NULL) {
        env_->DeleteGlobalRef(inputConnection_);
        inputConnection_ = NULL;
    }
}

void GameTextInput::setState(const GameTextInputState &state) {
    if (inputConnection_ == nullptr) return;
    jobject jstate = stateToJava(state);
    env_->CallVoidMethod(inputConnection_, inputConnectionSetStateMethod_,
                         jstate);
    env_->DeleteLocalRef(jstate);
    setStateInner(state);
}

void GameTextInput::setStateInner(const GameTextInputState &state) {
    // Check if we're setting using our own string (other parts may be
    // different)
    if (state.text_UTF8 == currentState_.text_UTF8) {
        currentState_ = state;
        return;
    }
    // Otherwise, copy across the string.
    auto bytes_needed =
        std::min(static_cast<uint32_t>(state.text_length + 1),
                 static_cast<uint32_t>(stateStringBuffer_.size()));
    currentState_.text_UTF8 = stateStringBuffer_.data();
    std::copy(state.text_UTF8, state.text_UTF8 + bytes_needed - 1,
              stateStringBuffer_.data());
    currentState_.text_length = state.text_length;
    currentState_.selection = state.selection;
    currentState_.composingRegion = state.composingRegion;
    stateStringBuffer_[bytes_needed - 1] = 0;
}

void GameTextInput::setInputConnection(jobject inputConnection) {
    if (inputConnection_ != NULL) {
        env_->DeleteGlobalRef(inputConnection_);
    }
    inputConnection_ = env_->NewGlobalRef(inputConnection);
}

/*static*/ void GameTextInput::processCallback(
    void *context, const GameTextInputState *state) {
    auto thiz = static_cast<GameTextInput *>(context);
    if (state != nullptr) thiz->setStateInner(*state);
}

void GameTextInput::processEvent(jobject textInputEvent) {
    stateFromJava(textInputEvent, processCallback, this);
    if (eventCallback_) {
        eventCallback_(eventCallbackContext_, &currentState_);
    }
}

void GameTextInput::showIme(uint32_t flags) {
    if (inputConnection_ == nullptr) return;
    env_->CallVoidMethod(inputConnection_, setSoftKeyboardActiveMethod_, true,
                         flags);
}

void GameTextInput::setEventCallback(GameTextInputEventCallback callback,
                                     void *context) {
    eventCallback_ = callback;
    eventCallbackContext_ = context;
}

void GameTextInput::setImeInsetsCallback(
    GameTextInputImeInsetsCallback callback, void *context) {
    insetsCallback_ = callback;
    insetsCallbackContext_ = context;
}

void GameTextInput::processImeInsets(const ARect *insets) {
    currentInsets_ = *insets;
    if (insetsCallback_) {
        insetsCallback_(insetsCallbackContext_, &currentInsets_);
    }
}

void GameTextInput::hideIme(uint32_t flags) {
    if (inputConnection_ == nullptr) return;
    env_->CallVoidMethod(inputConnection_, setSoftKeyboardActiveMethod_, false,
                         flags);
}

jobject GameTextInput::stateToJava(const GameTextInputState &state) const {
    static jmethodID constructor = nullptr;
    if (constructor == nullptr) {
        constructor = env_->GetMethodID(stateJavaClass_, "<init>",
                                        "(Ljava/lang/String;IIII)V");
        if (constructor == nullptr) {
            __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                                "Can't find gametextinput.State constructor");
            return nullptr;
        }
    }
    const char *text = state.text_UTF8;
    if (text == nullptr) {
        static char empty_string[] = "";
        text = empty_string;
    }
    // Note that this expects 'modified' UTF-8 which is not the same as UTF-8
    // https://en.wikipedia.org/wiki/UTF-8#Modified_UTF-8
    jstring jtext = env_->NewStringUTF(text);
    jobject jobj =
        env_->NewObject(stateJavaClass_, constructor, jtext,
                        state.selection.start, state.selection.end,
                        state.composingRegion.start, state.composingRegion.end);
    env_->DeleteLocalRef(jtext);
    return jobj;
}

void GameTextInput::stateFromJava(jobject textInputEvent,
                                  GameTextInputGetStateCallback callback,
                                  void *context) const {
    jstring text =
        (jstring)env_->GetObjectField(textInputEvent, stateClassInfo_.text);
    // Note this is 'modified' UTF-8, not true UTF-8. It has no NULLs in it,
    // except at the end. It's actually not specified whether the value returned
    // by GetStringUTFChars includes a null at the end, but it *seems to* on
    // Android.
    const char *text_chars = env_->GetStringUTFChars(text, NULL);
    int text_len = env_->GetStringUTFLength(
        text);  // Length in bytes, *not* including the null.
    int selectionStart =
        env_->GetIntField(textInputEvent, stateClassInfo_.selectionStart);
    int selectionEnd =
        env_->GetIntField(textInputEvent, stateClassInfo_.selectionEnd);
    int composingRegionStart =
        env_->GetIntField(textInputEvent, stateClassInfo_.composingRegionStart);
    int composingRegionEnd =
        env_->GetIntField(textInputEvent, stateClassInfo_.composingRegionEnd);
    GameTextInputState state{text_chars,
                             text_len,
                             {selectionStart, selectionEnd},
                             {composingRegionStart, composingRegionEnd}};
    callback(context, &state);
    env_->ReleaseStringUTFChars(text, text_chars);
    env_->DeleteLocalRef(text);
}
