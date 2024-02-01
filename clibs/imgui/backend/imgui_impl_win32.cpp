#include <imgui.h>
#include <oleidl.h>
#include <backends/imgui_impl_win32.h>
#include <memory>
#include "backend/imgui_impl_platform.h"

void ImGui_ImplPlatform_Init(void* window) {
	ImGui_ImplWin32_Init(window);
}

void ImGui_ImplPlatform_Shutdown() {
	ImGui_ImplWin32_Shutdown();
}

void ImGui_ImplPlatform_NewFrame() {
	ImGui_ImplWin32_NewFrame();
}
