#pragma once

#include <cstddef>
#include <map>
#include <unordered_map>
#include <string>
#include <vector>

struct ImDrawList;
struct ImRect;
namespace ImSequencer
{
   enum SEQUENCER_OPTIONS
   {
      SEQUENCER_EDIT_NONE = 0,
      SEQUENCER_EDIT_STARTEND = 1 << 1,
      SEQUENCER_CHANGE_FRAME = 1 << 3,
      SEQUENCER_ADD = 1 << 4,
      SEQUENCER_DEL = 1 << 5,
      SEQUENCER_COPYPASTE = 1 << 6,
      SEQUENCER_EDIT_ALL = SEQUENCER_EDIT_STARTEND | SEQUENCER_CHANGE_FRAME
   };
   int GetItemCount();
   const char* GetItemLabel(int index);
   size_t GetCustomHeight(int index);
   int GetFrameMin();
   int GetFrameMax();
   int GetItemCount();
   void Get(int index, int** start, int** end, int* type, unsigned int* color);
   void DoubleClick(int index);
   void BeginEdit(int index);
   void EndEdit();
   void CustomDrawCompact(int index, ImDrawList* draw_list, const ImRect& rc, const ImRect& clippingRect);

   struct key_event
   {
       int type;
       std::string event_type;
   };
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
   struct anim_detail
   {
       float duration{ 0.0f };
       float current_time{ 0.0f };
       bool is_playing{ false };
       float speed{ 1.0f };
       std::vector<bool>        event_flags;
       std::vector<clip_range>  clip_rangs;
       //imgui
       bool expand{ false };
   };
   extern bool new_anim;
   extern int current_id;
   extern std::unordered_map<int, std::unordered_map<std::string, anim_detail>> anim_info;

   struct SequenceInterface
   {
      bool focused = false;
      virtual int GetFrameMin() const = 0;
      virtual int GetFrameMax() const = 0;
      virtual int GetItemCount() const = 0;

      virtual void BeginEdit(int /*index*/) {}
      virtual void EndEdit() {}
      virtual int GetItemTypeCount() const { return 0; }
      virtual const char* GetItemTypeName(int /*typeIndex*/) const { return ""; }
      virtual const char* GetItemLabel(int /*index*/) const { return ""; }

      virtual void Get(int index, int** start, int** end, int* type, unsigned int* color) = 0;
      virtual void Add(int /*type*/) {}
      virtual void Del(int /*index*/) {}
      virtual void Duplicate(int /*index*/) {}

      virtual void Copy() {}
      virtual void Paste() {}

      virtual size_t GetCustomHeight(int /*index*/) { return 0; }
      virtual void DoubleClick(int /*index*/) {}
      virtual void CustomDraw(int /*index*/, ImDrawList* /*draw_list*/, const ImRect& /*rc*/, const ImRect& /*legendRect*/, const ImRect& /*clippingRect*/, const ImRect& /*legendClippingRect*/) {}
      virtual void CustomDrawCompact(int /*index*/, ImDrawList* /*draw_list*/, const ImRect& /*rc*/, const ImRect& /*clippingRect*/) {}
   };


   // return true if selection is made
   bool Sequencer(bool& pause, int& current_frame, int& selected_entry, int& move_type, int& range_index, int& move_delta);

}
