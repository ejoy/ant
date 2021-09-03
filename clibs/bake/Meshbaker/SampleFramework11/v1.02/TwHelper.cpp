//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"
#include "TwHelper.h"
#include "Utility.h"

namespace SampleFramework11
{

namespace TwHelper
{

// Variable parameters
void SetLabel(TwBar* bar, const char* varName, const char* label)
{
    TwCall(TwSetParam(bar, varName, "label", TW_PARAM_CSTRING, 1, label));
}

void SetHelpText(TwBar* bar, const char* varName, const char* helpText)
{
    TwCall(TwSetParam(bar, varName, "help", TW_PARAM_CSTRING, 1, helpText));
}

void SetGroup(TwBar* bar, const char* varName, const char* group)
{
    TwCall(TwSetParam(bar, varName, "group", TW_PARAM_CSTRING, 1, group));
}

void SetVisible(TwBar* bar, const char* varName, bool32 visible)
{
    TwCall(TwSetParam(bar, varName, "visible", TW_PARAM_INT32, 1, &visible));
}

void SetReadOnly(TwBar* bar, const char* varName, bool32 readOnly)
{
    TwCall(TwSetParam(bar, varName, "readonly", TW_PARAM_INT32, 1, &readOnly));
}

void SetMinMax(TwBar* bar, const char* varName, float min, float max)
{
    TwCall(TwSetParam(bar, varName, "min", TW_PARAM_FLOAT, 1, &min));
    TwCall(TwSetParam(bar, varName, "max", TW_PARAM_FLOAT, 1, &max));
}

void SetMinMax(TwBar* bar, const char* varName, int32 min, int32 max)
{
    TwCall(TwSetParam(bar, varName, "min", TW_PARAM_INT32, 1, &min));
    TwCall(TwSetParam(bar, varName, "max", TW_PARAM_INT32, 1, &max));
}

void SetStep(TwBar* bar, const char* varName, float step)
{
    TwCall(TwSetParam(bar, varName, "step", TW_PARAM_FLOAT, 1, &step));
}

void SetPrecision(TwBar* bar, const char* varName, int32 precision)
{
    TwCall(TwSetParam(bar, varName, "precision", TW_PARAM_INT32, 1, &precision));
}

void SetHexidecimal(TwBar* bar, const char* varName, bool32 hex)
{
    TwCall(TwSetParam(bar, varName, "hexa", TW_PARAM_INT32, 1, &hex));
}

void SetShortcutKey(TwBar* bar, const char* varName, const char* shortcutKey)
{
    TwCall(TwSetParam(bar, varName, "key", TW_PARAM_CSTRING, 1, shortcutKey));
}

void SetShortcutKeyIncrement(TwBar* bar, const char* varName, const char* shortcutKey)
{
    TwCall(TwSetParam(bar, varName, "keyincr", TW_PARAM_CSTRING, 1, shortcutKey));
}

void SetShortcutKeyDecrement(TwBar* bar, const char* varName, const char* shortcutKey)
{
    TwCall(TwSetParam(bar, varName, "keydecr", TW_PARAM_CSTRING, 1, shortcutKey));
}

void SetBoolLabels(TwBar* bar, const char* varName, const char* falseLabel, const char* trueLabel)
{
    TwCall(TwSetParam(bar, varName, "false", TW_PARAM_CSTRING, 1, falseLabel));
    TwCall(TwSetParam(bar, varName, "true", TW_PARAM_CSTRING, 1, trueLabel));
}

void SetUseAlphaChannel(TwBar* bar, const char* varName, bool32 useAlpha)
{
    TwCall(TwSetParam(bar, varName, "coloralpha", TW_PARAM_INT32, 1, &useAlpha));
}

void SetColorOrder(TwBar* bar, const char* varName, ColorOrder order)
{
    static const char* ColorOrderStrings[] = { "rgba", "bgra" };
    TwCall(TwSetParam(bar, varName, "colororder", TW_PARAM_CSTRING, 1, ColorOrderStrings[uint64(order)]));
}

void SetColorMode(TwBar* bar, const char* varName, ColorMode mode)
{
    static const char* ColorModeStrings[] = { "rgb", "hls" };
    TwCall(TwSetParam(bar, varName, "colormode", TW_PARAM_CSTRING, 1, ColorModeStrings[uint64(mode)]));
}

void SetUseArrowMode(TwBar* bar, const char* varName, bool32 useArrowMode, Float3 initialDirection)
{
    if(useArrowMode)
    {
        std::string dirString = "'" + ToAnsiString(initialDirection.x) + " " + ToAnsiString(initialDirection.y)
                                + " " + ToAnsiString(initialDirection.z) + "'";
        TwCall(TwSetParam(bar, varName, "arrow", TW_PARAM_CSTRING, 1, dirString.c_str()));
    }
    else
        TwCall(TwSetParam(bar, varName, "arrow", TW_PARAM_CSTRING, 1, "0"));
}

void SetArrowColor(TwBar* bar, const char* varName, Float3 color)
{
    int32 rgb[3] = { int32(Saturate(color.x) * 255.0f),
                     int32(Saturate(color.y) * 255.0f),
                     int32(Saturate(color.z) * 255.0f) };
    TwCall(TwSetParam(bar, varName, "arrowcolor", TW_PARAM_INT32, 3, rgb));
}

void SetAxisMapping(TwBar* bar, const char* varName, Axis xAxis, Axis yAxis, Axis zAxis)
{
    static const char* AxisStrings[] = { "x", "-x", "y", "-y", "z", "-z" };
    TwCall(TwSetParam(bar, varName, "axisx", TW_PARAM_CSTRING, 1, AxisStrings[uint64(xAxis)]));
    TwCall(TwSetParam(bar, varName, "axisy", TW_PARAM_CSTRING, 1, AxisStrings[uint64(yAxis)]));
    TwCall(TwSetParam(bar, varName, "axisz", TW_PARAM_CSTRING, 1, AxisStrings[uint64(zAxis)]));
}

void SetShowNumericalValue(TwBar* bar, const char* varName, bool32 showValue)
{
    TwCall(TwSetParam(bar, varName, "showval", TW_PARAM_INT32, 1, &showValue));
}


// TweakBar parameters
void SetLabel(TwBar* bar, const char* label)
{
    SetLabel(bar, nullptr, label);
}

void SetHelpText(TwBar* bar, const char* helpText)
{
    SetHelpText(bar, nullptr, helpText);
}

void SetColor(TwBar* bar, Float3 color)
{
    int32 rgb[3] = { int32(Saturate(color.x) * 255.0f),
                     int32(Saturate(color.y) * 255.0f),
                     int32(Saturate(color.z) * 255.0f) };
    TwCall(TwSetParam(bar, nullptr, "color", TW_PARAM_INT32, 3, rgb));
}

void SetAlpha(TwBar* bar, float alpha)
{
    int32 a = int32(Saturate(alpha));
    TwCall(TwSetParam(bar, nullptr, "alpha", TW_PARAM_INT32, 1, &a));
}

void SetTextMode(TwBar* bar, TextMode textMode)
{
    static const char* TextModeStrings[] = { "dark", "light" };
    TwCall(TwSetParam(bar, nullptr, "text", TW_PARAM_CSTRING, 1, TextModeStrings[uint64(textMode)]));
}

void SetPosition(TwBar* bar, int32 posX, int32 posY)
{
    int32 positions[2] = { posX, posY };
    TwCall(TwSetParam(bar, nullptr, "position", TW_PARAM_INT32, 2, positions));
}

void SetSize(TwBar* bar, int32 sizeX, int32 sizeY)
{
    int32 sizes[2] = { sizeX, sizeY};
    TwCall(TwSetParam(bar, nullptr, "size", TW_PARAM_INT32, 2, sizes));
}

void SetValuesWidth(TwBar* bar, int32 width, bool32 fit)
{
    if(fit)
        TwCall(TwSetParam(bar, nullptr, "valueswidth", TW_PARAM_CSTRING, 1, "fit"));
    else
        TwCall(TwSetParam(bar, nullptr, "valueswidth", TW_PARAM_INT32, 1, &width));
}

void SetRefreshRate(TwBar* bar, float rate)
{
    TwCall(TwSetParam(bar, nullptr, "refresh", TW_PARAM_FLOAT, 1, &rate));
}

void SetVisible(TwBar* bar, bool32 visible)
{
    SetVisible(bar, nullptr, visible);
}

void SetIconified(TwBar* bar, bool32 iconified)
{
    TwCall(TwSetParam(bar, nullptr, "iconified", TW_PARAM_INT32, 1, &iconified));
}

void SetIconifiable(TwBar* bar, bool32 iconifiable)
{
    TwCall(TwSetParam(bar, nullptr, "iconifiable", TW_PARAM_INT32, 1, &iconifiable));
}

void SetMovable(TwBar* bar, bool32 movable)
{
    TwCall(TwSetParam(bar, nullptr, "movable", TW_PARAM_INT32, 1, &movable));
}

void SetResizable(TwBar* bar, bool32 resizable)
{
    TwCall(TwSetParam(bar, nullptr, "resizable", TW_PARAM_INT32, 1, &resizable));
}

void SetAlwaysOnTop(TwBar* bar, bool32 alwaysOnTop)
{
    TwCall(TwSetParam(bar, nullptr, "alwaystop", TW_PARAM_INT32, 1, &alwaysOnTop));
}

void SetAlwaysOnBottom(TwBar* bar, bool32 alwaysOnBottom)
{
    TwCall(TwSetParam(bar, nullptr, "alwaysbottom", TW_PARAM_INT32, 1, &alwaysOnBottom));
}

void SetContained(TwBar* bar, bool32 contained)
{
    TwCall(TwSetParam(bar, nullptr, "contained", TW_PARAM_INT32, 1, &contained));
}

void SetButtonAlignment(TwBar* bar, ButtonAlignment alignment)
{
    static const char* ButtonAlignmentStrings[] = { "left", "center", "right" };
    TwCall(TwSetParam(bar, nullptr, "buttonalign", TW_PARAM_CSTRING, 1, ButtonAlignmentStrings[uint64(alignment)]));
}


// Group parameters
void SetOpened(TwBar* bar, const char* groupName, bool32 opened)
{
    TwCall(TwSetParam(bar, groupName, "opened", TW_PARAM_INT32, 1, &opened));
}


// Global parameters
void SetGlobalHelpText(const char* helpText)
{
    SetHelpText(nullptr, helpText);
}

void SetIconPosition(IconPosition position)
{
    static const char* IconPositionStrings[] = { "topleft", "topright", "bottomleft", "bottomright" };
    TwCall(TwSetParam(nullptr, nullptr, "iconpos", TW_PARAM_CSTRING, 1, IconPositionStrings[uint64(position)]));
}

void SetIconAlignment(IconAlignment alignment)
{
    static const char* IconAlignmentStrings[] = { "vertical", "horizontal" };
    TwCall(TwSetParam(nullptr, nullptr, "iconalign", TW_PARAM_CSTRING, 1, IconAlignmentStrings[uint64(alignment)]));
}

void SetIconMargin(int32 marginX, int32 marginY)
{
    int32 margins[2] = { marginX, marginY };
    TwCall(TwSetParam(nullptr, nullptr, "iconmargin", TW_PARAM_INT32, 2, margins));
}

void SetFontSize(FontSize size)
{
    int32 fontSize[1] = { int32(size) };
    TwCall(TwSetParam(nullptr, nullptr, "fontsize", TW_PARAM_INT32, 1, fontSize));
}

void SetFontStyle(FontStyle style)
{
    static const char* FontStyleStrings[] = { "default", "fixed" };
    TwCall(TwSetParam(nullptr, nullptr, "fontstyle", TW_PARAM_CSTRING, 1, FontStyleStrings[uint64(style)]));
}

void SetFontResizable(bool32 resizable)
{
    TwCall(TwSetParam(nullptr, nullptr, "fontresizable", TW_PARAM_INT32, 1, &resizable));
}

void SetFontScaling(float scale)
{
    TwCall(TwSetParam(nullptr, nullptr, "fontscaling", TW_PARAM_FLOAT, 1, &scale));
}

void SetDrawOverlappedBars(bool32 drawOverlapped)
{
    TwCall(TwSetParam(nullptr, nullptr, "overlap", TW_PARAM_INT32, 1, &drawOverlapped));
}

void SetButtonAlignment(ButtonAlignment alignment)
{
    SetButtonAlignment(nullptr, alignment);
}

}

}