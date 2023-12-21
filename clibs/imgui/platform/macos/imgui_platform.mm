#include <imgui.h>
#include <SDL.h>
#include <SDL_syswm.h>
#include <backends/imgui_impl_sdl2.h>
#include "imgui_window.h"
#include "imgui_platform.h"
#include <stdio.h>

void* platformCreateMainWindow(int w, int h) {
	SDL_WindowFlags window_flags = (SDL_WindowFlags)(SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI);
	SDL_Window* window = SDL_CreateWindow("ImGui Host Viewport", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, w, h, window_flags);
	if (!window) {
		printf("Couldn't create window: %s\n", SDL_GetError());
		return nullptr;
	}
	SDL_SysWMinfo wmInfo;
	SDL_VERSION(&wmInfo.version);
	SDL_GetWindowWMInfo(window, &wmInfo);
	return window;
}

void platformDestroyMainWindow() {
}

bool platformDispatchMessage() {
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
				window_event_size(event.window.data1, event.window.data2);
				break;
			}
			default:
				break;
			}
		}
	}
	return true;
}

void platformInit(void* window) {
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0) {
		return;
	}
#if defined(SDL_VIDEO_DRIVER_WINDOWS)
	ImGui_ImplSDL2_InitForD3D((SDL_Window*)window);
#elif defined(SDL_VIDEO_DRIVER_COCOA)
	ImGui_ImplSDL2_InitForMetal((SDL_Window*)window);
#endif
}

void platformShutdown() {
	ImGui_ImplSDL2_Shutdown();
	SDL_Quit();
}

void platformNewFrame() {
	ImGui_ImplSDL2_NewFrame();
}

#if defined(SDL_VIDEO_DRIVER_COCOA)

#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Cocoa/Cocoa.h>

void* setupMetalLayer(void *wnd) {
    NSWindow *window = (NSWindow*)wnd;
    NSView *contentView = [window contentView];
    [contentView setWantsLayer:YES];
    CAMetalLayer *res = [CAMetalLayer layer];
    [contentView setLayer:res];
    return res;
}

#endif

void* platformGetHandle(ImGuiViewport* viewport) {
	SDL_Window* window = (SDL_Window*)viewport->PlatformHandle;
	SDL_SysWMinfo wmInfo;
	SDL_VERSION(&wmInfo.version);
	SDL_GetWindowWMInfo(window, &wmInfo);
#if defined(SDL_VIDEO_DRIVER_WINDOWS)
	return wmInfo.info.win.window;
#elif defined(SDL_VIDEO_DRIVER_COCOA)
	return setupMetalLayer(wmInfo.info.cocoa.window);
#endif
}
