#pragma once

void* platformCreateMainWindow(int w, int h);
void  platformDestroyMainWindow();
bool  platformDispatchMessage();
void  platformInit(void* window);
void  platformShutdown();
void  platformNewFrame();
void* platformGetHandle(ImGuiViewport* viewport);
