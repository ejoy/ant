//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "PCH.h"
#include "Exceptions.h"
#include "SF11_Math.h"

namespace SampleFramework11
{

namespace TwHelper
{

enum class ColorOrder
{
    RGBA,
    ARGB,
};

enum class ColorMode
{
    RGB,
    HLS,
};

enum class Axis
{
    PositiveX,
    NegativeX,
    PositiveY,
    NegativeY,
    PositiveZ,
    NegativeZ,
};

enum class TextMode
{
    Light,
    Dark,
};

enum class IconPosition
{
    TopLeft,
    TopRight,
    BottomLeft,
    BottomRight,
};

enum class IconAlignment
{
    Vertical,
    Horizontal,
};

enum class FontSize
{
    Small = 0,
    Medium = 1,
    Large = 2,
};

enum class FontStyle
{
    Default,
    Fixed,
};

enum class ButtonAlignment
{
    Left,
    Center,
    Right,
};

// Helper functions for AntTweakBar

// Variable parameters
void SetLabel(TwBar* bar, const char* varName, const char* label);
void SetHelpText(TwBar* bar, const char* varName, const char* helpText);
void SetGroup(TwBar* bar, const char* varName, const char* group);
void SetVisible(TwBar* bar, const char* varName, bool32 visible);
void SetReadOnly(TwBar* bar, const char* varName, bool32 readOnly);
void SetMinMax(TwBar* bar, const char* varName, float min, float max);
void SetMinMax(TwBar* bar, const char* varName, int32 min, int32 max);
void SetStep(TwBar* bar, const char* varName, float step);
void SetPrecision(TwBar* bar, const char* varName, int32 precision);
void SetHexidecimal(TwBar* bar, const char* varName, bool32 hex);
void SetShortcutKey(TwBar* bar, const char* varName, const char* shortcutKey);
void SetShortcutKeyIncrement(TwBar* bar, const char* varName, const char* shortcutKey);
void SetShortcutKeyDecrement(TwBar* bar, const char* varName, const char* shortcutKey);
void SetBoolLabels(TwBar* bar, const char* varName, const char* falseLabel, const char* trueLabel);
void SetUseAlphaChannel(TwBar* bar, const char* varName, bool32 useAlpha);
void SetColorOrder(TwBar* bar, const char* varName, ColorOrder order);
void SetColorMode(TwBar* bar, const char* varName, ColorMode mode);
void SetUseArrowMode(TwBar* bar, const char* varName, bool32 useArrowMode, Float3 initialDirection);
void SetArrowColor(TwBar* bar, const char* varName, Float3 color);
void SetAxisMapping(TwBar* bar, const char* varName, Axis xAxis, Axis yAxis, Axis zAxis);
void SetShowNumericalValue(TwBar* bar, const char* varName, bool32 showValue);

// TweakBar parameters
void SetLabel(TwBar* bar, const char* label);
void SetHelpText(TwBar* bar, const char* helpText);
void SetColor(TwBar* bar, Float3 color);
void SetAlpha(TwBar* bar, float alpha);
void SetTextMode(TwBar* bar, TextMode textMode);
void SetPosition(TwBar* bar, int32 posX, int32 posY);
void SetSize(TwBar* bar, int32 sizeX, int32 sizeY);
void SetValuesWidth(TwBar* bar, int32 width, bool32 fit);
void SetRefreshRate(TwBar* bar, float rate);
void SetVisible(TwBar* bar, bool32 visible);
void SetIconified(TwBar* bar, bool32 iconified);
void SetIconifiable(TwBar* bar, bool32 iconifiable);
void SetMovable(TwBar* bar, bool32 movable);
void SetResizable(TwBar* bar, bool32 resizable);
void SetAlwaysOnTop(TwBar* bar, bool32 alwaysOnTop);
void SetAlwaysOnBottom(TwBar* bar, bool32 alwaysOnBottom);
void SetContained(TwBar* bar, bool32 contained);
void SetButtonAlignment(TwBar* bar, ButtonAlignment alignment);

// Group parameters
void SetOpened(TwBar* bar, const char* groupName, bool32 opened);

// Global parameters
void SetGlobalHelpText(const char* helpText);
void SetIconPosition(IconPosition position);
void SetIconAlignment(IconAlignment alignment);
void SetIconMargin(int32 marginX, int32 marginY);
void SetFontSize(FontSize size);
void SetFontStyle(FontStyle style);
void SetFontResizable(bool32 resizable);
void SetFontScaling(float scale);
void SetDrawOverlappedBars(bool32 drawOverlapped);
void SetButtonAlignment(ButtonAlignment alignment);

}

}