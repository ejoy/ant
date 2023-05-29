#pragma once

#if defined(__cplusplus)
#	include <lua.hpp>
#	include <utility>
#else
#	include <lua.h>
#	include <lauxlib.h>
#endif

struct ecs_context;
struct bgfx_interface_vtbl;
struct bgfx_encoder_s;
struct math3d_api;
struct render_material;

struct bgfx_encoder_holder {
	struct bgfx_encoder_s* encoder;
};

#if defined(__cplusplus)
	namespace ecs_world_ {
		template <int N>
		struct flag {
			friend constexpr int adl_flag(flag<N>);
		};
		template <int N>
		struct writer {
			friend constexpr int adl_flag(flag<N>) {
				return N;
			}
			static constexpr int value = N;
		};
		template <int N, class = char[noexcept(adl_flag(flag<N> ()))?+1:-1]>
		constexpr int reader(int, flag<N>) {
			return N;
		}
		template <int N>
		constexpr int reader(float, flag<N>, int R = reader (0, flag<N-1> ())) {
			return R;
		}
		constexpr int reader(float, flag<0>) {
			return 0;
		}
		template <int N = 1, int C = reader(0, flag<32> ())>
		constexpr int next(int R = writer<C + N>::value) {
			return R;
		}
		template <typename T>
		struct type { 
			static constexpr int id { next() };
			constexpr static int type_id () { return id; }
		};
	}
#endif

struct ecs_world {
	struct ecs_context*           ecs;
	struct bgfx_interface_vtbl*   bgfx;
	struct math3d_api*            math3d;
	struct bgfx_encoder_holder*   holder;
	struct render_material*		  R;
#if defined(__cplusplus)
	static constexpr size_t kMaxMember = 4;
	uintptr_t member[kMaxMember];

	template <typename T, typename ...Args>
	void create_member(Args&&... args) {
		constexpr size_t ID = ecs_world_::type<T>::type_id();
		static_assert(ID < kMaxMember);
		T* v = new T(std::forward<Args>(args)...);
		member[ID] = (uintptr_t)v;
	}

	template <typename T>
	void destroy_member() {
		constexpr size_t ID = ecs_world_::type<T>::type_id();
		static_assert(ID < kMaxMember);
		delete (T*)member[ID];
		member[ID] = 0;
	}

	template <typename T>
	T& get_member() {
		constexpr size_t ID = ecs_world_::type<T>::type_id();
		static_assert(ID < kMaxMember);
		return *(T*)member[ID];
	}

#endif
};

static inline struct ecs_world* getworld(lua_State* L) {
	size_t sz = 0;
	struct ecs_world* ctx = (struct ecs_world*)luaL_checklstring(L, lua_upvalueindex(1), &sz);
	if (sizeof(struct ecs_world) > sz) {
		luaL_error(L, "invalid ecs_world");
		return NULL;
	}
	return ctx;
}
