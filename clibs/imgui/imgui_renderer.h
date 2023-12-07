#pragma once

#include <imgui.h>
#include <optional>

struct RendererInitArgs {
    int font_prog;
    int image_prog;
    int font_uniform;
    int image_uniform;
};
bool rendererInit(RendererInitArgs const& args);
bool rendererCreate();
void rendererDestroy();
void rendererDrawData(ImGuiViewport* viewport);
void rendererBuildFont();
std::optional<ImTextureID> rendererGetTextureID(int bgfx_handle);
