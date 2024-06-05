#include "backend/imgui_impl_platform.h"

#if defined(__APPLE__)

#elif defined(_WIN32)

#include <backends/imgui_impl_win32.h>

void ImGui_ImplPlatform_Init(void* window) { ImGui_ImplWin32_Init(window); }
void ImGui_ImplPlatform_Shutdown() { ImGui_ImplWin32_Shutdown(); }
void ImGui_ImplPlatform_NewFrame() { ImGui_ImplWin32_NewFrame(); }

#elif defined(__linux__)
#include "imgui_impl_x11.h"

void ImGui_ImplPlatform_Init(void* ctx) { ImGui_ImplX11_Init(ctx); }
void ImGui_ImplPlatform_Shutdown() { ImGui_ImplX11_Shutdown(); }
void ImGui_ImplPlatform_NewFrame() { ImGui_ImplX11_NewFrame(); }

#else
#include <imgui.h>
void ImGui_ImplPlatform_Init(void* window) {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(0.f, 0.f);
}
void ImGui_ImplPlatform_Shutdown() {}
void ImGui_ImplPlatform_NewFrame() {}

#endif
