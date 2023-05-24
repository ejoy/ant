#pragma once

struct lua_State;

#include "luaecs.h"
#include <type_traits>
#include <tuple>
#include <array>

namespace ecs_api {
    namespace flags {
        struct absent {};
    }
    constexpr int EID = 0xFFFFFFFF;

    template <typename T>
    struct component {};

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
        requires (component<MainKey>::id != EID)
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
        template <typename Component>
        Component* iter(ecs_context* ctx, int i) noexcept {
            static_assert(!std::is_function<Component>::value);
            return (Component*)entity_iter(ctx, component<Component>::id, i);
        }

        template <typename Component>
        Component* sibling(ecs_context* ctx, int mainkey, int i) noexcept {
            static_assert(!std::is_function<Component>::value);
            return (Component*)entity_sibling(ctx, mainkey, i, component<Component>::id);
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

        template <typename Component, typename Cached>
            requires (!std::is_function_v<Component> && component<Component>::id != EID)
        Component* sibling(Cached& cache, int i) noexcept {
            return cache_fetch<Component>(cache, i);
        }

        template <typename Component, typename Cached>
            requires (!std::is_function_v<Component> && component<Component>::id == EID)
        Component* sibling(Cached& cache, int i) noexcept {
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

    template <typename MainKey, typename ...SubKey>
    struct entity {
    public:
        using cached_type = cached<MainKey, SubKey...>;

        entity(ecs_context* ctx) noexcept
            : ctx(ctx)
        { }
        static constexpr int kInvalidIndex = -1;
        bool init(int id) noexcept {
            auto v = impl::iter<MainKey>(ctx, id);
            if (!v) {
                index = kInvalidIndex;
                return false;
            }
            assgin<0>(v);
            if constexpr (sizeof...(SubKey) == 0) {
                index = id;
                return true;
            }
            else {
                if (init_sibling<impl::next<0, MainKey>(), SubKey...>(id)) {
                    index = id;
                    return true;
                }
                index = kInvalidIndex;
                return false;
            }
        }
        int find(int id) noexcept {
            index = id;
            for (;;++index) {
                auto v = impl::iter<MainKey>(ctx, index);
                if (!v) {
                    index = kInvalidIndex;
                    break;
                }
                assgin<0>(v);
                if constexpr (sizeof...(SubKey) == 0) {
                    break;
                }
                else {
                    if (init_sibling<impl::next<0, MainKey>(), SubKey...>(index)) {
                        break;
                    }
                }
            }
            return index;
        }
        int next(int i) noexcept {
            index = i;
            if (index == kInvalidIndex) {
                return kInvalidIndex;
            }
            ++index;
            return find(index);
        }
        int find(cached_type& cache, int id) noexcept {
            index = id;
            for (;;++index) {
                auto v = impl::iter<MainKey>(cache, index);
                if (!v) {
                    index = kInvalidIndex;
                    break;
                }
                assgin<0>(v);
                if constexpr (sizeof...(SubKey) == 0) {
                    break;
                }
                else {
                    if (init_sibling<impl::next<0, MainKey>(), SubKey...>(cache, index)) {
                        break;
                    }
                }
            }
            return index;
        }
        int next(cached_type& cache, int i) noexcept {
            index = i;
            if (index == kInvalidIndex) {
                return kInvalidIndex;
            }
            ++index;
            return find(cache, index);
        }
        void remove() const noexcept {
            entity_remove(ctx, component<MainKey>::id, index);
        }
        int getid() const noexcept {
            return index;
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
            entity_enable_tag(ctx, component<MainKey>::id, index, component<T>::id);
        }
        void enable_tag(int id) noexcept {
            entity_enable_tag(ctx, component<MainKey>::id, index, id);
        }
        template <typename T>
            requires (component<T>::tag)
        void disable_tag() noexcept {
            entity_disable_tag(ctx, component<MainKey>::id, index, component<T>::id);
        }
        void disable_tag(int id) noexcept {
            entity_disable_tag(ctx, component<MainKey>::id, index, id);
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
        template <std::size_t Is, typename Component, typename ...Components>
        bool init_sibling(cached_type& cache, int i) noexcept {
            if constexpr (std::is_function<Component>::value) {
                using C = typename std::invoke_result<Component, flags::absent>::type;
                auto v = impl::sibling<C>(cache, i);
                if (v) {
                    return false;
                }
                if constexpr (sizeof...(Components) > 0) {
                    return init_sibling<Is, Components...>(i);
                }
                return true;
            }
            else {
                auto v = impl::sibling<Component>(cache, i);
                if (!v) {
                    return false;
                }
                assgin<Is>(v);
                if constexpr (sizeof...(Components) > 0) {
                    return init_sibling<impl::next<Is, Component>(), Components...>(cache, i);
                }
                return true;
            }
        }
    private:
        impl::components<MainKey, SubKey...> c;
        ecs_context* ctx;
        int index = kInvalidIndex;
    };

    namespace impl {
        template <typename ...Args>
        struct selector {
            using entity_type = entity<Args...>;
            struct begin_t {};
            struct end_t {};
            struct iterator {
                entity_type& e;
                int index;
                iterator(begin_t, entity_type& e) noexcept
                    : e(e)
                    , index(e.find(0))
                { }
                iterator(end_t, entity_type& e) noexcept
                    : e(e)
                    , index(entity_type::kInvalidIndex)
                { }
                bool operator!=(iterator const& o) const noexcept {
                    return index != o.index;
                }
                bool operator==(iterator const& o) const noexcept {
                    return !(*this != o);
                }
                iterator& operator++() noexcept {
                    index = e.next(index);
                    return *this;
                }
                entity_type& operator*() noexcept {
                    return e;
                }
            };
            selector(ecs_context* ctx) noexcept
                : e(ctx)
            {}
            iterator begin() noexcept {
                return {begin_t{}, e};
            }
            iterator end() noexcept {
                return {end_t{}, e};
            }
            entity_type e;
        };
        
        template <typename ...Args>
        struct cached_selector {
            using entity_type = entity<Args...>;
            using cached_type = cached<Args...>;
            struct begin_t {};
            struct end_t {};
            struct iterator {
                cached_type& c;
                entity_type& e;
                int index;
                iterator(begin_t, cached_type& c, entity_type& e) noexcept
                    : c(c)
                    , e(e)
                    , index(e.find(c, 0))
                { }
                iterator(end_t, cached_type& c, entity_type& e) noexcept
                    : c(c)
                    , e(e)
                    , index(entity_type::kInvalidIndex)
                { }
                bool operator!=(iterator const& o) const noexcept {
                    return index != o.index;
                }
                bool operator==(iterator const& o) const noexcept {
                    return !(*this != o);
                }
                iterator& operator++() noexcept {
                    index = e.next(c, index);
                    return *this;
                }
                entity_type& operator*() noexcept {
                    return e;
                }
            };
            cached_selector(cached_type& cache) noexcept
                : c(cache)
                , e(cache.ctx)
            {}
            iterator begin() noexcept {
                cache_sync(c);
                return {begin_t{}, c, e};
            }
            iterator end() noexcept {
                return {end_t{}, c, e};
            }
            cached_type& c;
            entity_type e;
        };
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

    template <typename Component>
        requires (component<Component>::id == EID)
    int index(ecs_context* ctx, Component eid) noexcept {
        return entity_index(ctx, eid);
    }

    template <typename ...Args>
    auto select(ecs_context* ctx) noexcept {
        return impl::selector<Args...>(ctx);
    }

    template <typename ...Args>
    auto select(cached<Args...>& cache) noexcept {
        return impl::cached_selector<Args...>(cache);
    }
}
