#include <lua.hpp>
#include <cassert>
#include <cstring>

#include <bgfx/c99/bgfx.h>

#include "efkbgfx/renderer/bgfxrenderer.h"
#include "../../clibs/bgfx/bgfx_interface.h"
#include <Effekseer/Effekseer.DefaultEffectLoader.h>

#include "fastio.h"
extern "C" {
	#include <textureman.h>
}

struct efk_slot {
	Effekseer::EffectRef eptr;
	Effekseer::Handle inst;
	union {
		int next;
		int n;
	};
	bool shown;
	bool fadeout;
	std::vector<Effekseer::Handle> clone;
};

static inline void
ToMatrix43(const Effekseer::Matrix44& src, Effekseer::Matrix43& dst) {
	for (int m = 0; m < 4; m++) {
		for (int n = 0; n < 3; n++) {
			dst.Value[m][n] = src.Values[m][n];
		}
	}
}

class efk_ctx {
public:
	efk_ctx() = default;
	~efk_ctx() = default;
public:
	bool init(EffekseerRendererBGFX::InitArgs &efkargs) {
		renderer = EffekseerRendererBGFX::CreateRenderer(&efkargs);
		if (renderer == nullptr){
			return false;
		}
		manager = Effekseer::Manager::Create(efkargs.squareMaxCount);
		manager->GetSetting()->SetCoordinateSystem(Effekseer::CoordinateSystem::LH);

		manager->SetModelRenderer(CreateModelRenderer(renderer, &efkargs));
		manager->SetSpriteRenderer(renderer->CreateSpriteRenderer());
		manager->SetRibbonRenderer(renderer->CreateRibbonRenderer());
		manager->SetRingRenderer(renderer->CreateRingRenderer());
		manager->SetTrackRenderer(renderer->CreateTrackRenderer());
		manager->SetTextureLoader(renderer->CreateTextureLoader());
		manager->SetCurveLoader(Effekseer::MakeRefPtr<Effekseer::CurveLoader>());

		drawParameter.ZNear = 0.f;
		drawParameter.ZFar = 0.f;
		return true;
	}

	void set_state(const Effekseer::Matrix44 &viewmat, const Effekseer::Matrix44 &projmat, float delta) {
		renderer->SetCameraMatrix(viewmat);
		renderer->SetProjectionMatrix(projmat);
		renderer->SetTime(renderer->GetTime() + delta);
		drawParameter.ViewProjectionMatrix = renderer->GetCameraProjectionMatrix();
	}

	void update() {
		// Stabilize in	a variable frame environment
		// float deltaFrames = delta * 60.0f;
		// int iterations =	std::max(1,	(int)roundf(deltaFrames));
		// float advance = deltaFrames / iterations;
		// for (int	i =	0; i < iterations; i++)	{
		//	   ctx->manager->Update(advance);
		// }
		manager->Update();
	}

	void render() {
		renderer->BeginRendering();
		manager->Draw(drawParameter);
		renderer->EndRendering();
	}

	void reset(){
		// set invisible
		for (auto &slot : effects) {
			if (slot.eptr != nullptr) {
				manager->SetShown(slot.inst, false);
				if (slot.n == 0) {
					for (auto handle : slot.clone) {
						manager->StopEffect(handle);
					}
					slot.clone.resize(0);
				} else {
					for (auto handle : slot.clone) {
						manager->SetShown(handle, false);
					}
					slot.n = 0;
				}
			}
		}
	}
private:
	inline int
	alloc_efk_slot(){
		if (freelist >= 0) {
			auto slot = effects[freelist];
			const int handle = freelist;
			freelist = slot.next;
			return handle;
		}

		const int handle = (int)effects.size();
		effects.resize(handle + 1);
		return handle;
	}

public:
	inline bool
	slot_valid(int handle) const {
		return (0 <= handle && handle < (int)effects.size()) && (effects[handle].eptr != nullptr);
	}

	inline void
	slot_valid(lua_State *L, int handle) {
		if (!slot_valid(handle)) {
			luaL_error(L, "invalid handle: %d", handle);
		}
	}

	int slot_new(Effekseer::EffectRef ep) {
		const int handle = alloc_efk_slot();
		assert(0 <= handle && handle < (int)effects.size());
		auto& slot = effects[handle];
		slot.eptr = ep;
		slot.inst = -1;
		slot.n = 0;
		slot.shown = true;
		slot.fadeout = false;
		return handle;
	}

	void
	slot_remove(int handle) {
		assert(slot_valid(handle));
		auto& slot = effects[handle];
		slot_stop(slot, false);
		slot.eptr = nullptr;
		slot.next = this->freelist;
		this->freelist = handle;
	}

	struct efk_slot&
	slot_from_lua(lua_State *L, int index)	{
		const int handle = (int)luaL_checkinteger(L, index);
		slot_valid(L, handle);
		return effects[handle];
	}

	void
	slot_show(struct efk_slot &slot, bool show){
		manager->SetShown(slot.inst, show);
		for (auto &c : slot.clone){
			manager->SetShown(c, show);
		}
	}

	void
	slot_stop(struct efk_slot& slot, bool fadeout) {
		if (slot.inst < 0)
			return;

		if (fadeout) {
			manager->SetSpawnDisabled(slot.inst, true);
			for (auto handle : slot.clone) {
				manager->SetSpawnDisabled(handle, true);
			}
		} else {
			manager->StopEffect(slot.inst);
			for (auto handle : slot.clone) {
				manager->StopEffect(handle);
			}
		}
		slot.inst = -1;
		slot.clone.resize(0);
		slot.n = 0;
	}

	void
	slot_pause(struct efk_slot &slot, bool pause) {
		manager->SetPaused(slot.inst, pause);
		for (auto handle : slot.clone) {
			manager->SetPaused(handle, pause);
		}
	}

	void
	slot_set_time(struct efk_slot &slot, float frame) {
		manager->SetPaused(slot.inst, false);
		manager->UpdateHandleToMoveToFrame(slot.inst, frame);
		manager->SetPaused(slot.inst, true);

		for (auto handle : slot.clone) {
			manager->SetPaused(handle, false);
			manager->UpdateHandleToMoveToFrame(handle, frame);
			manager->SetPaused(handle, true);
		}
	}

	void
	slot_speed(struct efk_slot &slot, float speed) {
		manager->SetSpeed(slot.inst, speed);
		for (auto handle : slot.clone)	{
			manager->SetSpeed(handle, speed);
		}
	}

	void
	slot_play(struct efk_slot& slot, float speed, int32_t startframe, bool fadeout){
		if (manager->Exists(slot.inst)) {
			slot_show(slot, fadeout);
			slot_stop(slot, fadeout);
		}

		slot.fadeout = false;	//reset fadeout to false
		slot.inst = manager->Play(slot.eptr, Effekseer::Vector3D(0, 0, 0), startframe);
		manager->SetSpeed(slot.inst, speed);
	}

	void
	slot_clone(struct efk_slot& slot, const	Effekseer::Matrix43 &mat) {
		const Effekseer::Handle handle = manager->Play(slot.eptr, 0, 0, 0);
		manager->SetShown(handle, slot.shown);
		const float speed = manager->GetSpeed(slot.inst);
		manager->SetSpeed(handle, speed);
		const bool paused = manager->GetPaused(slot.inst);
		manager->SetPaused(handle, paused);
		slot.clone.emplace_back(handle);
		++slot.n;
	}

	void
	slot_update(struct efk_slot& slot, const Effekseer::Matrix44& effekMat44){
		if (manager->Exists(slot.inst)) {
			if (slot.shown) {
				Effekseer::Matrix43 effekMat; ToMatrix43(effekMat44, effekMat);
				if (slot.n == 0) {
					manager->SetMatrix(slot.inst, effekMat);
					manager->SetShown(slot.inst, true);
					slot.n = 1;
				} else {
					const int	idx = slot.n - 1;
					if (idx < (int)slot.clone.size()) {
						manager->SetMatrix(slot.clone[idx], effekMat);
						manager->SetShown(slot.clone[idx], true);
						++slot.n;
					} else {
						slot_clone(slot, effekMat);
					}
				}
				if (slot.fadeout) {
					slot_stop(slot, true);
				}
			} else {
				slot_stop(slot, false);
			}
		}
	}
public:
	EffekseerRenderer::RendererRef		renderer;
	Effekseer::ManagerRef				manager;
	Effekseer::Manager::DrawParameter	drawParameter;

	std::vector<efk_slot> 				effects;
	int	freelist = -1;
};

static efk_ctx*
EC(lua_State *L, int idx=1){
	return (efk_ctx*)lua_touserdata(L, idx);
}

static inline Effekseer::Matrix44*
TOM(lua_State *L, int index){
	const int t = lua_type(L, index);
	if (t == LUA_TUSERDATA || t	== LUA_TLIGHTUSERDATA) {
		return (Effekseer::Matrix44*)lua_touserdata(L, index);
	}

	if (t == LUA_TSTRING){
		return (Effekseer::Matrix44*)lua_tostring(L, index);
	}

	luaL_error(L, "Invalid data:%d,	type:%s", index, lua_typename(L, index));

	return nullptr;
}


static inline Effekseer::Vector3D*
TOV(lua_State *L, int index){
	const int t = lua_type(L, index);
	if (t == LUA_TUSERDATA || t == LUA_TLIGHTUSERDATA){
		return (Effekseer::Vector3D*)lua_touserdata(L, index);
	}

	if (t == LUA_TSTRING){
		return (Effekseer::Vector3D*)lua_tostring(L, index);
	}

	luaL_error(L, "Invalid data:%d,	type:%s", index, lua_typename(L, index));

	return nullptr;
}

static inline Effekseer::Color*
TOC(lua_State *L, int index){
	const int t = lua_type(L, index);
	if (t == LUA_TUSERDATA || t == LUA_TLIGHTUSERDATA){
		return (Effekseer::Color*)lua_touserdata(L,	index);
	}

	if (t == LUA_TSTRING){
		return (Effekseer::Color*)lua_tostring(L, index);
	}

	luaL_error(L, "Invalid data:%d,	type:%s", index, lua_typename(L, index));

	return nullptr;
}

static int
lefkctx_handle(lua_State *L) {
	lua_pushlightuserdata(L, EC(L, 1));
	return 1;
}

static int
lefkctx_setstate(lua_State *L) {
	auto ctx = EC(L, 1);
	auto viewmat = TOM(L, 2);
	auto projmat = TOM(L, 3);
	auto delta = (float)luaL_checknumber(L, 4) * 0.001f;

	ctx->set_state(*viewmat, *projmat, delta);
	return 0;
}

static int
lefkctx_render(lua_State *L){
	auto ctx = EC(L, 1);
	ctx->update();
	ctx->render();
	ctx->reset();
	return 0;
}

struct efk_box {
	Effekseer::EffectRef eptr;
};

static int
lefk_release(lua_State *L) {
	struct efk_box *box = (struct efk_box *)luaL_checkudata(L, 1, "EFK_INSTANCE");
	box->eptr = nullptr;
	return 0;
}

static int
lefkctx_new(lua_State *L) {
	auto ctx = EC(L, 1);
	auto content = getmemory(L, 2);
	char16_t u16_materialPath[1024];
	auto materialPath = luaL_checkstring(L, 3);
	Effekseer::ConvertUtf8ToUtf16(u16_materialPath, 1024, materialPath);

	const float mag = (float)luaL_optnumber(L, 4, 1.f);

	struct efk_box *box = (struct efk_box *)lua_newuserdatauv(L, sizeof(*box), 0);
	new	(&box->eptr) Effekseer::EffectRef(Effekseer::Effect::Create(ctx->manager, content.data(), (int)content.size(), mag,	u16_materialPath));
	if (luaL_newmetatable(L, "EFK_INSTANCE")) {
		lua_pushcfunction(L, lefk_release);
		lua_setfield(L, -2, "__gc");
		lua_pushcfunction(L, lefk_release);
		lua_setfield(L, -2, "release");
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

static int
lefkctx_create(lua_State *L) {
	auto ctx = EC(L, 1);
	struct efk_box *box = (struct efk_box *)luaL_checkudata(L, 2, "EFK_INSTANCE");
	if (box->eptr == nullptr) {
		return luaL_error(L, "Released effect");
	}

	lua_pushinteger(L, ctx->slot_new(box->eptr));
	return 1;
}

static int
lefkctx_destroy(lua_State *L) {
	EC(L, 1)->slot_remove((int)luaL_checkinteger(L, 2));
	return 0;
}

static int
lefkctx_update_transform(lua_State *L) {
	auto ctx = EC(L, 1);
	ctx->slot_update(ctx->slot_from_lua(L, 2), *TOM(L, 3));
	return 0;
}

static int
lefkctx_update_transforms(lua_State *L){
	auto ctx = EC(L);
	const uint32_t num = (uint32_t)luaL_checkinteger(L, 2);
	constexpr uint32_t MAX_EFK_HITCH = 256;
	if (num	== 0 || num >= MAX_EFK_HITCH){
		return luaL_error(L, "Max hitch transform should lower than %d, %d provided", MAX_EFK_HITCH, num);
	}
	struct transform_data {
		uint32_t handle;
		float* data;
	};

	const transform_data* td = (const transform_data*)lua_touserdata(L, 3);
	if (td == nullptr){
		return luaL_error(L, "Invalid transform data");
	}

	for	(uint32_t ii=0; ii<num; ++ii){
		const auto& t = td[ii];
		ctx->slot_valid(L, t.handle);
		ctx->slot_update(ctx->effects[t.handle], *reinterpret_cast<const Effekseer::Matrix44*>(t.data));
	}

	return 0;
}

static int
lefkctx_is_alive(lua_State *L) {
	auto ctx = EC(L);
	const int handle = (int)luaL_checkinteger(L, 2);

	lua_pushboolean(L,
		ctx->slot_valid(handle) &&
		ctx->manager->Exists(ctx->effects[handle].inst));
	return 1;
}

static int
lefkctx_play(lua_State *L) {
	auto ctx = EC(L, 1);
	auto& slot = ctx->slot_from_lua(L, 2);
	const float speed = (float)luaL_optnumber(L, 3, 1.0f);
	const int32_t startframe = (int32_t)luaL_optinteger(L, 4, 0);
	const bool fadeout = lua_toboolean(L, 5);
	ctx->slot_play(slot, speed, startframe, fadeout);
	return 0;
}

static int
lefkctx_stop(lua_State *L){
	auto ctx = EC(L);
	auto& slot = ctx->slot_from_lua(L, 2);
	const bool fadeout = lua_toboolean(L, 3);
	if (fadeout) {
		slot.fadeout = true;
	} else {
		ctx->slot_stop(slot, false);
	}
	return 0;
}

static int
lefkctx_set_visible(lua_State *L) {
	auto ctx = EC(L, 1);
	auto& slot = ctx->slot_from_lua(L, 2);
	slot.shown = (lua_type(L, 3) == LUA_TBOOLEAN) ? lua_toboolean(L, 3) : true;
	return 0;
}

static int
lefkctx_pause(lua_State *L) {
	auto ctx = EC(L, 1);
	auto& slot = ctx->slot_from_lua(L, 2);
	ctx->slot_pause(slot, lua_type(L, 3) == LUA_TBOOLEAN ? lua_toboolean(L, 3) : false);
	return 0;
}

static int
lefkctx_set_time(lua_State *L) {
	auto ctx = EC(L, 1);
	const float frame = std::max(0.f, (float)luaL_optnumber(L, 3, 0.f));
	ctx->slot_set_time(ctx->slot_from_lua(L, 2), frame);
	return 0;
}

static int
lefkctx_set_speed(lua_State *L) {
	auto ctx = EC(L);
	auto& slot = ctx->slot_from_lua(L, 2);

	const float speed = (float)lua_tonumber(L, 3);
	ctx->slot_speed(slot, speed);
	return 0;
}

static int
lefkctx_set_light_direction(lua_State *L) {
	auto ctx = EC(L);
	auto direction = TOV(L, 2);
	ctx->renderer->SetLightDirection(*direction);
	return 0;
}

static int
lefkctx_set_light_color(lua_State *L) {
	auto ctx = EC(L, 1);
	auto color = TOC(L,	2);
	ctx->renderer->SetLightColor(*color);
	return 0;
}

static int
lefkctx_set_ambient_color(lua_State *L) {
	auto ctx = EC(L, 1);
	auto ambient = TOC(L, 2);
	ctx->renderer->SetLightAmbientColor(*ambient);
	return 0;
}

static inline void
fetch_efk_args(lua_State *L, int index, EffekseerRendererBGFX::InitArgs &args) {
	args.invz = true;	//we use inverse z
	auto get_field = [L](const char* name, int idx, int luatype, auto op){
		auto ltype = lua_getfield(L, idx, name);
		if (luatype	== ltype){
			op();
		} else {
			luaL_error(L, "invalid field:%s, miss match	type:%s, %s", lua_typename(L, ltype), lua_typename(L, luatype));
		}

		lua_pop(L, 1);
	};
	
	get_field("max_count", 1, LUA_TNUMBER,	[&](){args.squareMaxCount = (int)lua_tointeger(L, -1);});
	get_field("viewid", 1, LUA_TNUMBER,	[&](){args.viewid = (bgfx_view_id_t)lua_tointeger(L, -1);});

	args.bgfx = bgfx_inf_;

	get_field("shader_load", 1, LUA_TLIGHTUSERDATA, [&](){args.shader_load = (decltype(args.shader_load))lua_touserdata(L, -1);});
	get_field("texture_load", 1, LUA_TLIGHTUSERDATA, [&](){args.texture_load = (decltype(args.texture_load))lua_touserdata(L, -1);});
	get_field("texture_get", 1, LUA_TLIGHTUSERDATA, [&](){args.texture_get = (decltype(args.texture_get))lua_touserdata(L, -1);});
	get_field("texture_unload", 1, LUA_TLIGHTUSERDATA, [&](){args.texture_unload = (decltype(args.texture_unload))lua_touserdata(L, -1);});
	get_field("texture_handle", 1, LUA_TLIGHTUSERDATA, [&](){args.texture_handle = (decltype(args.texture_handle))lua_touserdata(L, -1);});
	get_field("userdata", 1, LUA_TTABLE, [&]() {
		get_field("callback", -1, LUA_TUSERDATA, [&](){args.ud = lua_touserdata(L, -1);});
	});
}

static int
lefk_startup(lua_State *L){
	luaL_checktype(L, 1, LUA_TTABLE);

	EffekseerRendererBGFX::InitArgs	efkArgs;
	fetch_efk_args(L, 2, efkArgs);

	auto ctx = (efk_ctx*)lua_newuserdatauv(L, sizeof(efk_ctx), 0);
	new	(ctx)efk_ctx();
	if (luaL_newmetatable(L, "EFK_CTX")){
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
		luaL_Reg l[] = {
			{"handle",				lefkctx_handle},
			{"setstate",			lefkctx_setstate},
			{"render",				lefkctx_render},
			{"new",					lefkctx_new},
			{"create",				lefkctx_create},
			{"destroy",				lefkctx_destroy},
			{"play",				lefkctx_play},
			{"stop",				lefkctx_stop},
			{"set_visible",			lefkctx_set_visible},
			{"pause",				lefkctx_pause},
			{"set_time",			lefkctx_set_time},
			{"set_speed",			lefkctx_set_speed},
			{"update_transform",	lefkctx_update_transform},
			{"update_transforms",	lefkctx_update_transforms},
			{"is_alive",			lefkctx_is_alive},
			{"set_light_direction",	lefkctx_set_light_direction},
			{"set_light_color",		lefkctx_set_light_color},
			{"set_ambient_color",	lefkctx_set_ambient_color},
			{nullptr, nullptr},
		};

		luaL_setfuncs(L, l, 0);
	}
	lua_setmetatable(L, -2);

	new	(ctx) efk_ctx();

	if (!ctx->init(efkArgs)){
		return luaL_error(L, "create efk_ctx init failed");
	}
	return 1;
}

static int
lefk_shutdown(lua_State *L){
	auto ctx = EC(L);
	ctx->manager.Reset();
	ctx->renderer.Reset();
	ctx->~efk_ctx();
	return 0;
}

extern "C" int
luaopen_efk(lua_State *L) {
	luaL_Reg lib[] = {
		{ "startup", lefk_startup},
		{ "shutdown",lefk_shutdown},
		{ nullptr, nullptr },
	};
	luaL_newlib(L, lib);
	return 1;
}
