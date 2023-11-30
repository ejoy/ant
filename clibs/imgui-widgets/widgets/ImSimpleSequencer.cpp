#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif

#include "ImSimpleSequencer.h"
#include "imgui.h"
#include "imgui_internal.h"
#include <cstdlib>
#include <algorithm>
#include <string>
#include <unordered_map>

namespace ImSimpleSequencer
{
	int anim_fps = 50;
	anim_layer* current_layer{ nullptr };
	bone_anim_s bone_anim;
	int ItemHeight = 20;

	int GetFrameMin() { return 0; }
	int GetFrameMax() { return (int)std::ceil(bone_anim.duration * anim_fps) - 1; }

#ifndef IMGUI_DEFINE_MATH_OPERATORS
	static ImVec2 operator+(const ImVec2& a, const ImVec2& b) { return ImVec2(a.x + b.x, a.y + b.y); }
#endif

	void SimpleSequencer(bool& pause, int& selected_layer, int& current_frame, int& selected_frame, int& move_type, int& range_index, int& move_delta)
	{
		static int firstFrame = 0;
		static float framePixelWidth = 10.f;
		static float framePixelWidthTarget = 10.f;
		static bool inited = false;
		if (!inited) {
			inited = true;
			auto viewport = ImGui::GetMainViewport();
			auto scale = viewport->DpiScale;
			ItemHeight = (int)(ItemHeight * scale);
			framePixelWidth *= scale;
			framePixelWidthTarget *= scale;
		}
		static bool movingEntry = false;
		static int movingPos = -1;
		static int movingPart = -1;

		ImGuiIO& io = ImGui::GetIO();
		const int cx = (int)(io.MousePos.x);

		ImGui::BeginGroup();

		ImDrawList* draw_list = ImGui::GetWindowDrawList();
		ImVec2 canvas_pos = ImGui::GetCursorScreenPos();            // ImDrawList API uses screen coordinates!
		ImVec2 canvas_size = ImGui::GetContentRegionAvail();        // Resize canvas to what's available
		int firstFrameUsed = firstFrame;

		int frameCount = ImMax(GetFrameMax() - GetFrameMin(), 1);

		static bool MovingScrollBar = false;
		static bool MovingCurrentFrame = false;

		// zoom in/out
		const int visibleFrameCount = (int)floorf(canvas_size.x / framePixelWidth);
		const float barWidthRatio = ImMin(visibleFrameCount / (float)frameCount, 1.f);
		const float barWidthInPixels = barWidthRatio * canvas_size.x;

		ImRect regionRect(canvas_pos, canvas_pos + canvas_size);

		static bool panningView = false;
		static ImVec2 panningViewSource;
		static int panningViewFrame;
		if (ImGui::IsWindowFocused() && io.KeyAlt && io.MouseDown[2]) {
			if (!panningView) {
				panningViewSource = io.MousePos;
				panningView = true;
				panningViewFrame = firstFrame;
			}
			firstFrame = panningViewFrame - int((io.MousePos.x - panningViewSource.x) / framePixelWidth);
			firstFrame = ImClamp(firstFrame, GetFrameMin(), GetFrameMax() - visibleFrameCount);
		}
		if (panningView && !io.MouseDown[2]) {
			panningView = false;
		}
		framePixelWidthTarget = ImClamp(framePixelWidthTarget, 0.1f, 50.f);

		framePixelWidth = ImLerp(framePixelWidth, framePixelWidthTarget, 0.33f);

		frameCount = GetFrameMax() - GetFrameMin();
		if (visibleFrameCount >= frameCount)
			firstFrame = GetFrameMin();

		bool hasScrollBar(true);
		// test scroll area
		ImVec2 headerSize(canvas_size.x, (float)ItemHeight);
		ImVec2 scrollBarSize(canvas_size.x, 14.f);
		ImGui::InvisibleButton("topBar", headerSize);
		draw_list->AddRectFilled(canvas_pos, canvas_pos + headerSize, 0xFFFF0000, 0);
		ImVec2 childFramePos = ImGui::GetCursorScreenPos();
		ImVec2 childFrameSize(canvas_size.x, canvas_size.y - 8.f - headerSize.y - (hasScrollBar ? scrollBarSize.y : 0));
		ImGui::PushStyleColor(ImGuiCol_FrameBg, 0);
		ImGui::BeginChild(890, childFrameSize, ImGuiChildFlags_FrameStyle);
		//focused = ImGui::IsWindowFocused();
		ImGui::InvisibleButton("contentBar", ImVec2(canvas_size.x, float(ItemHeight)));
		const ImVec2 contentMin = ImGui::GetItemRectMin();
		const ImVec2 contentMax = ImGui::GetItemRectMax();
		const ImRect contentRect(contentMin, contentMax);
		const float contentHeight = contentMax.y - contentMin.y;

		// full background
		draw_list->AddRectFilled(canvas_pos, canvas_pos + canvas_size, 0xFF242424, 0);

		// current frame top
		ImRect topRect(ImVec2(canvas_pos.x, canvas_pos.y), ImVec2(canvas_pos.x + canvas_size.x, canvas_pos.y + ItemHeight));

		if (!MovingCurrentFrame && !MovingScrollBar && !movingEntry && current_frame >= 0 && topRect.Contains(io.MousePos) && io.MouseDown[0])
		{
			MovingCurrentFrame = true;
		}
		if (MovingCurrentFrame)
		{
			if (frameCount)
			{
				current_frame = (int)((io.MousePos.x - topRect.Min.x) / framePixelWidth) + firstFrameUsed;
				if (current_frame < GetFrameMin())
					current_frame = GetFrameMin();
				if (current_frame >= GetFrameMax())
					current_frame = GetFrameMax();
			}
			if (!io.MouseDown[0])
				MovingCurrentFrame = false;
			pause = true;
		}

		//header
		draw_list->AddRectFilled(canvas_pos, ImVec2(canvas_size.x + canvas_pos.x, canvas_pos.y + ItemHeight), 0xFF3D3837, 0);
		//header frame number and lines
		int modFrameCount = 10;
		int frameStep = 1;
		//             while ((modFrameCount * framePixelWidth) < 100/*150*/)
		//             {
		//                 modFrameCount *= 2;
		//                 frameStep *= 2;
		//             };
		int halfModFrameCount = modFrameCount / 2;

		auto drawLine = [&](int i, int regionHeight) {
			bool baseIndex = ((i % modFrameCount) == 0) || (i == GetFrameMax() || i == GetFrameMin());
			bool halfIndex = (i % halfModFrameCount) == 0;
			int px = (int)canvas_pos.x + int(i * framePixelWidth) - int(firstFrameUsed * framePixelWidth);
			int tiretStart = baseIndex ? 4 : (halfIndex ? 10 : 14);
			int tiretEnd = baseIndex ? regionHeight : ItemHeight;

			if (px <= (canvas_size.x + canvas_pos.x) && px >= canvas_pos.x) {
				draw_list->AddLine(ImVec2((float)px, canvas_pos.y + (float)tiretStart), ImVec2((float)px, canvas_pos.y + (float)tiretEnd - 1), 0xFF606060, 1);
				draw_list->AddLine(ImVec2((float)px, canvas_pos.y + (float)ItemHeight), ImVec2((float)px, canvas_pos.y + (float)regionHeight - 1), 0x30606060, 1);
			}

			if (baseIndex && px > canvas_pos.x) {
				char tmps[512];
				snprintf(tmps, 512, "%d", i);
				draw_list->AddText(ImVec2((float)px + 3.f, canvas_pos.y), 0xFFBBBBBB, tmps);
			}
		};

		auto drawLineContent = [&](int i, int regionHeight, int layer_index) {
			int px = (int)canvas_pos.x + int(i * framePixelWidth) - int(firstFrameUsed * framePixelWidth);
			int tiretStart = int(contentMin.y + ItemHeight * layer_index);
			int tiretEnd = int(contentMax.y + ItemHeight * layer_index);

			if (px <= (canvas_size.x + canvas_pos.x) && px >= canvas_pos.x) {
				draw_list->AddLine(ImVec2(float(px), float(tiretStart)), ImVec2(float(px), float(tiretEnd)), 0x30606060, 1);
			}
// 			if (range_index >= 0 && range_index < current_anim->clip_rangs.size()) {
// 				const auto& flags = current_anim->clip_rangs[range_index].event_flags;
// 				if (i < flags.size() && flags[i]) {
// 					draw_list->AddRectFilled(ImVec2((float)px, contentMin.y), ImVec2((float)px + framePixelWidth, contentMin.y + ItemHeight), 0x8050BF50);
// 				}
// 			}
		};
		for (int i = GetFrameMin(); i <= GetFrameMax(); i += frameStep) {
			drawLine(i, ItemHeight);
		}
		drawLine(GetFrameMin(), ItemHeight);
		drawLine(GetFrameMax(), ItemHeight);

		// draw item names in the legend rect on the left
// 		size_t customHeight = 0;
// 		ImVec2 tpos(contentMin.x + 3, contentMin.y/* + offset_y*/ + 2 + customHeight);
// 		draw_list->AddText(tpos, 0xFFFFFFFF, "Event");
		// clipping rect so items bars are not visible in the legend on the left when scrolled
		int layer_idx = 0;
		for(auto& layer : bone_anim.anim_layers) {
			int offset_y = layer_idx * ItemHeight;
			bool is_active = (selected_layer == layer_idx);
			ImVec2 pos = ImVec2(contentMin.x, contentMin.y + 1 + offset_y);
			ImVec2 sz = ImVec2(canvas_size.x + canvas_pos.x, pos.y + ItemHeight - 1);
			draw_list->AddRectFilled(pos, sz, is_active ? 0x6F715D55 : (layer_idx % 2) == 0 ? 0x6F513D35 : 0x6F412D25, 0);
			// draw clip_ranges
			for (int i = 0; i < layer.clip_rangs.size(); i++) {
				auto start = layer.clip_rangs[i].start;
				auto end = layer.clip_rangs[i].end;
				if (start == -1 || end == -1 || end < start) {
					continue;
				}
				ImVec2 pos = ImVec2(contentMin.x - firstFrameUsed * framePixelWidth, contentMin.y + 1 + offset_y);
				pos.x -= 0.25f * framePixelWidth;
				ImVec2 slotP1(pos.x + start * framePixelWidth, pos.y + 2);
				ImVec2 slotP2(pos.x + end * framePixelWidth + framePixelWidth, pos.y + ItemHeight - 2);
				ImVec2 slotP3(pos.x + end * framePixelWidth + framePixelWidth, pos.y + ItemHeight - 2);
				unsigned int color = 0xFFAA8080;
				unsigned int slotColor = color | 0xFF000000;
				unsigned int slotColorHalf = (color & 0xFFFFFF) | 0x40000000;

				if (slotP1.x <= (canvas_size.x + contentMin.x) && slotP2.x >= contentMin.x) {
					if (is_active && range_index == i) {
						draw_list->AddRectFilled(slotP1, slotP3, slotColorHalf, 2);
						draw_list->AddRectFilled(slotP1, slotP2, slotColor, 2);
					}
					else {
						draw_list->AddRect(slotP1, slotP3, slotColorHalf, 2);
						draw_list->AddRect(slotP1, slotP2, slotColor, 2);
					}
				}
				if (ImRect(slotP1, slotP2).Contains(io.MousePos) && io.MouseDoubleClicked[0]) {
					;// DoubleClick(i);
				}
				ImRect rects[3] = { ImRect(slotP1, ImVec2(slotP1.x + framePixelWidth / 2, slotP2.y))
					, ImRect(ImVec2(slotP2.x - framePixelWidth / 2, slotP1.y), slotP2)
					, ImRect(slotP1, slotP2) };

				const unsigned int quadColor[] = { 0xFFFFFFFF, 0xFFFFFFFF, slotColor + (/*selected*/false ? 0 : 0x202020) };
				if (!movingEntry) {
					for (int j = 2; j >= 0; j--) {
						ImRect& rc = rects[j];
						if (!rc.Contains(io.MousePos))
							continue;
						if (is_active && range_index == i) {
							draw_list->AddRectFilled(rc.Min, rc.Max, quadColor[j], 2);
						}
					}
					if (io.MouseClicked[0]) {
						for (int j = 0; j < 3; j++) {
							ImRect& rc = rects[j];
							if (!rc.Contains(io.MousePos))
								continue;
							if (!ImRect(childFramePos, childFramePos + childFrameSize).Contains(io.MousePos))
								continue;
							if (is_active && range_index == i && !MovingCurrentFrame) {
								movingEntry = true;
								movingPos = cx;
								movingPart = j + 1;
								break;
							}
						}
					}
				}
			}

			// vertical frame lines in content area
			for (int i = GetFrameMin(); i <= GetFrameMax(); i += frameStep) {
				drawLineContent(i, int(contentHeight), layer_idx);
			}
			drawLineContent(GetFrameMin(), int(contentHeight), layer_idx);
			drawLineContent(GetFrameMax(), int(contentHeight), layer_idx);

			if (io.MouseClicked[0]) {
				if (io.MousePos.x > contentMin.x) {
					auto layer_index =  (int)floor((io.MousePos.y - contentMin.y) / ItemHeight);
					if (layer_index >= 0 && layer_index < bone_anim.anim_layers.size()) {
						selected_layer = layer_index;
					}
					if (is_active) {
						selected_frame = -1;
						range_index = -1;
						auto col = (int)floor((io.MousePos.x - contentMin.x + 3) / framePixelWidth) + firstFrameUsed;
						for (int ri = 0; ri < layer.clip_rangs.size(); ri++) {
							if (col >= layer.clip_rangs[ri].start && col <= layer.clip_rangs[ri].end) {
								range_index = ri;
							}
						}
						if (range_index >= 0 && range_index < layer.clip_rangs.size()) {
							if (((col == layer.clip_rangs[range_index].start) || (col == layer.clip_rangs[range_index].end))) {
								selected_frame = col;
							}
						}
					}
				}
			}
			if (is_active && selected_frame >= 0 && range_index >= 0) {
				int px = (int)canvas_pos.x + int(selected_frame * framePixelWidth) - int(firstFrameUsed * framePixelWidth);
				draw_list->AddRect(ImVec2((float)px, contentMin.y + offset_y), ImVec2((float)px + framePixelWidth, contentMin.y + ItemHeight + offset_y), 0xFF1080FF);
			}

			// moving
			if (is_active && movingEntry) {
				ImGui::SetNextFrameWantCaptureMouse(true);
				int diffFrame = int((cx - movingPos) / framePixelWidth);
				movingPos += int(diffFrame * framePixelWidth);
				if (is_active && std::abs(diffFrame) > 0 && range_index >= 0) {
					int* start = &layer.clip_rangs[range_index].start;
					int* end = &layer.clip_rangs[range_index].end;
					int& l = *start;
					int& r = *end;
					if (movingPart & 1)
						l += diffFrame;
					if (movingPart & 2)
						r += diffFrame;
					if (l < 0) {
						if (movingPart & 2)
							r -= l;
						l = 0;
					}
					if (movingPart & 1 && l > r)
						l = r;
					if (movingPart & 2 && r < l)
						r = l;
					move_type = movingPart;
					move_delta = diffFrame;
				}
				if (!io.MouseDown[0]) {
					movingEntry = false;
				}
			}

			layer_idx++;
		}


		const int anim_layer_count = (int)bone_anim.anim_layers.size();
		// cursor
		if (!bone_anim.anim_layers.empty() && current_frame >= firstFrame && current_frame <= GetFrameMax()) {
			static const float cursorWidth = 2.f;
			float cursorOffset = contentMin.x + (current_frame - firstFrameUsed) * framePixelWidth + framePixelWidth / 2 - cursorWidth * 0.5f;
			draw_list->AddLine(ImVec2(cursorOffset - 3, canvas_pos.y), ImVec2(cursorOffset - 3, contentMax.y + (anim_layer_count - 1) * ItemHeight), 0x502A2AFF, cursorWidth);
			char tmps[512];
			snprintf(tmps, 512, "%d", current_frame);
			draw_list->AddText(ImVec2(cursorOffset + 10, canvas_pos.y + 2), 0xFF2A2AFF, tmps);
			draw_list->AddRectFilled(ImVec2(cursorOffset - 0.75f * framePixelWidth + 1, canvas_pos.y), ImVec2(cursorOffset + 0.25f * framePixelWidth + 1, canvas_pos.y + ItemHeight), 0x502A2AFF);
		}

		ImGui::EndChild();
		ImGui::PopStyleColor();
		if (hasScrollBar) {
			ImGui::InvisibleButton("scrollBar", scrollBarSize);
			ImVec2 scrollBarMin = ImGui::GetItemRectMin();
			ImVec2 scrollBarMax = ImGui::GetItemRectMax();

			// ratio = number of frames visible in control / number to total frames

			float startFrameOffset = ((float)(firstFrameUsed - GetFrameMin()) / (float)frameCount) * (canvas_size.x);
			ImVec2 scrollBarA(scrollBarMin.x, scrollBarMin.y - 2);
			ImVec2 scrollBarB(scrollBarMin.x + canvas_size.x, scrollBarMax.y - 1);
			draw_list->AddRectFilled(scrollBarA, scrollBarB, 0xFF222222, 0);

			ImRect scrollBarRect(scrollBarA, scrollBarB);
			bool inScrollBar = scrollBarRect.Contains(io.MousePos);

			draw_list->AddRectFilled(scrollBarA, scrollBarB, 0xFF101010, 8);


			ImVec2 scrollBarC(scrollBarMin.x + startFrameOffset, scrollBarMin.y);
			ImVec2 scrollBarD(scrollBarMin.x + barWidthInPixels + startFrameOffset, scrollBarMax.y - 2);
			draw_list->AddRectFilled(scrollBarC, scrollBarD, (inScrollBar || MovingScrollBar) ? 0xFF606060 : 0xFF505050, 6);

			//float handleRadius = (scrollBarMax.y - scrollBarMin.y) / 2;
			ImRect barHandleLeft(scrollBarC, ImVec2(scrollBarC.x + 14, scrollBarD.y));
			ImRect barHandleRight(ImVec2(scrollBarD.x - 14, scrollBarC.y), scrollBarD);

			bool onLeft = barHandleLeft.Contains(io.MousePos);
			bool onRight = barHandleRight.Contains(io.MousePos);

			static bool sizingRBar = false;
			static bool sizingLBar = false;

			draw_list->AddRectFilled(barHandleLeft.Min, barHandleLeft.Max, (onLeft || sizingLBar) ? 0xFFAAAAAA : 0xFF666666, 6);
			draw_list->AddRectFilled(barHandleRight.Min, barHandleRight.Max, (onRight || sizingRBar) ? 0xFFAAAAAA : 0xFF666666, 6);

			ImRect scrollBarThumb(scrollBarC, scrollBarD);
			static const float MinBarWidth = 44.f;
			if (sizingRBar) {
				if (!io.MouseDown[0]) {
					sizingRBar = false;
				} else {
					float barNewWidth = ImMax(barWidthInPixels + io.MouseDelta.x, MinBarWidth);
					float barRatio = barNewWidth / barWidthInPixels;
					framePixelWidthTarget = framePixelWidth = framePixelWidth / barRatio;
					int newVisibleFrameCount = int(canvas_size.x / framePixelWidthTarget);
					int lastFrame = firstFrame + newVisibleFrameCount;
					if (lastFrame > GetFrameMax()) {
						framePixelWidthTarget = framePixelWidth = canvas_size.x / float(GetFrameMax() - firstFrame);
					}
				}
			} else if (sizingLBar) {
				if (!io.MouseDown[0]) {
					sizingLBar = false;
				} else {
					if (fabsf(io.MouseDelta.x) > FLT_EPSILON) {
						float barNewWidth = ImMax(barWidthInPixels - io.MouseDelta.x, MinBarWidth);
						float barRatio = barNewWidth / barWidthInPixels;
						float previousFramePixelWidthTarget = framePixelWidthTarget;
						framePixelWidthTarget = framePixelWidth = framePixelWidth / barRatio;
						int newVisibleFrameCount = int(visibleFrameCount / barRatio);
						int newFirstFrame = firstFrame + newVisibleFrameCount - visibleFrameCount;
						newFirstFrame = ImClamp(newFirstFrame, GetFrameMin(), ImMax(GetFrameMax() - visibleFrameCount, GetFrameMin()));
						if (newFirstFrame == firstFrame) {
							framePixelWidth = framePixelWidthTarget = previousFramePixelWidthTarget;
						} else {
							firstFrame = newFirstFrame;
						}
					}
				}
			} else {
				if (MovingScrollBar) {
					if (!io.MouseDown[0]) {
						MovingScrollBar = false;
					} else {
						float framesPerPixelInBar = barWidthInPixels / (float)visibleFrameCount;
						firstFrame = int((io.MousePos.x - panningViewSource.x) / framesPerPixelInBar) - panningViewFrame;
						firstFrame = ImClamp(firstFrame, GetFrameMin(), ImMax(GetFrameMax() - visibleFrameCount, GetFrameMin()));
					}
				} else {
					if (scrollBarThumb.Contains(io.MousePos) && ImGui::IsMouseClicked(0)
						&& !MovingCurrentFrame && !movingEntry) {
						MovingScrollBar = true;
						panningViewSource = io.MousePos;
						panningViewFrame = -firstFrame;
					}
					if (!sizingRBar && onRight && ImGui::IsMouseClicked(0))
						sizingRBar = true;
					if (!sizingLBar && onLeft && ImGui::IsMouseClicked(0))
						sizingLBar = true;

				}
			}
		}

		ImGui::EndGroup();
	}
}
