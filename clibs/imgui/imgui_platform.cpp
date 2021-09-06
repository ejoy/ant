#include <imgui.h>
#include <SDL.h>
#include <SDL_syswm.h>
#include <backends/imgui_impl_sdl.h>
#include "imgui_window.h"
#include "imgui_platform.h"

void* platformCreate(lua_State* L, int w, int h) {
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0) {
		return nullptr;
	}
	SDL_WindowFlags window_flags = (SDL_WindowFlags)(SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI);
	SDL_Window* window = SDL_CreateWindow("ImGui Host Viewport", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, w, h, window_flags);
	if (!window) {
		printf("Couldn't create window: %s\n", SDL_GetError());
		return nullptr;
	}
	SDL_SysWMinfo wmInfo;
	SDL_VERSION(&wmInfo.version);
	SDL_GetWindowWMInfo(window, &wmInfo);
#if defined(SDL_VIDEO_DRIVER_WINDOWS)
	ImGui_ImplSDL2_InitForD3D(window);
	return wmInfo.info.win.window;
#elif defined(SDL_VIDEO_DRIVER_COCOA)
	ImGui_ImplSDL2_InitForMetal(window);
	return wmInfo.info.cocoa.window;
#endif
}

void platformShutdown() {
	ImGui_ImplSDL2_Shutdown();
}

void platformDestroy() {
	SDL_Quit();
}

bool platformNewFrame() {
	SDL_Event event;
	while (SDL_PollEvent(&event)) {
		ImGui_ImplSDL2_ProcessEvent(&event);
		if (event.type == SDL_QUIT) {
			return false;
		}
		if (event.type == SDL_WINDOWEVENT && event.window.windowID == SDL_GetWindowID((SDL_Window*)ImGui::GetMainViewport()->PlatformHandle)) {
			switch (event.window.event) {
			case SDL_WINDOWEVENT_CLOSE:
				return false;
			case SDL_WINDOWEVENT_SIZE_CHANGED:
			case SDL_WINDOWEVENT_RESIZED: {
				struct window_callback* cb = window_get_callback((lua_State*)ImGui::GetIO().UserData);
				window_event_size(cb, event.window.data1, event.window.data2);
				break;
			}
			default:
				break;
			}
		}
	}
	ImGui_ImplSDL2_NewFrame();
	return true;
}
