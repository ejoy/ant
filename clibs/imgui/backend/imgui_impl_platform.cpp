#include "backend/imgui_impl_platform.h"

#if defined(__APPLE__)

#elif defined(_WIN32)

#include <backends/imgui_impl_win32.h>

void ImGui_ImplPlatform_Init(void* window) { ImGui_ImplWin32_Init(window); }
void ImGui_ImplPlatform_Shutdown() { ImGui_ImplWin32_Shutdown(); }
void ImGui_ImplPlatform_NewFrame() { ImGui_ImplWin32_NewFrame(); }

#else

#include <imgui.h>

void ImGui_ImplPlatform_Init(void* window) {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(0.f, 0.f);
}
void ImGui_ImplPlatform_Shutdown() {}
void ImGui_ImplPlatform_NewFrame() {}

#endif
