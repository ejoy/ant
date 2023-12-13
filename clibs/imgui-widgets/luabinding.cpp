#include <lua.hpp>

#include "widgets/ImSequencer.h"
#include "widgets/ImSimpleSequencer.h"
#include "zmo/imGuIZMOquat.h"

#define INDEX_ID 1
#define INDEX_ARGS 2

static double
read_field_float(lua_State *L, const char * field, double v, int tidx = INDEX_ARGS) {
	if (lua_getfield(L, tidx, field) == LUA_TNUMBER) {
		v = lua_tonumber(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static int
read_field_int(lua_State *L, const char * field, int v, int tidx = INDEX_ARGS) {
	if (lua_getfield(L, tidx, field) == LUA_TNUMBER) {
		if (!lua_isinteger(L, -1)) {
			luaL_error(L, "Not an integer");
		}
		v = (int)lua_tointeger(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static const char *
read_field_string(lua_State *L, const char * field, const char *v, int tidx = INDEX_ARGS) {
	if (lua_getfield(L, tidx, field) == LUA_TSTRING) {
		v = lua_tostring(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static bool
read_field_boolean(lua_State *L, const char *field, bool v, int tidx = INDEX_ARGS) {
	if (lua_getfield(L, tidx, field) == LUA_TBOOLEAN) {
		v = (bool)lua_toboolean(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

namespace ImSequencer
{
	extern int anim_fps;
	extern anim_detail* current_anim;
	extern std::unordered_map<std::string, anim_detail> anim_info;
}

static int
wSequencer(lua_State* L) {
	auto init_event = [L](std::vector<bool>& flags) {
		if (lua_getfield(L, -1, "key_event") == LUA_TTABLE) {
			lua_pushnil(L);
			while (lua_next(L, -2) != 0) {
				const char* frame_index = lua_tostring(L, -2);
				if (lua_type(L, -1) == LUA_TTABLE && (int)lua_rawlen(L, -1) > 0) {
					flags[std::atoi(frame_index)] = true;
				}
				lua_pop(L, 1);
			}
		}
		lua_pop(L, 1);
	};
	auto init_clip_ranges = [L, init_event](ImSequencer::anim_detail& item) {
		//item.clip_rangs.clear();
		if (lua_getfield(L, -1, "clips") == LUA_TTABLE) {
			int len = (int)lua_rawlen(L, -1);
			for (int index = 0; index < len; index++) {
				lua_pushinteger(L, index + 1);
				lua_gettable(L, -2);
				if (lua_type(L, -1) == LUA_TTABLE) {
 					auto event_flags = std::vector((int)std::ceil(item.duration * ImSequencer::anim_fps), false);
 					init_event(event_flags);
				}
				lua_pop(L, 1);
			}
		}
		lua_pop(L, 1);
	};

	static int selected_frame = -1;
	static int current_frame = 0;
	static std::string current_anim_name;
	static int selected_clip_index = -1;
	if (lua_type(L, 1) == LUA_TTABLE) {
		auto dirty = read_field_boolean(L, "dirty", false, 1);
		if (dirty) {
			ImSequencer::anim_fps = read_field_int(L, "anim_fps", 30, 2);
			ImSequencer::anim_info.clear();
			auto birth = read_field_string(L, "birth", "", 1);
			if (ImSequencer::anim_info.empty()) {
				lua_pushnil(L);
				while (lua_next(L, 1) != 0) {
					const char* anim_name = lua_tostring(L, -2);
					if (lua_type(L, -1) == LUA_TTABLE) {
						auto duration = (float)read_field_float(L, "duration", 0.0f, -1);
						if (duration > 0.0f) {
							ImSequencer::anim_info.insert({ std::string(anim_name), ImSequencer::anim_detail{} });
							auto& item = ImSequencer::anim_info[anim_name];
							item.duration = duration;
							init_clip_ranges(item);
						}
					}
					lua_pop(L, 1);
				}
				current_anim_name = birth;
				ImSequencer::current_anim = &ImSequencer::anim_info[birth];
			}
		}
		std::string anim_name = read_field_string(L, "anim_name", nullptr, 2);
		if (current_anim_name != anim_name) {
			current_anim_name = anim_name;
			ImSequencer::current_anim = &ImSequencer::anim_info[current_anim_name];
		}
		ImSequencer::current_anim->is_playing = read_field_boolean(L, "is_playing", false, 2);
		current_frame = read_field_int(L, "current_frame", 0, 2);
		selected_frame = read_field_int(L, "selected_frame", 0, 2);
		auto event_dirty_num = read_field_int(L, "event_dirty", 0, 2);
		// add or remove key event
		if (event_dirty_num == 1) {
			if (lua_getfield(L, 2, "current_event_list") == LUA_TTABLE
				&& selected_frame >= 0) {
				if (!ImSequencer::current_anim->event_flags.empty()) {
					ImSequencer::current_anim->event_flags[selected_frame] = ((int)lua_rawlen(L, -1) > 0);
				}
			}
			lua_pop(L, 1);
		} else if (event_dirty_num == -1) {
			auto duration = read_field_float(L, "duration", 0, 2);
			auto event_flags = std::vector((int)std::ceil(duration * ImSequencer::anim_fps), false);
			if (lua_getfield(L, 2, "key_event") == LUA_TTABLE) {
				lua_pushnil(L);
				while (lua_next(L, -2) != 0) {
					const char* frame_index = lua_tostring(L, -2);
					if (lua_type(L, -1) == LUA_TTABLE && (int)lua_rawlen(L, -1) > 0) {
						event_flags[std::atoi(frame_index)] = true;
					}
					lua_pop(L, 1);
				}
			}
			lua_pop(L, 1);
			ImSequencer::current_anim->event_flags = std::move(event_flags);
		}
	}

	bool pause = false;
	int move_type = -1;
	int move_delta = 0;
	int current_select = selected_frame;
	ImSequencer::Sequencer(pause, current_frame, current_select, move_type, selected_clip_index, move_delta);
	if (pause) {
		lua_pushinteger(L, current_frame);
		lua_setfield(L, -2, "pause");
	}
	if (move_type != -1) {
		lua_pushinteger(L, move_type);
		lua_setfield(L, -2, "move_type");
		lua_pushinteger(L, move_delta);
		lua_setfield(L, -2, "move_delta");
	}
	if (selected_frame != current_select) {
		selected_frame = current_select;
		lua_pushinteger(L, selected_frame);
		lua_setfield(L, -2, "selected_frame");
	}
	
	return 0;
}

namespace ImSimpleSequencer
{
	extern int anim_fps;
	extern anim_layer* current_layer;
	extern bone_anim_s bone_anim;
}

static int
wSimpleSequencer(lua_State* L) {
	auto init_clip_ranges = [L](ImSimpleSequencer::anim_layer& layer) {
		layer.clip_rangs.clear();
		if (lua_getfield(L, -1, "clips") == LUA_TTABLE) {
			int len = (int)lua_rawlen(L, -1);
			for (int index = 0; index < len; index++) {
				lua_pushinteger(L, index + 1);
				lua_gettable(L, -2);
				if (lua_type(L, -1) == LUA_TTABLE) {
					std::string_view nv;
					int start = -1;
					int end = -1;
					if (lua_getfield(L, -1, "name") == LUA_TSTRING) {
						nv = lua_tostring(L, -1);
					}
					lua_pop(L, 1);
					if (lua_getfield(L, -1, "range") == LUA_TTABLE) {
						lua_geti(L, -1, 1);
						start = (int)lua_tointeger(L, -1);
						lua_pop(L, 1);
						lua_geti(L, -1, 2);
						end = (int)lua_tointeger(L, -1);
						lua_pop(L, 1);

					}
					lua_pop(L, 1);

					layer.clip_rangs.emplace_back(nv, (int)start, (int)end);
				}
				lua_pop(L, 1);
			}
		}
		lua_pop(L, 1);
	};

	static int selected_frame = -1;
	static int current_frame = 0;
	static std::string current_anim_name;
	static int selected_clip_index = -1;
	static int selected_layer_index = -1;
	if (lua_type(L, 1) == LUA_TTABLE) {
		bool dirty = read_field_boolean(L, "dirty", false, 1);
		int dirty_layer = read_field_int(L, "dirty_layer", 0, 1);
		ImSimpleSequencer::bone_anim.is_playing = read_field_boolean(L, "is_playing", false, 1);
		if (ImSimpleSequencer::bone_anim.is_playing) {
			current_frame = read_field_int(L, "current_frame", 0, 1);
		}
		if (dirty) {
			ImSequencer::anim_fps = read_field_int(L, "anim_fps", 30, 2);
			ImSimpleSequencer::bone_anim.duration = (float)read_field_float(L, "duration", 0.0f, 1);
			selected_frame = read_field_int(L, "selected_frame", 0, 1);
			selected_layer_index = read_field_int(L, "selected_layer_index", 0, 1) - 1;
			selected_clip_index = read_field_int(L, "selected_clip_index", 0, 1) - 1;
		}
		if (dirty_layer != 0) {
			if (dirty_layer == -1) {
				ImSimpleSequencer::bone_anim.anim_layers.clear();
			}
			if (lua_getfield(L, 1, "target_anims") == LUA_TTABLE) {
				int len = (int)lua_rawlen(L, -1);
				for (int index = 0; index < len; index++) {
					lua_pushinteger(L, index + 1);
					lua_gettable(L, -2);
					if (lua_type(L, -1) == LUA_TTABLE) {
						ImSimpleSequencer::anim_layer* layer = nullptr;
						if (dirty_layer == -1) {
							std::string_view nv;
							if (lua_getfield(L, -1, "target_name") == LUA_TSTRING) {
								nv = lua_tostring(L, -1);
							}
							lua_pop(L, 1);
							ImSimpleSequencer::bone_anim.anim_layers.emplace_back();
							layer = &ImSimpleSequencer::bone_anim.anim_layers.back();
							layer->name = nv;
						} else if (dirty_layer == index + 1) {
							layer = &ImSimpleSequencer::bone_anim.anim_layers[index];
						}
						if (layer) {
							init_clip_ranges(*layer);
						}
					}
					lua_pop(L, 1);
				}
			}
			lua_pop(L, 1);
		}
	}

	bool pause = false;
	int move_type = -1;
	int move_delta = 0;
	int current_select = selected_frame;
	int current_layer_index = selected_layer_index;
	int current_clip_index = selected_clip_index;
	ImSimpleSequencer::SimpleSequencer(pause, selected_layer_index, current_frame, current_select, move_type, selected_clip_index, move_delta);
	if (pause) {
		lua_pushinteger(L, current_frame);
		lua_setfield(L, -2, "pause");
	}
	if (move_type != -1) {
		lua_pushinteger(L, move_type);
		lua_setfield(L, -2, "move_type");
		lua_pushinteger(L, move_delta);
		lua_setfield(L, -2, "move_delta");
	}
	if (selected_frame != current_select) {
		selected_frame = current_select;
		lua_pushinteger(L, selected_frame);
		lua_setfield(L, -2, "selected_frame");
	}

	if (selected_layer_index >= 0 && selected_layer_index != current_layer_index) {
		lua_pushinteger(L, selected_layer_index + 1);
		lua_setfield(L, -2, "selected_layer_index");
		if (!ImSimpleSequencer::bone_anim.anim_layers[selected_layer_index].clip_rangs.empty())
			selected_clip_index = 0;
		else
			selected_clip_index = -1;
	}

	if (/*selected_clip_index >= 0 && */selected_clip_index != current_clip_index) {
		lua_pushinteger(L, selected_clip_index >= 0 ? selected_clip_index + 1 : 0);
		lua_setfield(L, -2, "selected_clip_index");
	}

	return 0;
}

static int
zDirectionalArrow(lua_State *L) {
	const char * label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	lua_len(L, INDEX_ARGS);
	int n = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);
	if (n != 3)
		return luaL_error(L, "Need 3 numbers");
	vec3 dir;
	int i;
	for (i = 0; i < n; i++) {
		if (lua_geti(L, INDEX_ARGS, i + 1) != LUA_TNUMBER) {
			luaL_error(L, "Need float [%d]", i + 1);
		}
		if(i == 2) {
			dir[i] = -(float)lua_tonumber(L, -1);
		}
		else{
			dir[i] = (float)lua_tonumber(L, -1);
		}
		lua_pop(L, 1);
	}
	bool change = ImGui::gizmo3D(label, dir, 100, imguiGizmo::modeDirection);
	if (change) {
		for (i = 0; i < n; i++) {
		if(i == 2) {
			lua_pushnumber(L, -dir[i]);
		}
		else{
			lua_pushnumber(L, dir[i]);
		}			
			lua_seti(L, INDEX_ARGS, i + 1);
		}
		return 1;
	}
	else{
		return 0;
	}
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_imgui_widgets(lua_State *L) {
    luaL_Reg lib[] = {
        { "Sequencer", wSequencer },
        { "SimpleSequencer", wSimpleSequencer },
        { "DirectionalArrow", zDirectionalArrow },
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    return 1;
}
