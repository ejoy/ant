#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif

#include "ImSequencer.h"
#include "imgui.h"
#include "imgui_internal.h"
#include "ImCurveEdit.h"
#include <cstdlib>
#include <algorithm>
#include <string>
#include <unordered_map>

namespace ImSequencer
{
	anim_detail* current_anim{ nullptr };
	std::unordered_map<int, std::unordered_map<std::string, anim_detail>> anim_info;
	constexpr int ItemHeight = 20;

	int GetFrameMin() { return 0; }
	int GetFrameMax() { return (int)std::ceil(current_anim->duration * 30.0f); }

#ifndef IMGUI_DEFINE_MATH_OPERATORS
	static ImVec2 operator+(const ImVec2& a, const ImVec2& b) { return ImVec2(a.x + b.x, a.y + b.y); }
#endif

	void Sequencer(bool& pause, int& current_frame, int& selected_frame, int& move_type, int& range_index, int& move_delta)
	{
		static int firstFrame = 0;
		ImGuiIO& io = ImGui::GetIO();
		int cx = (int)(io.MousePos.x);
		int cy = (int)(io.MousePos.y);
		static float framePixelWidth = 10.f;
		static float framePixelWidthTarget = 10.f;
		constexpr int legendWidth = 150;

		static bool movingEntry = false;
		static int movingPos = -1;
		static int movingPart = -1;
		static int movingKeyFrame = -1;
		static int sourceKeyFrame = -1;
		ImGui::BeginGroup();

		ImDrawList* draw_list = ImGui::GetWindowDrawList();
		ImVec2 canvas_pos = ImGui::GetCursorScreenPos();            // ImDrawList API uses screen coordinates!
		ImVec2 canvas_size = ImGui::GetContentRegionAvail();        // Resize canvas to what's available
		canvas_size.y = 80.0f;
		int firstFrameUsed = firstFrame;

		int frameCount = ImMax(GetFrameMax() - GetFrameMin(), 1);

		static bool MovingScrollBar = false;
		static bool MovingCurrentFrame = false;

		// zoom in/out
		const int visibleFrameCount = (int)floorf((canvas_size.x - legendWidth) / framePixelWidth);
		const float barWidthRatio = ImMin(visibleFrameCount / (float)frameCount, 1.f);
		const float barWidthInPixels = barWidthRatio * (canvas_size.x - legendWidth);

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
		/*
		int framesPixelWidth = int(frameCount * framePixelWidth);
		if ((framesPixelWidth + legendWidth) >= canvas_size.x)
		{
			hasScrollBar = true;
		}
		*/
		// test scroll area
		ImVec2 headerSize(canvas_size.x, (float)ItemHeight);
		ImVec2 scrollBarSize(canvas_size.x, 14.f);
		ImGui::InvisibleButton("topBar", headerSize);
		draw_list->AddRectFilled(canvas_pos, canvas_pos + headerSize, 0xFFFF0000, 0);
		ImVec2 childFramePos = ImGui::GetCursorScreenPos();
		ImVec2 childFrameSize(canvas_size.x, canvas_size.y - 8.f - headerSize.y - (hasScrollBar ? scrollBarSize.y : 0));
		ImGui::PushStyleColor(ImGuiCol_FrameBg, 0);
		ImGui::BeginChildFrame(889, childFrameSize);
		//focused = ImGui::IsWindowFocused();
		ImGui::InvisibleButton("contentBar", ImVec2(canvas_size.x, float(ItemHeight)));
		const ImVec2 contentMin = ImGui::GetItemRectMin();
		const ImVec2 contentMax = ImGui::GetItemRectMax();
		const ImRect contentRect(contentMin, contentMax);
		const float contentHeight = contentMax.y - contentMin.y;

		// full background
		draw_list->AddRectFilled(canvas_pos, canvas_pos + canvas_size, 0xFF242424, 0);

		// current frame top
		ImRect topRect(ImVec2(canvas_pos.x + legendWidth, canvas_pos.y), ImVec2(canvas_pos.x + canvas_size.x, canvas_pos.y + ItemHeight));

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
			int px = (int)canvas_pos.x + int(i * framePixelWidth) + legendWidth - int(firstFrameUsed * framePixelWidth);
			int tiretStart = baseIndex ? 4 : (halfIndex ? 10 : 14);
			int tiretEnd = baseIndex ? regionHeight : ItemHeight;

			if (px <= (canvas_size.x + canvas_pos.x) && px >= (canvas_pos.x + legendWidth)) {
				draw_list->AddLine(ImVec2((float)px, canvas_pos.y + (float)tiretStart), ImVec2((float)px, canvas_pos.y + (float)tiretEnd - 1), 0xFF606060, 1);
				draw_list->AddLine(ImVec2((float)px, canvas_pos.y + (float)ItemHeight), ImVec2((float)px, canvas_pos.y + (float)regionHeight - 1), 0x30606060, 1);
			}

			if (baseIndex && px > (canvas_pos.x + legendWidth)) {
				char tmps[512];
				sprintf(tmps, "%d", i);
				draw_list->AddText(ImVec2((float)px + 3.f, canvas_pos.y), 0xFFBBBBBB, tmps);
			}
		};

		auto drawLineContent = [&](int i, int regionHeight) {
			int px = (int)canvas_pos.x + int(i * framePixelWidth) + legendWidth - int(firstFrameUsed * framePixelWidth);
			int tiretStart = int(contentMin.y);
			int tiretEnd = int(contentMax.y);

			if (px <= (canvas_size.x + canvas_pos.x) && px >= (canvas_pos.x + legendWidth)) {
				draw_list->AddLine(ImVec2(float(px), float(tiretStart)), ImVec2(float(px), float(tiretEnd)), 0x30606060, 1);
			}
			if (range_index >= 0 && range_index < current_anim->clip_rangs.size()) {
				const auto& flags = current_anim->clip_rangs[range_index].event_flags;
				if (i < flags.size() && flags[i]) {
					draw_list->AddRectFilled(ImVec2((float)px, contentMin.y), ImVec2((float)px + framePixelWidth, contentMin.y + ItemHeight), 0x8050BF50);
				}
			}
		};
		for (int i = GetFrameMin(); i <= GetFrameMax(); i += frameStep) {
			drawLine(i, ItemHeight);
		}
		drawLine(GetFrameMin(), ItemHeight);
		drawLine(GetFrameMax(), ItemHeight);
		draw_list->PushClipRect(childFramePos, childFramePos + childFrameSize);

		// draw item names in the legend rect on the left
		size_t customHeight = 0;
		ImVec2 tpos(contentMin.x + 3, contentMin.y/* + offset_y*/ + 2 + customHeight);
		draw_list->AddText(tpos, 0xFFFFFFFF, "Event");
		// clipping rect so items bars are not visible in the legend on the left when scrolled

		ImVec2 pos = ImVec2(contentMin.x, contentMin.y + 1);
		ImVec2 sz = ImVec2(canvas_size.x + canvas_pos.x, pos.y + ItemHeight - 1);
		draw_list->AddRectFilled(pos, sz, 0x7F614D45, 0);
		draw_list->PushClipRect(childFramePos + ImVec2(float(legendWidth), 0.f - ItemHeight), childFramePos + childFrameSize);
		// draw clip_ranges
		for (int i = 0; i < current_anim->clip_rangs.size(); i++) {
			auto start = current_anim->clip_rangs[i].start;
			auto end = current_anim->clip_rangs[i].end;
			ImVec2 pos = ImVec2(contentMin.x + legendWidth - firstFrameUsed * framePixelWidth, contentMin.y + 1);
			pos.x -= 0.5 * framePixelWidth;
			ImVec2 slotP1(pos.x + start * framePixelWidth, pos.y + 2);
			ImVec2 slotP2(pos.x + end * framePixelWidth + framePixelWidth, pos.y + ItemHeight - 2);
			ImVec2 slotP3(pos.x + end * framePixelWidth + framePixelWidth, pos.y + ItemHeight - 2);
			unsigned int color = 0xFFAA8080;
			unsigned int slotColor = color | 0xFF000000;
			unsigned int slotColorHalf = (color & 0xFFFFFF) | 0x40000000;

			if (slotP1.x <= (canvas_size.x + contentMin.x) && slotP2.x >= (contentMin.x + legendWidth)) {
				if (range_index == i) {
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
					if (range_index == i) {
						draw_list->AddRectFilled(rc.Min, rc.Max, quadColor[j], 2);
					}
				}

				for (int j = 0; j < 3; j++) {
					ImRect& rc = rects[j];
					if (!rc.Contains(io.MousePos))
						continue;
					if (!ImRect(childFramePos, childFramePos + childFrameSize).Contains(io.MousePos))
						continue;
					if (range_index == i) {
						movingEntry = true;
						movingPos = cx;
						movingPart = j + 1;
						break;
					}
				}
			}
		}

		// vertical frame lines in content area
		for (int i = GetFrameMin(); i <= GetFrameMax(); i += frameStep) {
			drawLineContent(i, int(contentHeight));
		}
		drawLineContent(GetFrameMin(), int(contentHeight));
		drawLineContent(GetFrameMax(), int(contentHeight));

		auto row = (int)floor((io.MousePos.y - contentMin.y) / ItemHeight);
		if (io.MouseClicked[0] && row == 0) {
			auto col = (int)floor((io.MousePos.x - contentMin.x - legendWidth + 3) / framePixelWidth) + firstFrameUsed;
			if (col >= 0 && col <= GetFrameMax() && selected_frame != col) {
				selected_frame = col;
			}
			if (range_index >= 0 && range_index < current_anim->clip_rangs.size()) {
				const auto& flags = current_anim->clip_rangs[range_index].event_flags;
				if (selected_frame < flags.size() && flags[selected_frame]) {
					movingEntry = true;
					movingPos = cx;
					movingKeyFrame = selected_frame;
					sourceKeyFrame = selected_frame;
					movingPart = 3;
				}
			}
		}
		int px = (int)canvas_pos.x + int(selected_frame * framePixelWidth) + legendWidth - int(firstFrameUsed * framePixelWidth);
		draw_list->AddRect(ImVec2((float)px, contentMin.y), ImVec2((float)px + framePixelWidth, contentMin.y + ItemHeight), 0xFF1080FF);

		// slots
		customHeight = 0;
// 		for (int i = 0; i < current_anim->clip_rangs.size(); i++) {
// 			auto start = current_anim->clip_rangs[i].start;
// 			auto end = current_anim->clip_rangs[i].end;
// 			ImVec2 pos = ImVec2(contentMin.x + legendWidth - firstFrameUsed * framePixelWidth, contentMin.y + 1);
// 			pos.x -= 0.5 * framePixelWidth;
// 			ImVec2 slotP1(pos.x + start * framePixelWidth, pos.y + 2);
// 			ImVec2 slotP2(pos.x + end * framePixelWidth + framePixelWidth, pos.y + ItemHeight - 2);
// 			ImVec2 slotP3(pos.x + end * framePixelWidth + framePixelWidth, pos.y + ItemHeight - 2);
// 			unsigned int color = 0xFFAA8080;
// 			unsigned int slotColor = color | 0xFF000000;
// 			unsigned int slotColorHalf = (color & 0xFFFFFF) | 0x40000000;
// 
// 			if (slotP1.x <= (canvas_size.x + contentMin.x) && slotP2.x >= (contentMin.x + legendWidth)) {
// 				if (range_index == i) {
// 					draw_list->AddRectFilled(slotP1, slotP3, slotColorHalf, 2);
// 					draw_list->AddRectFilled(slotP1, slotP2, slotColor, 2);
// 				} else {
// 					draw_list->AddRect(slotP1, slotP3, slotColorHalf, 2);
// 					draw_list->AddRect(slotP1, slotP2, slotColor, 2);
// 				}
// 			}
// 			if (ImRect(slotP1, slotP2).Contains(io.MousePos) && io.MouseDoubleClicked[0]) {
// 				;// DoubleClick(i);
// 			}
// 			ImRect rects[3] = { ImRect(slotP1, ImVec2(slotP1.x + framePixelWidth / 2, slotP2.y))
// 				, ImRect(ImVec2(slotP2.x - framePixelWidth / 2, slotP1.y), slotP2)
// 				, ImRect(slotP1, slotP2) };
// 
// 			const unsigned int quadColor[] = { 0xFFFFFFFF, 0xFFFFFFFF, slotColor + (/*selected*/false ? 0 : 0x202020) };
// 			if (!movingEntry) {
// 				for (int j = 2; j >= 0; j--) {
// 					ImRect& rc = rects[j];
// 					if (!rc.Contains(io.MousePos))
// 						continue;
// 					if (range_index == i) {
// 						draw_list->AddRectFilled(rc.Min, rc.Max, quadColor[j], 2);
// 					}
// 				}
// 
// 				for (int j = 0; j < 3; j++) {
// 					ImRect& rc = rects[j];
// 					if (!rc.Contains(io.MousePos))
// 						continue;
// 					if (!ImRect(childFramePos, childFramePos + childFrameSize).Contains(io.MousePos))
// 						continue;
// 					if (range_index == i) {
// 						movingEntry = true;
// 						movingPos = cx;
// 						movingPart = j + 1;
// 						break;
// 					}
// 				}
// 			}
// 		}

		// moving
		if (movingEntry) {
			ImGui::CaptureMouseFromApp();
			int diffFrame = int((cx - movingPos) / framePixelWidth);
			movingPos += int(diffFrame * framePixelWidth);
			if (io.KeyAlt/*move_keyframe*/) {
				if (std::abs(diffFrame) > 0 && sourceKeyFrame > 0) {
					if (movingPart == 3) {
						movingKeyFrame += diffFrame;
					}
					if (movingKeyFrame < 0) {
						movingKeyFrame = 0;
					}
					if (range_index >= 0 && range_index < current_anim->clip_rangs.size()) {
						auto& flags = current_anim->clip_rangs[range_index].event_flags;
						if (sourceKeyFrame != movingKeyFrame && !flags[movingKeyFrame]) {
							flags[movingKeyFrame] = true;
							flags[sourceKeyFrame] = false;
							selected_frame = movingKeyFrame;
							sourceKeyFrame = movingKeyFrame;
							move_type = 0;
						}
					}
				}
			} else {
				if (std::abs(diffFrame) > 0 && range_index >= 0) {
					int* start = &current_anim->clip_rangs[range_index].start;
					int* end = &current_anim->clip_rangs[range_index].end;
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
			}
			if (!io.MouseDown[0]) {
				movingEntry = false;
			}
		}

		// cursor
		if (current_frame >= firstFrame && current_frame <= GetFrameMax()) {
			static const float cursorWidth = 2.f;
			float cursorOffset = contentMin.x + legendWidth + (current_frame - firstFrameUsed) * framePixelWidth + framePixelWidth / 2 - cursorWidth * 0.5f;
			draw_list->AddLine(ImVec2(cursorOffset - 3, canvas_pos.y), ImVec2(cursorOffset - 3, contentMax.y), 0x502A2AFF, cursorWidth);
			char tmps[512];
			sprintf(tmps, "%d", current_frame);
			draw_list->AddText(ImVec2(cursorOffset + 10, canvas_pos.y + 2), 0xFF2A2AFF, tmps);
			int px = (int)canvas_pos.x + int((current_frame - firstFrameUsed) * framePixelWidth) + legendWidth - int(firstFrameUsed * framePixelWidth);
			draw_list->AddRectFilled(ImVec2((float)px, canvas_pos.y), ImVec2((float)px + framePixelWidth, canvas_pos.y + ItemHeight), 0x502A2AFF);
		}

		draw_list->PopClipRect();
		draw_list->PopClipRect();

		ImGui::EndChildFrame();
		ImGui::PopStyleColor();
		if (hasScrollBar) {
			ImGui::InvisibleButton("scrollBar", scrollBarSize);
			ImVec2 scrollBarMin = ImGui::GetItemRectMin();
			ImVec2 scrollBarMax = ImGui::GetItemRectMax();

			// ratio = number of frames visible in control / number to total frames

			float startFrameOffset = ((float)(firstFrameUsed - GetFrameMin()) / (float)frameCount) * (canvas_size.x - legendWidth);
			ImVec2 scrollBarA(scrollBarMin.x + legendWidth, scrollBarMin.y - 2);
			ImVec2 scrollBarB(scrollBarMin.x + canvas_size.x, scrollBarMax.y - 1);
			draw_list->AddRectFilled(scrollBarA, scrollBarB, 0xFF222222, 0);

			ImRect scrollBarRect(scrollBarA, scrollBarB);
			bool inScrollBar = scrollBarRect.Contains(io.MousePos);

			draw_list->AddRectFilled(scrollBarA, scrollBarB, 0xFF101010, 8);


			ImVec2 scrollBarC(scrollBarMin.x + legendWidth + startFrameOffset, scrollBarMin.y);
			ImVec2 scrollBarD(scrollBarMin.x + legendWidth + barWidthInPixels + startFrameOffset, scrollBarMax.y - 2);
			draw_list->AddRectFilled(scrollBarC, scrollBarD, (inScrollBar || MovingScrollBar) ? 0xFF606060 : 0xFF505050, 6);

			float handleRadius = (scrollBarMax.y - scrollBarMin.y) / 2;
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
					int newVisibleFrameCount = int((canvas_size.x - legendWidth) / framePixelWidthTarget);
					int lastFrame = firstFrame + newVisibleFrameCount;
					if (lastFrame > GetFrameMax()) {
						framePixelWidthTarget = framePixelWidth = (canvas_size.x - legendWidth) / float(GetFrameMax() - firstFrame);
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
