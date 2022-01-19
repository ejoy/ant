#pragma once

#include <cstddef>
#include <map>
#include <unordered_map>
#include <string>
#include <vector>

struct ImDrawList;
struct ImRect;
namespace ImSimpleSequencer
{
   struct clip_range
   {
       clip_range(std::string_view nv, int s, int e)
           : name{ nv }
           , start{ s }
           , end{ e }
       {}
       std::string name;
       int start;
       int end;
   };
   struct anim_layer
   {
       std::string name;
       std::vector<clip_range> clip_rangs;
   };
   struct bone_anim_s
   {
	   float duration{ 0.0f };
	   float current_time{ 0.0f };
	   bool is_playing{ false };
	   float speed{ 1.0f };
       std::vector<anim_layer> anim_layers;
   };
   extern bone_anim_s bone_anim;

   void SimpleSequencer(bool& pause, int& current_frame, int& selected_entry, int& move_type, int& range_index, int& move_delta);

}
