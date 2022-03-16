#include <lua.hpp>
#include "../bgfx/bgfx_interface.h"

#include <glm/glm.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtc/quaternion.hpp>
#include <glm/gtc/matrix_access.hpp>
#include <glm/gtx/transform.hpp>
#include <glm/gtx/quaternion.hpp>
#include <glm/gtx/compatibility.hpp>

#include "effect.h"
#include "effekseer_context.h"
#include <../EffekseerRendererCommon/EffekseerRenderer.CommonUtils.h>
#include <../EffekseerRendererBGFX/EffekseerRenderer/EffekseerRendererBGFX.ModelRenderer.h>
#include "lua2struct.h"

LUA2STRUCT(struct effekseer_ctx, viewid, square_max_count, sprite_programs, model_programs, unlit_layout, lit_layout, distortion_layout, ad_unlit_layout, ad_lit_layout, ad_distortion_layout, mtl_layout, mtl1_layout, mtl2_layout, model_layout);
LUA2STRUCT(struct program, prog, uniforms);
LUA2STRUCT(struct program::uniform, handle, name);

program::~program()
{
	BGFX(destroy_program)({ (uint16_t)prog });
}

namespace EffekseerRendererBGFX {
extern bgfx_view_id_t g_view_id;
}

static effekseer_ctx* g_effekseer = nullptr;
static std::string g_current_path = "";
static lua_State* g_current_lua_state = nullptr;
static std::unordered_map<std::string, int32_t> g_effect_cache_;

struct path_data
{
	std::string origin; 
	std::string result;
};

static int
lget_ant_file_path(lua_State* L) {
	struct path_data* pd = (struct path_data*)lua_touserdata(L, 1);
	lua_rawgeti(L, LUA_REGISTRYINDEX, g_effekseer->path_converter_);
	lua_pushlstring(L, pd->origin.data(), pd->origin.size());
	lua_call(L, 1, 1);
	if (lua_type(L, -1) == LUA_TSTRING) {
		pd->result = lua_tostring(L, -1);
	} else {
		lua_pop(L, 1);
	}
	return 0;
}

std::string get_ant_file_path(const std::string& path)
{
	lua_State* L = g_current_lua_state;
	path_data pd{ g_current_path + path, ""};
	lua_pushcfunction(L, lget_ant_file_path);
	lua_pushlightuserdata(L, &pd);
	if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
		printf("get_ant_file_path error : %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
	return pd.result;
}

struct fx_data
{
	std::string vspath;
	std::string fspath;
	bgfx_program_handle_t* prog;
	std::unordered_map<std::string, bgfx_uniform_handle_t>* uniforms;
};

static int
lload_fx(lua_State* L) {
	struct fx_data* fd = (struct fx_data*)lua_touserdata(L, 1);
	lua_rawgeti(L, LUA_REGISTRYINDEX, g_effekseer->fxloader_);
	lua_pushlstring(L, fd->vspath.data(), fd->vspath.size());
	lua_pushlstring(L, fd->fspath.data(), fd->fspath.size());
	lua_call(L, 2, 1);
	program fx;
	if (lua_type(L, -1) == LUA_TTABLE) {
		lua_struct::unpack(L, -1, fx);
		fd->prog->idx = fx.prog;
		for (auto& uniformInfo : fx.uniforms) {
			(*(fd->uniforms))[uniformInfo.name].idx = uniformInfo.handle;
		}
	} else {
		lua_pop(L, 1);
	}
	return 0;
}

void load_fx(const std::string& vspath, const std::string& fspath, bgfx_program_handle_t& prog,
	std::unordered_map<std::string, bgfx_uniform_handle_t>& uniforms)
{
	lua_State* L = g_current_lua_state;
	fx_data fd = { vspath, fspath, &prog, &uniforms };
	lua_pushcfunction(L, lload_fx);
	lua_pushlightuserdata(L, &fd);
	if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
		printf("load_fx error: %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
}

effekseer_ctx::effekseer_ctx(lua_State* L, int idx)
{
	lua_struct::unpack(L, idx, *this);
	EffekseerRendererBGFX::g_view_id = viewid;
}

bool effekseer_ctx::init()
{
	::EffekseerRendererBGFX::ModelRenderer::model_vertex_layout_ = model_layout;

	auto init_ctx = [this](std::vector<EffekseerRendererBGFX::bgfx_context>& ctx, const std::vector<program>& prog) {
		// 
		auto shaderCount = static_cast<size_t>(EffekseerRenderer::RendererShaderType::Material) + 1 + 1;
		ctx.resize(shaderCount);
		for (int i = 0; i < (shaderCount - 1); i++) {
			ctx[i].program_.idx = prog[i].prog;
			for (auto& uniformInfo : prog[i].uniforms) {
				ctx[i].uniforms_[uniformInfo.name].idx = uniformInfo.handle;
			}
		}
		ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::Unlit)].vertex_layout_ = unlit_layout;
		ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::Lit)].vertex_layout_ = lit_layout;
		ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::BackDistortion)].vertex_layout_ = distortion_layout;
		ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::AdvancedUnlit)].vertex_layout_ = ad_unlit_layout;
		ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::AdvancedLit)].vertex_layout_ = ad_lit_layout;
		ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::AdvancedBackDistortion)].vertex_layout_ = ad_distortion_layout;
		ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::Material)].vertex_layout_ = mtl_layout;
		// with custom data1
		ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::Material) + 1].vertex_layout_ = mtl1_layout;
		// with custom data2
		// ...
	};
	
	init_ctx(::EffekseerRendererBGFX::Renderer::s_bgfx_sprite_context_, sprite_programs);
	init_ctx(::EffekseerRendererBGFX::ModelRenderer::s_bgfx_model_context_, model_programs);

	renderer_ = ::EffekseerRendererBGFX::Renderer::Create(2000/*square_max_count*/);
	if (!renderer_.Get()) {
		return false;
	}
	manager_ = ::Effekseer::Manager::Create(square_max_count);
	if (!manager_.Get()) {
		return false;
	}
	manager_->SetCoordinateSystem(Effekseer::CoordinateSystem::LH);
	manager_->SetSpriteRenderer(renderer_->CreateSpriteRenderer());
	manager_->SetRibbonRenderer(renderer_->CreateRibbonRenderer());
	manager_->SetRingRenderer(renderer_->CreateRingRenderer());
	manager_->SetTrackRenderer(renderer_->CreateTrackRenderer());
	manager_->SetModelRenderer(renderer_->CreateModelRenderer());
	manager_->SetTextureLoader(renderer_->CreateTextureLoader());
	manager_->SetModelLoader(renderer_->CreateModelLoader());
	manager_->SetMaterialLoader(renderer_->CreateMaterialLoader());

	return true;
}

static int
leffekseer_init(lua_State* L) {
	if (g_effekseer) {
		return luaL_error(L, "Effekseer has been initialized.");
	}
	g_effekseer = new effekseer_ctx(L, 1);
	if (!g_effekseer->init()) {
		return luaL_error(L, "Failed to Initialise Effekseer.");
	}
	return 0;
}

static int
leffekseer_shutdown(lua_State* L) {
	g_effekseer->manager_.Reset();
	g_effekseer->renderer_.Reset();
	if (g_effekseer) {
		delete g_effekseer;
		g_effekseer = nullptr;
	}
	return 0;
}

static int
leffekseer_update_view_proj(lua_State* L) {
	const glm::mat4& viewmat = *(glm::mat4*)lua_touserdata(L, 1);
	const glm::mat4& projmat = *(glm::mat4*)lua_touserdata(L, 2);
	memcpy(g_effekseer->view_mat_.Values, (float*)glm::value_ptr(viewmat), sizeof(float) * 16);
	memcpy(g_effekseer->proj_mat_.Values, (float*)glm::value_ptr(projmat), sizeof(float) * 16);
	return 0;
}

static int
leffekseer_update(lua_State* L) {
	g_effekseer->update();
	float delta = (float)luaL_checknumber(L, 1);
	g_effekseer->draw(delta);
	return 0;
}

static int
lcreate(lua_State* L) {
	g_current_lua_state = L;
	if (lua_type(L, 1) == LUA_TSTRING && lua_type(L, 2) == LUA_TSTRING) {
		size_t sz;
		std::string filename = std::string(lua_tolstring(L, 2, &sz));
		if (auto it = g_effect_cache_.find(filename); it == g_effect_cache_.end()) {
			g_current_path = filename.substr(0, filename.rfind('/') + 1);
			const char* data = lua_tolstring(L, 1, &sz);
			auto eidx = g_effekseer->create_effect(data, (int32_t)sz);
			if (eidx == -1) {
				return luaL_error(L, "create effect failed.");
			}
			g_effect_cache_.insert(std::pair<std::string, int32_t>(filename, eidx));
		}
		lua_pushinteger(L, g_effect_cache_[filename]);
		return 1;
	}
	return 0;
}

static int
ldestroy(lua_State* L) {
	if (lua_type(L, 1) == LUA_TNUMBER) {
		int32_t eidx = lua_tointeger(L, -1);
		if (eidx == -1) {
			for (auto& effect : g_effekseer->effects_) {
				effect.destroy();
			}
			g_effect_cache_.clear();
		} else {
			g_effekseer->destroy_effect(eidx);
			for (auto it = g_effect_cache_.begin(); it != g_effect_cache_.end(); ++it) {
				if (eidx == it->second) {
					g_effect_cache_.erase(it);
					break;
				}
			}
		}
	}
	return 0;
}
static int
lset_fxloader(lua_State* L) {
	g_effekseer->fxloader_ = luaL_ref(L, LUA_REGISTRYINDEX);
	return 0;
}

static int
lset_path_converter(lua_State* L) {
	g_effekseer->path_converter_ = luaL_ref(L, LUA_REGISTRYINDEX);
	return 0;
}

static void get_effect_from_lua(lua_State* L, int32_t& effectid, int32_t& playid)
{
	if (lua_type(L, 1) == LUA_TNUMBER) {
		effectid = lua_tointeger(L, 1);
	}
	if (lua_type(L, 2) == LUA_TNUMBER) {
		playid = lua_tointeger(L, 2);
	}
}

static int
lupdate_transform(lua_State* L) {
	int32_t eidx = -1;
	int32_t pidx = -1;
	get_effect_from_lua(L, eidx, pidx);
	if (eidx != -1) {
		glm::mat4x4* m44 = (glm::mat4x4*)lua_touserdata(L, 3);
		auto col0 = glm::row(*m44, 0);
		auto col1 = glm::row(*m44, 1);
		auto col2 = glm::row(*m44, 2);
		glm::mat3x4 m34(col0, col1, col2);
		glm::mat4x3 m43 = glm::transpose(m34);

 		Effekseer::Matrix43 effekMat;
		memcpy(effekMat.Value, glm::value_ptr(m43), sizeof(float) * 12);
		auto effect = g_effekseer->get_effect(eidx);
		effect->set_tranform(pidx, effekMat);
	}
	return 0;
}

static int
lplay(lua_State* L) {
	int32_t eidx = -1;
	int32_t pidx = -1;
	get_effect_from_lua(L, eidx, pidx);
	if (eidx != -1) {
		if (auto effect = g_effekseer->get_effect(eidx); effect) {
			int32_t start = 0;
			if (lua_type(L, 3) == LUA_TNUMBER) {
				start = lua_tointeger(L, 3);
			}
			pidx = effect->play(pidx, start);
		}
	}
	lua_pushinteger(L, pidx);
	return 1;
}

static int
lpause(lua_State* L) {
	int32_t eidx = -1;
	int32_t pidx = -1;
	get_effect_from_lua(L, eidx, pidx);
	if (eidx != -1) {
		if (auto effect = g_effekseer->get_effect(eidx); effect) {
			bool start = false;
			if (lua_type(L, 3) == LUA_TBOOLEAN) {
				start = lua_toboolean(L, 3);
			}
			effect->pause(pidx, start);
		}
	}
	return 0;
}

static int
lset_time(lua_State* L) {
	int32_t eidx = -1;
	int32_t pidx = -1;
	get_effect_from_lua(L, eidx, pidx);
	if (eidx != -1) {
		if (auto effect = g_effekseer->get_effect(eidx); effect) {
			int32_t frame = 0.0f;
			if (lua_type(L, 3) == LUA_TNUMBER) {
				frame = lua_tointeger(L, 3);
			}
			bool should_exist = true;
			if (!lua_isnoneornil(L, 4)) {
				should_exist = lua_toboolean(L, 4);
			}
			pidx = effect->set_time(pidx, frame, should_exist);
			lua_pushinteger(L, pidx);
			return 1;
		}
	}
	return 0;
}

static int
lstop(lua_State* L) {
	int32_t eidx = -1;
	int32_t pidx = -1;
	get_effect_from_lua(L, eidx, pidx);
	if (eidx != -1) {
		if (auto effect = g_effekseer->get_effect(eidx); effect) {
			effect->stop(pidx);
		}
	}
	return 0;
}

static int
lset_loop(lua_State* L) {
	int32_t eidx = -1;
	int32_t pidx = -1;
	get_effect_from_lua(L, eidx, pidx);
	if (eidx != -1) {
		if (auto effect = g_effekseer->get_effect(eidx); effect) {
			bool loop = false;
			if (lua_type(L, 3) == LUA_TBOOLEAN) {
				loop = lua_toboolean(L, 3);
			}
			effect->set_loop(pidx, loop);
		}
	}
	return 0;
}

static int
lis_playing(lua_State* L) {
	bool isplay = false;
	int32_t eidx = -1;
	int32_t pidx = -1;
	get_effect_from_lua(L, eidx, pidx);
	if (eidx != -1) {
		if (auto effect = g_effekseer->get_effect(eidx); effect) {
			isplay = effect->is_playing(pidx);
		}
	}
	lua_pushboolean(L, isplay);
	return 1;
}

static int
lset_speed(lua_State* L) {
	int32_t eidx = -1;
	int32_t pidx = -1;
	get_effect_from_lua(L, eidx, pidx);
	if (eidx != -1) {
		if (auto effect = g_effekseer->get_effect(eidx); effect) {
			luaL_checktype(L, 3, LUA_TNUMBER);
			float speed = lua_tonumber(L, 3);
			effect->set_speed(pidx, speed);
		}
	}
	return 0;
}

static int
lset_visible(lua_State* L) {
	int32_t eidx = -1;
	int32_t pidx = -1;
	get_effect_from_lua(L, eidx, pidx);
	if (eidx != -1) {
		if (auto effect = g_effekseer->get_effect(eidx); effect) {
			bool visible = true;
			if (lua_type(L, 3) == LUA_TBOOLEAN) {
				visible = lua_toboolean(L, 3);
			}
			effect->set_visible(pidx, visible);
		}
	}
	return 0;
}

void effekseer_ctx::update()
{
	for (auto& eff : effects_) {
		eff.update();
	}
}

void effekseer_ctx::draw(float delta)
{
	if (effects_.empty()) {
		return;
	}
	auto encoder = BGFX(encoder_begin)(false);
	assert(encoder);
	renderer_->SetCurrentEncoder(encoder);

	BGFX(set_view_transform)(viewid, view_mat_.Values, proj_mat_.Values);
	renderer_->SetCameraMatrix(view_mat_);
	renderer_->SetProjectionMatrix(proj_mat_);
	float deltaFrames = delta * 60.0f;
	int iterations = std::max(1, (int)roundf(deltaFrames));
	float advance = deltaFrames / iterations;
	for (int i = 0; i < iterations; i++) {
		manager_->Update(advance);
	}
	renderer_->SetTime(renderer_->GetTime() + delta);
	renderer_->BeginRendering();
	manager_->Draw();
	renderer_->EndRendering();

	BGFX(encoder_end)(encoder);
}

int32_t effekseer_ctx::create_effect(const void* data, int32_t size)
{
	auto effect = Effekseer::Effect::Create(manager_, data, size);
	if (effect.Get()) {
		effects_.emplace_back(manager_.Get(), effect);
		return (int32_t)effects_.size() - 1;
	}
	return -1;
}

effect_adapter* effekseer_ctx::get_effect(int32_t eidx)
{
	if (eidx < effects_.size() && eidx >= 0) {
		return &effects_[eidx];
	}
	return nullptr;
}

void effekseer_ctx::destroy_effect(int32_t eidx)
{
	effects_[eidx].destroy();
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_effekseer(lua_State * L) {
	luaL_Reg l[] = {
		{ "init",     leffekseer_init },
		{ "shutdown", leffekseer_shutdown },
		{ "update_view_proj",   leffekseer_update_view_proj },
		{ "update",   leffekseer_update },
		{ "update_transform", lupdate_transform },
		{ "create", lcreate},
		{ "destroy", ldestroy},
		{ "set_fxloader", lset_fxloader},
		{ "set_path_converter", lset_path_converter},
		{ "play", lplay},
		{ "pause", lpause},
		{ "set_time", lset_time},
		{ "stop", lstop},
		{ "set_visible", lset_visible},
		{ "set_speed", lset_speed},
		{ "set_loop", lset_loop},
		{ "is_playing", lis_playing},
		{ nullptr, nullptr },
	};
	luaL_newlib(L, l);
	return 1;
}