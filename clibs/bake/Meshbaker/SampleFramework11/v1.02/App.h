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

#include "Window.h"
#include "Graphics\\DeviceManager.h"
#include "Graphics\\DeviceStates.h"
#include "Timer.h"
#include "Graphics\\SpriteFont.h"
#include "Graphics\\SpriteRenderer.h"

namespace SampleFramework11
{

class App
{

public:

    App(const wchar* appName, const wchar* iconResource = NULL);
    virtual ~App();

    int32 Run();

    void RenderText(const std::wstring& text, Float2 pos);
    void RenderCenteredText(const std::wstring& text);

protected:

    virtual void Initialize();
    virtual void Update(const Timer& timer) = 0;
    virtual void Render(const Timer& timer) = 0;

    virtual void BeforeReset();
    virtual void AfterReset();

    void Exit();
    void ToggleFullScreen(bool fullScreen);
    void CalculateFPS();

    static LRESULT OnWindowResized(void* context, HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

    Window window;
    DeviceManager deviceManager;
    Timer timer;

    BlendStates blendStates;
    RasterizerStates rasterizerStates;
    DepthStencilStates depthStencilStates;
    SamplerStates samplerStates;

    SpriteFont font;
    SpriteRenderer spriteRenderer;

    static const uint32 NumTimeDeltaSamples = 64;
    float timeDeltaBuffer[NumTimeDeltaSamples];
    uint32 currentTimeDeltaSample;
    uint32 fps;

    TwBar* tweakBar;

    std::wstring applicationName;
    std::string globalHelpText = "MJPs sample framework for DX11";

    bool createConsole;
    bool showWindow;
    int32 returnCode;

public:

    // Accessors
    Window& Window() { return window; }
    DeviceManager& DeviceManager() { return deviceManager; }
    SpriteFont& Font() { return font; }
    SpriteRenderer& SpriteRenderer() { return spriteRenderer; }
    TwBar* TweakBar() { return tweakBar; }
};

extern App* GlobalApp;

}