#pragma once

struct lua_State;

#include "luaecs.h"
#include <type_traits>
#include <tuple>
#include <array>
#include <cstdint>

namespace ecs_api {
    namespace flags {
        struct absent {};
    }
    constexpr int EID = 0xFFFFFFFF;

    template <typename T>
    struct component {};

    template <typename T>
    constexpr int component_id = component<T>::id;

    namespace impl {
        template <typename Component, typename...Components>
        constexpr bool has_element() {
            constexpr std::array<bool, sizeof...(Components)> same {std::is_same_v<Component, Components>...};
            for (size_t i = 0; i < sizeof...(Components); ++i) {
                if (same[i]) {
                    return true;
                }
            }
            return false;
        }
        
        template <typename Component, typename...Components>
        constexpr bool has_element_v = has_element<Component, Components...>();
    }

    template <typename MainKey, typename...Components>
    struct cached {
        using mainkey = MainKey;
        struct ecs_context* ctx;
        struct ecs_cache* c;
        int n = 0;
        cached(struct ecs_context* ctx) noexcept {
            std::array<int, 1+sizeof...(Components)> keys {component<MainKey>::id, component<Components>::id...};
            struct ecs_cache* c = entity_cache_create(ctx, keys.data(), static_cast<int>(keys.size()));
            this->ctx = ctx;
            this->c = c;
        }
        ~cached() noexcept {
            entity_cache_release(ctx, c);
        }
    };

    template <typename Component, typename MainKey, typename...Components>
    Component* cache_fetch(cached<MainKey, Components...>& cache, int index) noexcept {
        static_assert(impl::has_element_v<Component, Components...>);
        return (Component*)entity_cache_fetch(cache.ctx, cache.c, index, component<Component>::id);
    }

    template <typename MainKey, typename...Components>
    void cache_sync(cached<MainKey, Components...>& cache) noexcept {
        cache.n = entity_cache_sync(cache.ctx, cache.c);
    }

    namespace impl {
        inline ecs_context* context(ecs_context& ctx) {
            return &ctx;
        }
        template <typename Cached>
        ecs_context* context(Cached& cache) {
            return cache.ctx;
        }

        template <typename Component>
        Component* iter(ecs_context& ctx, int i) noexcept {
            static_assert(!std::is_function<Component>::value);
            return (Component*)entity_iter(&ctx, component<Component>::id, i);
        }

        template <typename Component, typename Cached>
            requires (!std::is_function_v<Component> && component<Component>::tag)
        Component* iter(Cached& cache, int i) noexcept {
            return i < cache.n
                ? (Component*)(~(uintptr_t)0)
                : nullptr;
        }

        template <typename Component, typename Cached>
            requires (!std::is_function_v<Component> && !component<Component>::tag && component<Component>::id != EID)
        Component* iter(Cached& cache, int i) noexcept {
            return cache_fetch<Component>(cache, i);
        }

        template <typename Component, typename Cached>
            requires (!std::is_function_v<Component> && component<Component>::id == EID)
        Component* iter(Cached& cache, int i) noexcept {
            return (Component*)entity_iter(cache.ctx, EID, i);
        }

        template <typename Component>
        Component* sibling(ecs_context& ctx, int mainkey, int i) noexcept {
            static_assert(!std::is_function<Component>::value);
            return (Component*)entity_sibling(&ctx, mainkey, i, component<Component>::id);
        }

        template <typename Component, typename Cached>
            requires (!std::is_function_v<Component> && component<Component>::id != EID)
        Component* sibling(Cached& cache, [[maybe_unused]] int mainkey, int i) noexcept {
            return cache_fetch<Component>(cache, i);
        }

        template <typename Component, typename Cached>
            requires (!std::is_function_v<Component> && component<Component>::id == EID)
        Component* sibling(Cached& cache, [[maybe_unused]] int mainkey, int i) noexcept {
            return (Component*)entity_sibling(cache.ctx, component<typename Cached::mainkey>::id, i, EID);
        }

        template <typename Component>
        Component* sibling(ecs_context* ctx, int mainkey, int i, lua_State* L) {
            static_assert(!std::is_function<Component>::value);
            auto c = sibling<Component>(ctx, mainkey, i);
            if (c == NULL) {
                luaL_error(L, "component `%s` not found.", component<Component>::name);
            }
            return c;
        }

        inline void sync(ecs_context& ctx) noexcept {
        }

        template <typename Cached>
        void sync(Cached& cache) noexcept {
            cache_sync(cache);
        }

        template <typename...Ts>
        using components = decltype(std::tuple_cat(
            std::declval<std::conditional_t<std::is_empty<Ts>::value || std::is_function<Ts>::value,
                std::tuple<>,
                std::tuple<Ts*>
            >>()...
        ));

        template <std::size_t Is, typename T>
        static constexpr std::size_t next() noexcept {
            if constexpr (std::is_empty<T>::value || std::is_function<T>::value) {
                return Is;
            }
            else {
                return Is+1;
            }
        }
    }

    template <typename Context, typename MainKey, typename ...SubKey>
    struct basic_entity {
    public:
        basic_entity(Context& ctx) noexcept
            : ctx(ctx)
        { }
        template <typename Component>
            requires (component<Component>::id == EID && component<MainKey>::id == EID)
        basic_entity(Context& ctx, Component eid) noexcept
            : ctx(ctx) {
            index = entity_index(impl::context(ctx), (void*)eid);
            std::get<Component*>(c) = (Component*)eid;
        }
        static constexpr int kInvalidIndex = -1;
        enum class fetch_status: uint8_t {
            success,
            failed,
            eof,
        };
        fetch_status fetch(int id) noexcept {
            auto v = impl::iter<MainKey>(ctx, id);
            if (!v) {
                return fetch_status::eof;
            }
            assgin<0>(v);
            if constexpr (sizeof...(SubKey) == 0) {
                return fetch_status::success;
            }
            else {
                if (init_sibling<impl::next<0, MainKey>(), SubKey...>(id)) {
                    return fetch_status::success;
                }
                return fetch_status::failed;
            }
        }
        bool init(int id) noexcept {
            if (fetch_status::success != fetch(id)) {
                index = kInvalidIndex;
                return false;
            }
            index = id;
            return true;
        }
        void next() noexcept {
            for (++index;;++index) {
                switch (fetch(index)) {
                case fetch_status::success:
                    return;
                case fetch_status::eof:
                    index = kInvalidIndex;
                    return;
                default:
                    break;
                }
            }
        }
        void remove() const noexcept {
            entity_remove(impl::context(ctx), component<MainKey>::id, index);
        }
        int getid() const noexcept {
            return index;
        }
        bool invalid() const {
            return index == kInvalidIndex;
        }
        template <typename T>
            requires (component<T>::id == EID)
        T get() noexcept {
            return (T)std::get<T*>(c);
        }
        template <typename T>
            requires (component<T>::id != EID && !std::is_empty<T>::value)
        T& get() noexcept {
            return *std::get<T*>(c);
        }
        template <typename T>
            requires (component<T>::id == EID)
        bool has() const noexcept {
            return true;
        }
        template <typename T>
            requires (component<T>::id != EID)
        bool has() const noexcept {
            return !!impl::sibling<T>(ctx, component<MainKey>::id, index);
        }
        template <typename T>
            requires (component<T>::tag)
        bool sibling() const noexcept {
            return !!impl::sibling<T>(ctx, component<MainKey>::id, index);
        }
        template <typename T>
            requires (component<T>::id != EID && !component<T>::tag && !std::is_empty<T>::value)
        T* sibling() const noexcept {
            return impl::sibling<T>(ctx, component<MainKey>::id, index);
        }
        template <typename T>
            requires (component<T>::id == EID)
        T sibling() const noexcept {
            return (T)impl::sibling<T>(ctx, component<MainKey>::id, index);
        }
        template <typename T>
            requires (component<T>::id == EID)
        T sibling(lua_State* L) const {
            return (T)impl::sibling<T>(ctx, component<MainKey>::id, index, L);
        }
        template <typename T>
            requires (component<T>::id != EID && !std::is_empty<T>::value)
        T& sibling(lua_State* L) const {
            return *impl::sibling<T>(ctx, component<MainKey>::id, index, L);
        }
        template <typename T>
            requires (component<T>::tag)
        void enable_tag() noexcept {
            entity_enable_tag(impl::context(ctx), component<MainKey>::id, index, component<T>::id);
        }
        void enable_tag(int id) noexcept {
            entity_enable_tag(impl::context(ctx), component<MainKey>::id, index, id);
        }
        template <typename T>
            requires (component<T>::tag)
        void disable_tag() noexcept {
            entity_disable_tag(impl::context(ctx), component<MainKey>::id, index, component<T>::id);
        }
        void disable_tag(int id) noexcept {
            entity_disable_tag(impl::context(ctx), component<MainKey>::id, index, id);
        }
    private:
        template <std::size_t Is, typename T>
        void assgin(T* v) noexcept {
            if constexpr (!std::is_empty<T>::value) {
                std::get<Is>(c) = v;
            }
        }
        template <std::size_t Is, typename Component, typename ...Components>
        bool init_sibling(int i) noexcept {
            if constexpr (std::is_function<Component>::value) {
                using C = typename std::invoke_result<Component, flags::absent>::type;
                auto v = impl::sibling<C>(ctx, component<MainKey>::id, i);
                if (v) {
                    return false;
                }
                if constexpr (sizeof...(Components) > 0) {
                    return init_sibling<Is, Components...>(i);
                }
                return true;
            }
            else {
                auto v = impl::sibling<Component>(ctx, component<MainKey>::id, i);
                if (!v) {
                    return false;
                }
                assgin<Is>(v);
                if constexpr (sizeof...(Components) > 0) {
                    return init_sibling<impl::next<Is, Component>(), Components...>(i);
                }
                return true;
            }
        }
    public:
        impl::components<MainKey, SubKey...> c;
        Context& ctx;
        int index = kInvalidIndex;
    };

    template <typename MainKey, typename ...SubKey>
    using entity = basic_entity<ecs_context, MainKey, SubKey...>;

    template <typename MainKey, typename ...SubKey>
    using cached_entity = basic_entity<cached<MainKey, SubKey...>, MainKey, SubKey...>;

    namespace impl {
        template <typename Context, typename ...Args>
        struct basic_selector {
            using entity_type = basic_entity<Context, Args...>;
            struct begin_t {};
            struct end_t {};
            struct iterator {
                entity_type e;
                iterator(begin_t, Context& ctx) noexcept
                    : e(ctx) {
                    impl::sync(ctx);
                    e.next();
                }
                iterator(end_t, Context& ctx) noexcept
                    : e(ctx)
                {}
                bool operator!=(iterator const& o) const noexcept {
                    return e.index != o.e.index;
                }
                bool operator==(iterator const& o) const noexcept {
                    return !(*this != o);
                }
                iterator& operator++() noexcept {
                    if (e.invalid()) {
                        return *this;
                    }
                    e.next();
                    return *this;
                }
                entity_type& operator*() noexcept {
                    return e;
                }
            };
            basic_selector(Context& ctx) noexcept
                : ctx(ctx)
            {}
            iterator begin() noexcept {
                return {begin_t{}, ctx};
            }
            iterator end() noexcept {
                return { end_t{}, ctx };
            }
            Context& ctx;
        };
        
        template <typename ...Args>
        using selector = basic_selector<ecs_context, Args...>;

        template <typename ...Args>
        using cached_selector = basic_selector<cached<Args...>, Args...>;
    }

    template <typename Component>
    void clear_type(ecs_context* ctx) noexcept {
        entity_clear_type(ctx, component<Component>::id);
    }

    template <typename Component, size_t N>
        requires (component<Component>::tag)
    void group_enable(ecs_context* ctx, int (&ids)[N]) noexcept {
        entity_group_enable(ctx, component<Component>::id, N, ids);
    }

    template <typename Component>
    size_t count(ecs_context* ctx) noexcept {
        return (size_t)entity_count(ctx, component<Component>::id);
    }

    template <typename ...Args>
    auto select(ecs_context* ctx) noexcept {
        return impl::selector<Args...>(*ctx);
    }

    template <typename Context, typename ...Args>
    auto select(Context& ctx) noexcept {
        return impl::basic_selector<Context, Args...>(ctx);
    }

    template <typename ...Args>
    auto cached_select(cached<Args...>& cache) noexcept {
        return impl::cached_selector<Args...>(cache);
    }
}
