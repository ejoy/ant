#include "backend/imgui_impl_platform.h"

#if defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)

#include <backends/imgui_impl_osx.h>
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

#elif defined(__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__)

#include <imgui.h>
#import <QuartzCore/CAMetalLayer.h>

struct ImGui_ImplIOS_Data {
	CAMetalLayer* Layer;
	ImGui_ImplIOS_Data() { memset(this, 0, sizeof(*this)); }
};

void ImGui_ImplPlatform_Init(void* layer) {
	ImGuiIO& io = ImGui::GetIO();
	ImGui_ImplIOS_Data* bd = IM_NEW(ImGui_ImplIOS_Data)();
	bd->Layer = (__bridge CAMetalLayer*)layer;
	io.BackendPlatformUserData = (void*)bd;
	io.BackendPlatformName = "imgui_impl_ios";
}

void ImGui_ImplPlatform_Shutdown() {
	ImGuiIO& io = ImGui::GetIO();
	ImGui_ImplIOS_Data* bd = (ImGui_ImplIOS_Data*)io.BackendPlatformUserData;
	IM_DELETE(bd);
	io.BackendPlatformUserData = NULL;
}

void ImGui_ImplPlatform_NewFrame() {
	ImGuiIO& io = ImGui::GetIO();
	ImGui_ImplIOS_Data* bd = (ImGui_ImplIOS_Data*)io.BackendPlatformUserData;
	io.DisplaySize = ImVec2(
		(float)bd->Layer.drawableSize.width,
		(float)bd->Layer.drawableSize.height
	);
}

#endif
