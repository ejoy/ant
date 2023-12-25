#pragma once

#include <imgui.h>
#include <optional>
#include <vector>

struct RendererInitArgs {
    int fontProg;
    int imageProg;
    int fontUniform;
    int imageUniform;
    std::vector<int> viewIdPool;
};

bool rendererCreate(RendererInitArgs& args);
void rendererDestroy();
void rendererDrawData(ImGuiViewport* viewport);
void rendererBuildFont();
std::optional<ImTextureID> rendererGetTextureID(int bgfx_handle);
