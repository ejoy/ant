#pragma once

struct lua_State;

#include "luaecs.h"
#include <type_traits>
#include <tuple>

namespace ecs_api {
    template <typename T>
    struct component {};

    namespace impl {
        template <typename Component>
        Component* iter(ecs_context* ctx, int i) {
            return (Component*)entity_iter(ctx, component<Component>::id, i);
        }

        template <typename Component>
        Component* sibling(ecs_context* ctx, int mainkey, int i) {
            return (Component*)entity_sibling(ctx, mainkey, i, component<Component>::id);
        }

        template <typename Component>
        Component* sibling(ecs_context* ctx, int mainkey, int i, lua_State* L) {
            auto c = sibling<Component>(ctx, mainkey, i);
            if (c == NULL) {
                luaL_error(L, "No %s", component<Component>::name);
            }
            return c;
        }
    }

    template <typename MainKey, typename ...SubKey>
    struct entity {
    public:
        int getid() const {
            return index;
        }
        template <typename T>
        T& get() {
            return *std::get<T*>(c);
        }
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
    private:
        template <std::size_t Is, typename Component, typename ...Components>
        bool init_sibling(ecs_context* ctx, int i) {
            auto v = impl::sibling<Component>(ctx, component<MainKey>::id, i);
            if (!v) {
                return false;
            }
            std::get<Is>(c) = v;
            if constexpr (sizeof...(Components) > 0) {
                return init_sibling<Is+1, Components...>(ctx, i);
            }
            return true;
        }
        bool init_components(ecs_context* ctx, int& i) {
            for (;;++i) {
                auto v = impl::iter<MainKey>(ctx, i);
                if (!v) {
                    return false;
                }
                std::get<0>(c) = v;
                if constexpr (sizeof...(SubKey) == 0) {
                    return true;
                }
                else {
                    if (init_sibling<1, SubKey...>(ctx, i)) {
                        return true;
                    }
                }
            }
        }
        template <std::size_t Is, typename Component, typename ...Components>
        void init_sibling(ecs_context* ctx, int i, lua_State* L) {
            auto v = impl::sibling<Component>(ctx, component<MainKey>::id, i, L);
            std::get<Is>(c) = v;
            if constexpr (sizeof...(Components) > 0) {
                init_sibling<Is+1, Components...>(ctx, i, L);
            }
        }
        bool init_components(ecs_context* ctx, int i, lua_State* L) {
            auto v = impl::iter<MainKey>(ctx, i);
            if (!v) {
                return false;
            }
            std::get<0>(c) = v;
            if constexpr (sizeof...(SubKey) > 0) {
                init_sibling<1, SubKey...>(ctx, i, L);
            }
            return true;
        }
    private:
        std::tuple<MainKey*, SubKey*...> c;
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

        template <typename Component>
        Component* iter(int index) {
            return impl::iter<Component>(ecs, index);
        }

        template <typename Component, typename MainKey, typename ...SubKey>
        Component* sibling(entity<MainKey, SubKey...> const& e) {
            return impl::sibling<Component>(ecs, component<MainKey>::id, e.getid());
        }

        template <typename Component, typename MainKey, typename ...SubKey>
        void enable_tag(entity<MainKey, SubKey...> const& e) {
            static_assert(component<Component>::tag);
            entity_enable_tag(ecs, component<MainKey>::id, e.getid(), component<Component>::id);
        }

        template <typename MainKey, typename ...SubKey>
        void enable_tag(entity<MainKey, SubKey...> const& e, int id) {
            entity_enable_tag(ecs, component<MainKey>::id, e.getid(), id);
        }

        template <typename Component, typename MainKey, typename ...SubKey>
        void disable_tag(entity<MainKey, SubKey...> const& e) {
            static_assert(component<Component>::tag);
            entity_disable_tag(ecs, component<MainKey>::id, e.getid(), component<Component>::id);
        }

        template <typename MainKey, typename ...SubKey>
        void disable_tag(entity<MainKey, SubKey...> const& e, int id) {
            entity_disable_tag(ecs, component<MainKey>::id, e.getid(), id);
        }

        template <typename Component>
        void clear_type() {
            entity_clear_type(ecs, component<Component>::id);
        }

        template <typename MainKey, typename ...SubKey>
        void remove(entity<MainKey, SubKey...> const& e) {
            entity_remove(ecs, component<MainKey>::id, e.getid());
        }

        template <typename ...Args>
        auto select(lua_State* L) {
            return impl::strict_select_range<Args...>(ecs, L);
        }

        template <typename ...Args>
        auto select() {
            return impl::select_range<Args...>(ecs);
        }

        template <typename ...Args>
        bool init_entity(entity<Args...>& e, int i, lua_State* L) {
            return e.init(ecs, i, L);
        }
    };
}
