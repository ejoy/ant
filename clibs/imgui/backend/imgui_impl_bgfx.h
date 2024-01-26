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

bool ImGui_ImplBgfx_Init(RendererInitArgs& args);
void ImGui_ImplBgfx_Shutdown();
void ImGui_ImplBgfx_RenderDrawData(ImGuiViewport* viewport);
void ImGui_ImplBgfx_CreateFontsTexture();
std::optional<ImTextureID> ImGui_ImplBgfx_GetTextureID(int bgfx_handle);
