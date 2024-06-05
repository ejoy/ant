#include "backend/imgui_impl_platform.h"
#include "backend/imgui_impl_x11.h"
#include <imgui.h>
#include <cstdio>

static int64_t getLinuxHPCounter()
{
    struct timeval now;
    gettimeofday(&now, 0);
    int64_t i64 = now.tv_sec * INT64_C(1000000) + now.tv_usec;
    return i64;
}

static int64_t getLinuxHPFrequency()
{
    return INT64_C(1000000);
}

static WindowContext* ImGui_ImplX11_GetBackendData()
{
    return ImGui::GetCurrentContext() ? (WindowContext*)ImGui::GetIO().BackendPlatformUserData : nullptr;
}

void ImGui_ImplX11_Init(void *ctx)
{
    WindowContext *win_ctx = (WindowContext *)ctx;
    ImGuiIO& io = ImGui::GetIO();
    IM_ASSERT(io.BackendPlatformUserData == nullptr && "Already initialized a platform backend!");

    auto perf_frequency = getLinuxHPFrequency();
    auto perf_counter = getLinuxHPCounter();
    
    // Setup backend capabilities flags
    WindowContext* bd = IM_NEW(WindowContext)();
    io.BackendPlatformUserData = (void*)bd;
    io.BackendPlatformName = "imgui_impl_x11";
    io.BackendFlags |= ImGuiBackendFlags_HasMouseCursors;
    
    bd->dpy = win_ctx->dpy;
    bd->window = win_ctx->window;
    bd->screen =  win_ctx->screen;
    bd->gc = win_ctx->gc;
    bd->ticks_per_sec = perf_frequency;
    bd->time = perf_counter;

    ImGuiViewport* main_viewport = ImGui::GetMainViewport();
    main_viewport->PlatformHandle = main_viewport->PlatformHandleRaw = (void *)(uintptr_t)(win_ctx->window);
    
}
void ImGui_ImplX11_Shutdown() 
{
    WindowContext* bd = ImGui_ImplX11_GetBackendData();
    IM_ASSERT(bd != nullptr && "No platform backend to shutdown, or already shutdown?");
    ImGuiIO& io = ImGui::GetIO();
    io.BackendPlatformName = nullptr;
    io.BackendPlatformUserData = nullptr;
    io.BackendFlags &= ~(ImGuiBackendFlags_HasMouseCursors);
    IM_DELETE(bd);

}

void ImGui_ImplX11_NewFrame() 
{
    WindowContext* bd = ImGui_ImplX11_GetBackendData();
    IM_ASSERT(bd != nullptr && "Context or backend not initialized? Did you call ImGui_ImplX11_Init()?");
    ImGuiIO& io = ImGui::GetIO();

    int x, y;
    unsigned int w = 0, h = 0, border_width, depth;
    Window root;
    XGetGeometry(bd->dpy, bd->window, &root, &x, &y, &w, &h, &border_width, &depth);

    io.DisplaySize = ImVec2((float)(w), (float)(h));
    auto current_time = getLinuxHPCounter();
    io.DeltaTime = (float)(current_time - bd->time) / bd->ticks_per_sec;
    bd->time = current_time;
}
