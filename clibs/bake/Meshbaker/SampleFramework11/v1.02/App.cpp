
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "App.h"
#include "Exceptions.h"
#include "Graphics\\Profiler.h"
#include "Graphics\\Spectrum.h"
#include "SF11_Math.h"
#include "FileIO.h"
#include "Settings.h"
#include "TwHelper.h"

// AppSettings framework
namespace AppSettings
{
    void Initialize(ID3D11Device* device);
    void Update();
    void UpdateCBuffer(ID3D11DeviceContext* context);
}

namespace SampleFramework11
{

App* GlobalApp = nullptr;

App::App(const wchar* appName, const wchar* iconResource) :   window(NULL, appName, WS_OVERLAPPEDWINDOW,
                                                                     WS_EX_APPWINDOW, 1280, 720, iconResource, iconResource),
                                                              currentTimeDeltaSample(0),
                                                              fps(0), tweakBar(nullptr), applicationName(appName),
                                                              createConsole(true), showWindow(true), returnCode(0)
{
    GlobalApp = this;
    for(uint32 i = 0; i < NumTimeDeltaSamples; ++i)
        timeDeltaBuffer[i] = 0;

    SampledSpectrum::Init();
}

App::~App()
{

}

int32 App::Run()
{
    try
    {
        if(createConsole)
        {
            Win32Call(AllocConsole());
            Win32Call(SetConsoleTitle(applicationName.c_str()));
            FILE* consoleFile = nullptr;
            freopen_s(&consoleFile, "CONOUT$", "wb", stdout);
        }

        window.SetClientArea(deviceManager.BackBufferWidth(), deviceManager.BackBufferHeight());
        deviceManager.Initialize(window);

        if(showWindow)
            window.ShowWindow();

        blendStates.Initialize(deviceManager.Device());
        rasterizerStates.Initialize(deviceManager.Device());
        depthStencilStates.Initialize(deviceManager.Device());
        samplerStates.Initialize(deviceManager.Device());

        // Create a font + SpriteRenderer
        font.Initialize(L"Arial", 18, SpriteFont::Regular, true, deviceManager.Device());
        spriteRenderer.Initialize(deviceManager.Device());

        Profiler::GlobalProfiler.Initialize(deviceManager.Device(), deviceManager.ImmediateContext());

        window.RegisterMessageCallback(WM_SIZE, OnWindowResized, this);

        // Initialize AntTweakBar
        TwCall(TwInit(TW_DIRECT3D11, deviceManager.Device()));

        // Create a tweak bar
        tweakBar = TwNewBar("Settings");
        std::string helpTextDefinition = MakeAnsiString(" GLOBAL help='%s' ", globalHelpText.c_str());
        TwCall(TwDefine(helpTextDefinition.c_str()));
        TwCall(TwDefine(" GLOBAL fontsize=3 "));

        Settings.Initialize(tweakBar);

        TwHelper::SetValuesWidth(Settings.TweakBar(), 120, false);

        AppSettings::Initialize(deviceManager.Device());

        Initialize();

        AfterReset();

        while(window.IsAlive())
        {
            if(!window.IsMinimized())
            {
                timer.Update();
                Settings.Update();

                CalculateFPS();

                AppSettings::Update();

                Update(timer);

                UpdateShaders(deviceManager.Device());

                AppSettings::UpdateCBuffer(deviceManager.ImmediateContext());

                Render(timer);

                // Render the profiler text
                spriteRenderer.Begin(deviceManager.ImmediateContext(), SpriteRenderer::Point);
                Profiler::GlobalProfiler.EndFrame(spriteRenderer, font);
                spriteRenderer.End();

                {
                    PIXEvent pixEvent(L"Ant Tweak Bar");

                    // Render the TweakBar UI
                    TwCall(TwDraw());
                }

                deviceManager.Present();
            }

            window.MessageLoop();
        }
    }
    catch(SampleFramework11::Exception exception)
    {
        exception.ShowErrorMessage();
        return -1;
    }

    ShutdownShaders();

    TwCall(TwTerminate());

    if(createConsole)
    {
        fclose(stdout);
        FreeConsole();
    }

    return returnCode;
}

void App::CalculateFPS()
{
    timeDeltaBuffer[currentTimeDeltaSample] = timer.DeltaSecondsF();
    currentTimeDeltaSample = (currentTimeDeltaSample + 1) % NumTimeDeltaSamples;

    float averageDelta = 0;
    for(UINT i = 0; i < NumTimeDeltaSamples; ++i)
        averageDelta += timeDeltaBuffer[i];
    averageDelta /= NumTimeDeltaSamples;

    fps = static_cast<UINT>(std::floor((1.0f / averageDelta) + 0.5f));
}

LRESULT App::OnWindowResized(void* context, HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    App* app = reinterpret_cast<App*>(context);

    if(!app->deviceManager.FullScreen() && wParam != SIZE_MINIMIZED)
    {
        int width, height;
        app->window.GetClientArea(width, height);

        if(width != app->deviceManager.BackBufferWidth() || height != app->deviceManager.BackBufferHeight())
        {
            app->BeforeReset();

            app->deviceManager.SetBackBufferWidth(width);
            app->deviceManager.SetBackBufferHeight(height);
            app->deviceManager.Reset();

            app->AfterReset();
        }
    }

    return 0;
}

void App::Exit()
{
    window.Destroy();
}

void App::Initialize()
{
}

void App::BeforeReset()
{
}

void App::AfterReset()
{
    const uint32 width = deviceManager.BackBufferWidth();
    const uint32 height = deviceManager.BackBufferHeight();

    TwHelper::SetSize(tweakBar, 375, deviceManager.BackBufferHeight());
    TwHelper::SetPosition(tweakBar, deviceManager.BackBufferWidth() - 375, 0);
}

void App::ToggleFullScreen(bool fullScreen)
{
    if(fullScreen != deviceManager.FullScreen())
    {
        BeforeReset();

        deviceManager.SetFullScreen(fullScreen);
        deviceManager.Reset();

        AfterReset();
    }
}

void App::RenderText(const std::wstring& text, Float2 pos)
{
    ID3D11DeviceContext* context = deviceManager.ImmediateContext();

    // Set the backbuffer and viewport
    ID3D11RenderTargetView* rtvs[1] = { deviceManager.BackBuffer() };
    context->OMSetRenderTargets(1, rtvs, NULL);

    float clearColor[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
    context->ClearRenderTargetView(rtvs[0], clearColor);

    SetViewport(context, deviceManager.BackBufferWidth(), deviceManager.BackBufferHeight());

    // Draw the text
    Float4x4 transform;
    transform.SetTranslation(Float3(pos.x, pos.y,0.0f));
    spriteRenderer.Begin(context, SpriteRenderer::Point);
    spriteRenderer.RenderText(font, text.c_str(), transform.ToSIMD());
    spriteRenderer.End();

    // Present
    deviceManager.SwapChain()->Present(0, 0);

    // Pump the message loop
    window.MessageLoop();
}

void App::RenderCenteredText(const std::wstring& text)
{

    // Measure the text
    Float2 textSize = font.MeasureText(text.c_str());

    // Position it in the middle
    Float2 textPos;
    textPos.x = Round((deviceManager.BackBufferWidth() / 2.0f) - (textSize.x / 2.0f));
    textPos.y = Round((deviceManager.BackBufferHeight() / 2.0f) - (textSize.y / 2.0f));

    RenderText(text, textPos);
}

}