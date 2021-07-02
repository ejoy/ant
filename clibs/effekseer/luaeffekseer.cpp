#include <glm/glm.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtc/quaternion.hpp>
#include <glm/gtc/matrix_access.hpp>
#include <glm/gtx/transform.hpp>
#include <glm/gtx/quaternion.hpp>
#include <glm/gtx/compatibility.hpp>

#define EXPORT_BGFX_INTERFACE
extern "C" {
#include "../bgfx/bgfx_interface.h"
}
#include "effect.h"
#include "effekseer_context.h"
#include <../EffekseerRendererCommon/EffekseerRenderer.CommonUtils.h>

#include "lua2struct.h"

LUA2STRUCT(struct effekseer_ctx, viewid, square_max_count, programs, unlit_layout, lit_layout, distortion_layout, ad_unlit_layout, ad_lit_layout, ad_distortion_layout, mtl_layout);
LUA2STRUCT(struct program, prog, uniforms);
LUA2STRUCT(struct program::uniform, handle, name);

namespace EffekseerRendererBGFX {
extern bgfx_view_id_t g_view_id;
}

static effekseer_ctx* g_effekseer = nullptr;
static std::string g_current_path = "";
std::string get_ant_file_path(const std::string& path)
{
// 	lua_State* L = g_effekseer->lua_State_;
// 	std::string result;
// 	lua_pushlstring(L, path.data(), path.size());
// 	lua_rawgeti(L, LUA_REGISTRYINDEX, g_effekseer->filename_callback_);
// 	lua_insert(L, -2);
// 	lua_call(L, 1, 1);
// 	if (lua_type(L, -1) == LUA_TSTRING) {
// 		size_t sz = 0;
// 		const char* str = lua_tolstring(L, -1, &sz);
// 		result.assign(str, sz);
// 	}
// 	return result;
	return g_current_path + "/" + path;
}

effekseer_ctx::effekseer_ctx(lua_State* L, int idx)
	: lua_State_{ L }
{
	lua_struct::unpack(L, idx, *this);
	EffekseerRendererBGFX::g_view_id = viewid;
}

bool effekseer_ctx::init()
{
	auto shaderCount = static_cast<size_t>(EffekseerRenderer::RendererShaderType::Material) + 1;
	auto& bgfx_ctx = ::EffekseerRendererBGFX::Renderer::s_bgfx_context_;
	bgfx_ctx.resize(shaderCount);
	for (int i = 0; i < shaderCount; i++) {
		bgfx_ctx[i].program_.idx = programs[i].prog;
		//bgfx_ctx[i].vertex_layout_ = layouts[i];
		for (auto& uniformInfo : programs[i].uniforms) {
			bgfx_ctx[i].uniforms_[uniformInfo.name].idx = uniformInfo.handle;
		}
	}
	bgfx_ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::Unlit)].vertex_layout_ = unlit_layout;
	bgfx_ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::Lit)].vertex_layout_ = lit_layout;
	bgfx_ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::BackDistortion)].vertex_layout_ = distortion_layout;
	bgfx_ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::AdvancedUnlit)].vertex_layout_ = ad_unlit_layout;
	bgfx_ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::AdvancedLit)].vertex_layout_ = ad_lit_layout;
	bgfx_ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::AdvancedBackDistortion)].vertex_layout_ = ad_distortion_layout;
	bgfx_ctx[static_cast<size_t>(EffekseerRenderer::RendererShaderType::Material)].vertex_layout_ = mtl_layout;

	renderer = ::EffekseerRendererBGFX::Renderer::Create(square_max_count);
	if (!renderer.Get()) {
		return false;
	}
	manager = ::Effekseer::Manager::Create(square_max_count);
	if (!manager.Get()) {
		return false;
	}
	manager->SetCoordinateSystem(Effekseer::CoordinateSystem::LH);
	manager->SetSpriteRenderer(renderer->CreateSpriteRenderer());
	manager->SetRibbonRenderer(renderer->CreateRibbonRenderer());
	manager->SetRingRenderer(renderer->CreateRingRenderer());
	manager->SetTrackRenderer(renderer->CreateTrackRenderer());
	manager->SetModelRenderer(renderer->CreateModelRenderer());
	manager->SetTextureLoader(renderer->CreateTextureLoader());
	manager->SetModelLoader(renderer->CreateModelLoader());
	manager->SetMaterialLoader(renderer->CreateMaterialLoader());
	//test
// 	test_effect = Effekseer::Effect::Create(manager, u"D:/Github/EffekseerBGFX/Resources/Base/Laser03.efk");
// 	test_handle = manager->Play(test_effect, { 0, 0, 0 });
	//manager->SetPaused(test_handle, true);

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
	g_effekseer->test_effect.Reset();
	g_effekseer->manager.Reset();
	g_effekseer->renderer.Reset();
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
	memcpy(g_effekseer->view_mat.Values, (float*)glm::value_ptr(viewmat), sizeof(float) * 16);
	memcpy(g_effekseer->proj_mat.Values, (float*)glm::value_ptr(projmat), sizeof(float) * 16);
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
	if (lua_type(L, 1) == LUA_TSTRING && lua_type(L, 2) == LUA_TSTRING) {
		size_t sz;
		g_current_path = std::string(lua_tolstring(L, 2, &sz));
		const char* data = lua_tolstring(L, 1, &sz);
		auto eidx = g_effekseer->create_effect(data, (int32_t)sz);
		lua_pop(L, 2);
		if (eidx != -1) {
			lua_pushinteger(L, eidx);
			return 1;
		} else {
			return luaL_error(L, "create effect failed.");
		}
	}
	return 0;
}

static int
ldestroy(lua_State* L) {
	if (lua_type(L, 1) == LUA_TNUMBER) {
		int32_t eidx = lua_tointeger(L, -1);
		g_effekseer->destroy_effect(eidx);
		lua_pop(L, 1);
	}
	return 0;
}

static int
lset_filename_callback(lua_State* L) {
	g_effekseer->filename_callback_ = luaL_ref(L, LUA_REGISTRYINDEX);
	return 0;
}

static int32_t get_effect_index(lua_State* L)
{
	int32_t eidx = -1;
	if (lua_type(L, 1) == LUA_TNUMBER) {
		eidx = lua_tointeger(L, 1);
	}
	return eidx;
}
static int
lupdate_transform(lua_State* L) {
	int32_t eidx = get_effect_index(L);
	if (eidx != -1) {
		glm::mat4x4* m44 = (glm::mat4x4*)lua_touserdata(L, 2);
		auto col0 = glm::row(*m44, 0);
		auto col1 = glm::row(*m44, 1);
		auto col2 = glm::row(*m44, 2);
		glm::mat3x4 m34(col0, col1, col2);
		glm::mat4x3 m43 = glm::transpose(m34);

 		Effekseer::Matrix43 effekMat;
		memcpy(effekMat.Value, glm::value_ptr(m43), sizeof(float) * 12);
		auto effect = g_effekseer->get_effect(eidx);
		effect->set_tranform(effekMat);
	}
	return 0;
}

static int
lplay(lua_State* L) {
	int32_t eidx = get_effect_index(L);
	if (eidx != -1) {
		auto effect = g_effekseer->get_effect(eidx);
		if (effect) {
			int32_t start = 0;
			if (lua_type(L, 2) == LUA_TNUMBER) {
				start = lua_tointeger(L, 2);
			}
			effect->play(start);
		}
	}
	return 0;
}

static int
lpause(lua_State* L) {
	int32_t eidx = get_effect_index(L);
	if (eidx != -1) {
		auto effect = g_effekseer->get_effect(eidx);
		if (effect) {
			bool start = false;
			if (lua_type(L, 2) == LUA_TBOOLEAN) {
				start = lua_toboolean(L, 2);
			}
			effect->pause(start);
		}
	}
	return 0;
}

static int
lset_time(lua_State* L) {
	int32_t eidx = get_effect_index(L);
	if (eidx != -1) {
		auto effect = g_effekseer->get_effect(eidx);
		if (effect) {
			int32_t frame = 0.0f;
			if (lua_type(L, 2) == LUA_TNUMBER) {
				frame = lua_tointeger(L, 2);
			}
			effect->set_time(frame);
		}
	}
	return 0;
}

static int
lstop(lua_State* L) {
	int32_t eidx = get_effect_index(L);
	if (eidx != -1) {
		auto effect = g_effekseer->get_effect(eidx);
		if (effect) {
			effect->stop();
		}
	}
	return 0;
}

static int
lset_loop(lua_State* L) {
	int32_t eidx = get_effect_index(L);
	if (eidx != -1) {
		auto effect = g_effekseer->get_effect(eidx);
		if (effect) {
			luaL_checktype(L, 2, LUA_TBOOLEAN);
			effect->set_loop(lua_toboolean(L, 2));
		}
	}
	return 0;
}

static int
lis_playing(lua_State* L) {
	bool isplay = false;
	int32_t eidx = get_effect_index(L);
	if (eidx != -1) {
		auto effect = g_effekseer->get_effect(eidx);
		if (effect)
		{
			isplay = effect->is_playing();
		}
	}
	lua_pushboolean(L, isplay);
	return 1;
}

static int
lset_speed(lua_State* L) {
	int32_t eidx = get_effect_index(L);
	if (eidx != -1) {
		auto effect = g_effekseer->get_effect(eidx);
		if (effect)
		{
			luaL_checktype(L, 2, LUA_TNUMBER);
			float speed = lua_tonumber(L, 2);
			effect->set_speed(speed);
		}
	}
	return 0;
}

void effekseer_ctx::update()
{
	for (auto& eff : effects)
	{
		eff.update();
	}
}

void effekseer_ctx::draw(float delta)
{
	if (effects.empty())
	{
		return;
	}
	BGFX(set_view_transform)(viewid, view_mat.Values, proj_mat.Values);
	renderer->SetCameraMatrix(view_mat);
	renderer->SetProjectionMatrix(proj_mat);
	float deltaFrames = delta * 60.0f;
	int iterations = std::max(1, (int)roundf(deltaFrames));
	float advance = deltaFrames / iterations;
	for (int i = 0; i < iterations; i++) {
		manager->Update(advance);
	}
	renderer->SetTime(renderer->GetTime() + delta);
	renderer->BeginRendering();
	manager->Draw();
	renderer->EndRendering();
}

int32_t effekseer_ctx::create_effect(const void* data, int32_t size)
{
	auto effect = Effekseer::Effect::Create(manager, data, size);
	if (effect.Get()) {
		effects.emplace_back(manager.Get(), effect);
		return (int32_t)effects.size() - 1;
	}
	return -1;
}

effect_adapter* effekseer_ctx::get_effect(int32_t eidx)
{
	if (eidx < effects.size() && eidx >= 0)
	{
		return &effects[eidx];
	}
	return nullptr;
}

void effekseer_ctx::destroy_effect(int32_t eidx)
{
	effects[eidx].destroy();
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_effekseer(lua_State * L) {
	init_interface(L);
	luaL_Reg l[] = {
		{ "init",     leffekseer_init },
		{ "shutdown", leffekseer_shutdown },
		{ "update_view_proj",   leffekseer_update_view_proj },
		{ "update",   leffekseer_update },
		{ "update_transform", lupdate_transform },
		{ "create", lcreate},
		{ "destroy", ldestroy},
		{ "set_filename_callback", lset_filename_callback},
		{ "play", lplay},
		{ "pause", lpause},
		{ "set_time", lset_time},
		{ "stop", lstop},
		{ "set_speed", lset_speed},
		{ "set_loop", lset_loop},
		{ "is_playing", lis_playing},
		{ nullptr, nullptr },
	};
	luaL_newlib(L, l);
	return 1;
}