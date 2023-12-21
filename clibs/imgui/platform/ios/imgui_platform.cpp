#include <imgui.h>
#include "imgui_window.h"
#include "imgui_platform.h"

void platformInit(void* window) {
}

void platformShutdown() {
}

void platformNewFrame() {
}

void* platformGetHandle(ImGuiViewport* viewport) {
	return nullptr;
}
