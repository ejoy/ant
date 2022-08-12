#pragma once

struct lua_State;

#include "luaecs.h"
#include <type_traits>
#include <tuple>

namespace ecs_api {
    namespace flags {
        struct absent {};
    }
    constexpr int EID = 0xFFFFFFFF;

    template <typename T>
    struct component {};

    namespace impl {
        template <typename Component>
        Component* iter(ecs_context* ctx, int i) {
            static_assert(!std::is_function<Component>::value);
            return (Component*)entity_iter(ctx, component<Component>::id, i);
        }

        template <typename Component>
        Component* sibling(ecs_context* ctx, int mainkey, int i) {
            static_assert(!std::is_function<Component>::value);
            return (Component*)entity_sibling(ctx, mainkey, i, component<Component>::id);
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
        static constexpr std::size_t next() {
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
        bool init(ecs_context* ctx, int& i) {
            auto r = init_components(ctx, i);
            if (r) {
                index = i;
            }
            return r;
        }
        bool init(ecs_context* ctx, int i, lua_State* L) {
            auto r = init_components(ctx, i, L);
            if (r) {
                index = i;
            }
            return r;
        }
        void remove(ecs_context* ctx) const {
            entity_remove(ctx, component<MainKey>::id, index);
        }
        int getid() const {
            return index;
        }
        template <typename T>
            requires (component<T>::id == EID)
        T get() {
            return (T)std::get<T*>(c);
        }
        template <typename T>
            requires (component<T>::id != EID && !std::is_empty<T>::value)
        T& get() {
            return *std::get<T*>(c);
        }
        template <typename T>
            requires (component<T>::tag)
        bool sibling(ecs_context* ctx) const {
            return !!impl::sibling<T>(ctx, component<MainKey>::id, index);
        }
        template <typename T>
            requires (!component<T>::tag && !std::is_empty<T>::value)
        T* sibling(ecs_context* ctx) const {
            return impl::sibling<T>(ctx, component<MainKey>::id, index);
        }
        template <typename T>
            requires (component<T>::id == EID)
        T sibling(ecs_context* ctx, lua_State* L) const {
            return (T)impl::sibling<T>(ctx, component<MainKey>::id, index, L);
        }
        template <typename T>
            requires (component<T>::id != EID && !std::is_empty<T>::value)
        T& sibling(ecs_context* ctx, lua_State* L) const {
            return *impl::sibling<T>(ctx, component<MainKey>::id, index, L);
        }
        template <typename T>
            requires (component<T>::tag)
        void enable_tag(ecs_context* ctx) {
            entity_enable_tag(ctx, component<MainKey>::id, index, component<T>::id);
        }
        void enable_tag(ecs_context* ctx, int id) {
            entity_enable_tag(ctx, component<MainKey>::id, index, id);
        }
        template <typename T>
            requires (component<T>::tag)
        void disable_tag(ecs_context* ctx) {
            entity_disable_tag(ctx, component<MainKey>::id, index, component<T>::id);
        }
        void disable_tag(ecs_context* ctx, int id) {
            entity_disable_tag(ctx, component<MainKey>::id, index, id);
        }
    private:
        template <std::size_t Is, typename T>
        void assgin(T* v) {
            if constexpr (!std::is_empty<T>::value) {
                std::get<Is>(c) = v;
            }
        }
        template <std::size_t Is, typename Component, typename ...Components>
        bool init_sibling(ecs_context* ctx, int i) {
            if constexpr (std::is_function<Component>::value) {
                using C = typename std::invoke_result<Component, flags::absent>::type;
                auto v = impl::sibling<C>(ctx, component<MainKey>::id, i);
                if (v) {
                    return false;
                }
                if constexpr (sizeof...(Components) > 0) {
                    return init_sibling<Is, Components...>(ctx, i);
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
                    return init_sibling<impl::next<Is, Component>(), Components...>(ctx, i);
                }
                return true;
            }
        }
        bool init_components(ecs_context* ctx, int& i) {
            for (;;++i) {
                auto v = impl::iter<MainKey>(ctx, i);
                if (!v) {
                    return false;
                }
                assgin<0>(v);
                if constexpr (sizeof...(SubKey) == 0) {
                    return true;
                }
                else {
                    if (init_sibling<impl::next<0, MainKey>(), SubKey...>(ctx, i)) {
                        return true;
                    }
                }
            }
        }
        template <std::size_t Is, typename Component, typename ...Components>
        void init_sibling(ecs_context* ctx, int i, lua_State* L) {
            if constexpr (std::is_function<Component>::value) {
                using C = typename std::invoke_result<Component, flags::absent>::type;
                auto v = impl::sibling<Component>(ctx, component<MainKey>::id, i);
                if (v) {
                    luaL_error(L, "component `%s` exists.", component<C>::name);
                }
                if constexpr (sizeof...(Components) > 0) {
                    init_sibling<Is, Components...>(ctx, i, L);
                }
            }
            else {
                auto v = impl::sibling<Component>(ctx, component<MainKey>::id, i, L);
                assgin<Is>(v);
                if constexpr (sizeof...(Components) > 0) {
                    init_sibling<impl::next<Is, Component>(), Components...>(ctx, i, L);
                }
            }
        }
        bool init_components(ecs_context* ctx, int i, lua_State* L) {
            auto v = impl::iter<MainKey>(ctx, i);
            if (!v) {
                return false;
            }
            assgin<0>(v);
            if constexpr (sizeof...(SubKey) > 0) {
                init_sibling<impl::next<0, MainKey>(), SubKey...>(ctx, i, L);
            }
            return true;
        }
    private:
        impl::components<MainKey, SubKey...> c;
        int index;
    };

    namespace impl {
        template <typename ...Args>
        struct strict_select_range {
            struct iterator {
                ecs_context* ctx;
                int index;
                entity<Args...>& e;
                lua_State* L;
                iterator(entity<Args...>& e)
                    : ctx(NULL)
                    , index(0)
                    , e(e)
                    , L(NULL)
                { }
                iterator(ecs_context* ctx, entity<Args...>& e, lua_State* L)
                    : ctx(ctx)
                    , index(0)
                    , e(e)
                    , L(L)
                { }
        
                bool operator!=(iterator const& o) const {
                    if (ctx != o.ctx) {
                        return true;
                    }
                    if (ctx == NULL) {
                        return false;
                    }
                    return index != o.index;
                }
                bool operator==(iterator const& o) const {
                    return !(*this != o);
                }
                iterator& operator++() {
                    index++;
                    next();
                    return *this;
                }
                entity<Args...>& operator*() {
                    return e;
                }
                void next() {
                    if (!e.init(ctx, index, L)) {
                        ctx = NULL;
                    }
                }
            };
            ecs_context* ctx;
            entity<Args...> e;
            lua_State* L;

            strict_select_range(ecs_context* ctx, lua_State* L)
                : ctx(ctx)
                , e()
                , L(L)
            {}

            iterator begin() {
                iterator iter {ctx, e, L};
                iter.next();
                return iter;
            }
            iterator end() {
                return {e};
            }
        };

        template <typename ...Args>
        struct select_range {
            struct iterator {
                ecs_context* ctx;
                int index;
                entity<Args...>& e;
                iterator(entity<Args...>& e)
                    : ctx(NULL)
                    , index(0)
                    , e(e)
                { }
                iterator(ecs_context* ctx, entity<Args...>& e)
                    : ctx(ctx)
                    , index(0)
                    , e(e)
                { }
        
                bool operator!=(iterator const& o) const {
                    if (ctx != o.ctx) {
                        return true;
                    }
                    if (ctx == NULL) {
                        return false;
                    }
                    return index != o.index;
                }
                bool operator==(iterator const& o) const {
                    return !(*this != o);
                }
                iterator& operator++() {
                    index++;
                    next();
                    return *this;
                }
                entity<Args...>& operator*() {
                    return e;
                }
                void next() {
                    if (!e.init(ctx, index)) {
                        ctx = NULL;
                    }
                }
            };
            ecs_context* ctx;
            entity<Args...> e;

            select_range(ecs_context* ctx)
                : ctx(ctx)
                , e()
            {}

            iterator begin() {
                iterator iter {ctx, e};
                iter.next();
                return iter;
            }
            iterator end() {
                return {e};
            }
        };
    }

    struct context {
        ecs_context* ecs;

        operator ecs_context*() {
            return ecs;
        }

        template <typename Component>
            requires (component<Component>::id != EID && !std::is_empty<Component>::value)
        Component& entity_sibling(int mainkey, int i, lua_State* L) {
            return *impl::sibling<Component>(ecs, mainkey, i, L);
        }

        template <typename Component>
        void clear_type() {
            entity_clear_type(ecs, component<Component>::id);
        }

        template <typename ...Args>
        auto select(lua_State* L) {
            return impl::strict_select_range<Args...>(ecs, L);
        }

        template <typename ...Args>
        auto select() {
            return impl::select_range<Args...>(ecs);
        }
    };
}
