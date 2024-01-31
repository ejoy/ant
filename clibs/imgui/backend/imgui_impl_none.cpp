#include <imgui.h>
#include "backend/imgui_impl_platform.h"

void platformInit(void* window) {
}

void platformShutdown() {
}

void platformNewFrame() {
}

void* platformGetHandle(ImGuiViewport* viewport) {
	return nullptr;
}
