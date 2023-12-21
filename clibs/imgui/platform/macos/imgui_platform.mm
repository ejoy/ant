#include <imgui.h>
#include <backends/imgui_impl_osx.h>
#include "imgui_window.h"
#include "imgui_platform.h"
#import <Cocoa/Cocoa.h>

void* platformCreateMainWindow(int w, int h) {
	return nullptr;
}

void platformDestroyMainWindow() {
}

bool platformDispatchMessage() {
	return false;
}

void platformInit(void* window) {
	NSWindow* nswindow = (__bridge NSWindow*)window;
	ImGui_ImplOSX_Init(nswindow.contentView);
}

void platformShutdown() {
	ImGui_ImplOSX_Shutdown();
}

void platformNewFrame() {
    ImGuiViewport* main_viewport = ImGui::GetMainViewport();
	NSWindow* nswindow = (__bridge NSWindow*)main_viewport->PlatformHandleRaw;
	ImGui_ImplOSX_NewFrame(nswindow.contentView);
}

void* platformGetHandle(ImGuiViewport* viewport) {
	return viewport->PlatformHandleRaw;
}
