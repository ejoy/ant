#include <backends/imgui_impl_osx.h>
#include "backend/imgui_impl_platform.h"
#import <Cocoa/Cocoa.h>

void ImGui_ImplPlatform_Init(void* window) {
	NSWindow* nswindow = (__bridge NSWindow*)window;
	ImGui_ImplOSX_Init(nswindow.contentView);
}

void ImGui_ImplPlatform_Shutdown() {
	ImGui_ImplOSX_Shutdown();
}

void ImGui_ImplPlatform_NewFrame() {
    ImGuiViewport* main_viewport = ImGui::GetMainViewport();
	NSWindow* nswindow = (__bridge NSWindow*)main_viewport->PlatformHandleRaw;
	ImGui_ImplOSX_NewFrame(nswindow.contentView);
}
