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
 * @defgroup game_common Game Common
 * Common structures and functions used within AGDK
 * @{
 */

#pragma once

/**
 * The type of a component for which to retrieve insets. See
 * https://developer.android.com/reference/androidx/core/view/WindowInsetsCompat.Type
 */
typedef enum GameCommonInsetsType {
    GAMECOMMON_INSETS_TYPE_CAPTION_BAR = 0,
    GAMECOMMON_INSETS_TYPE_DISPLAY_CUTOUT,
    GAMECOMMON_INSETS_TYPE_IME,
    GAMECOMMON_INSETS_TYPE_MANDATORY_SYSTEM_GESTURES,
    GAMECOMMON_INSETS_TYPE_NAVIGATION_BARS,
    GAMECOMMON_INSETS_TYPE_STATUS_BARS,
    GAMECOMMON_INSETS_TYPE_SYSTEM_BARS,
    GAMECOMMON_INSETS_TYPE_SYSTEM_GESTURES,
    GAMECOMMON_INSETS_TYPE_TAPABLE_ELEMENT,
    GAMECOMMON_INSETS_TYPE_WATERFALL,
    GAMECOMMON_INSETS_TYPE_COUNT
} GameCommonInsetsType;
