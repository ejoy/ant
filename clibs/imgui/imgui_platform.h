#pragma once

void  platformInit(void* window);
void  platformShutdown();
void  platformNewFrame();
void* platformGetHandle(ImGuiViewport* viewport);
