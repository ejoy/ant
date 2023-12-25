#include <imgui.h>
#include <oleidl.h>
#include <backends/imgui_impl_win32.h>
#include <memory>
#include "imgui_window.h"
#include "imgui_platform.h"

void* platformGetHandle(ImGuiViewport* viewport) {
	return viewport->PlatformHandle;
}

void platformInit(void* window) {
	ImGui_ImplWin32_Init(window);
}

void platformShutdown() {
	ImGui_ImplWin32_Shutdown();
}

void platformNewFrame() {
	ImGui_ImplWin32_NewFrame();
}
