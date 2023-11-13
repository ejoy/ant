#pragma once
#include "imgui.h"
namespace ImGui {
	bool SelectableInput(const char* str_id, bool selected, ImGuiSelectableFlags flags, char* buf, size_t buf_size);
}