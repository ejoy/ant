#include <imgui.h>
#include "imgui_window.h"
#include "imgui_platform.h"

void* platformCreateMainWindow(int w, int h) {
	return nullptr;
}

void platformDestroyMainWindow() {
}

bool platformDispatchMessage() {
	return false;
}

void platformInit(void* window) {
}

void platformShutdown() {
}

void platformNewFrame() {
}

void* platformGetHandle(ImGuiViewport* viewport) {
	return nullptr;
}
