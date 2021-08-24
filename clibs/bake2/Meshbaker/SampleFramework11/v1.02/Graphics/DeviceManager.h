//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "..\\PCH.h"

#include "..\\InterfacePointers.h"
#include "GraphicsTypes.h"

namespace SampleFramework11
{

class DeviceManager
{

public:

    DeviceManager();
    ~DeviceManager();

    void Initialize(HWND outputWindow);
    void Reset();
    void Present();

    // Getters
    ID3D11Device*               Device() const  { return device.GetInterfacePtr(); };
    ID3D11DeviceContext*        ImmediateContext() const    { return immediateContext.GetInterfacePtr(); };
    IDXGISwapChain*             SwapChain() const   { return swapChain.GetInterfacePtr(); };
    ID3D11RenderTargetView*     BackBuffer() const  { return bbRTView.GetInterfacePtr(); };
    ID3D11Texture2D*            BackBufferTexture() const   { return bbTexture; };
    D3D_FEATURE_LEVEL           FeatureLevel() const    { return featureLevel; };
    D3D_FEATURE_LEVEL           MinFeatureLevel() const     { return minFeatureLevel; };

    DXGI_FORMAT                 BackBufferFormat() const    { return backBufferFormat; };
    uint32                      BackBufferWidth() const     { return backBufferWidth; };
    uint32                      BackBufferHeight() const    { return backBufferHeight; };
    uint32                      BackBufferMSCount() const    { return msCount; };
    uint32                      BackBufferMSQuality() const    { return msQuality; };
    bool                        FullScreen() const   { return fullScreen; };
    bool                        VSYNCEnabled() const    { return vsync; };
    uint32                      NumVSYNCIntervals() const   { return numVSYNCIntervals; };


    // Setters
    void SetBackBufferFormat(DXGI_FORMAT format)    { backBufferFormat = format; };
    void SetBackBufferWidth(uint32 width)   { backBufferWidth = width; };
    void SetBackBufferHeight(uint32 height)     { backBufferHeight = height; };
    void SetBackBufferMSCount(uint32 count)     { msCount = count; };
    void SetBackBufferMSQuality(uint32 quality)     { msQuality = quality; };
    void SetFullScreen(bool enabled)        { fullScreen = enabled; };
    void SetVSYNCEnabled(bool enabled)      { vsync = enabled; };
    void SetMinFeatureLevel(D3D_FEATURE_LEVEL level)    { minFeatureLevel = level; };
    void SetNumVSYNCIntervals(uint32 intervals)     { numVSYNCIntervals = intervals; };

protected:

    void CheckForSuitableOutput();
    void AfterReset();
    void PrepareFullScreenSettings();

    IDXGIFactory1Ptr                factory;
    IDXGIAdapter1Ptr                adapter;
    IDXGIOutputPtr                  output;

    ID3D11DevicePtr                 device;
    ID3D11DeviceContextPtr          immediateContext;
    IDXGISwapChainPtr               swapChain;
    ID3D11Texture2DPtr              bbTexture;
    ID3D11RenderTargetViewPtr       bbRTView;

    DXGI_FORMAT                 backBufferFormat;
    uint32                      backBufferWidth;
    uint32                      backBufferHeight;
    uint32                      msCount;
    uint32                      msQuality;
    bool                        fullScreen;
    bool                        vsync;
    DXGI_RATIONAL               refreshRate;
    uint32                      numVSYNCIntervals;

    D3D_FEATURE_LEVEL           featureLevel;
    D3D_FEATURE_LEVEL           minFeatureLevel;
};

}