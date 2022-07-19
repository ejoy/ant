#pragma once

struct lua_State;

#include "luaecs.h"
#include <type_traits>

namespace ecs_api {
    template <typename T>
    struct component {};

    namespace impl {
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

    template <typename ...Components>
    struct entity_;

    template <>
    struct entity_<> {};

    template <typename Component, typename ...Components>
    struct entity_<Component, Components...> : public entity_<Components...> {
    public:
        template <typename T>
        T& get() {
            if constexpr (std::is_same<T, Component>::value) {
                return *c;
            }
            else {
                return entity_<Components...>::template get<T>();
            }
        }

        bool init_sibling(ecs_context* ctx, int mainkey, int i) {
            auto v = impl::sibling<Component>(ctx, mainkey, i);
            if (!v) {
                return false;
            }
            c = v;
            if constexpr (sizeof...(Components) > 0) {
                return entity_<Components...>::init_sibling(ctx, mainkey, i);
            }
            return true;
        }
        void init_sibling(ecs_context* ctx, int mainkey, int i, lua_State* L) {
            auto v = impl::sibling<Component>(ctx, mainkey, i, L);
            c = v;
            if constexpr (sizeof...(Components) > 0) {
                return entity_<Components...>::init_sibling(ctx, mainkey, i, L);
            }
        }
        bool init(ecs_context* ctx, int& i) {
            for (;;++i) {
                auto v = (Component*)entity_iter(ctx, component<Component>::id, i);
                if (!v) {
                    return false;
                }
                c = v;
                if constexpr (sizeof...(Components) == 0) {
                    return true;
                }
                if (entity_<Components...>::init_sibling(ctx, component<Component>::id, i)) {
                    return true;
                }
            }
        }
        bool init(ecs_context* ctx, int i, lua_State* L) {
            auto v = (Component*)entity_iter(ctx, component<Component>::id, i);
            if (!v) {
                return false;
            }
            c = v;
            if constexpr (sizeof...(Components) > 0) {
                entity_<Components...>::init_sibling(ctx, component<Component>::id, i, L);
            }
            return true;
        }
    private:
        Component* c;
    };

    template <typename ...Components>
    struct entity : public entity_<Components...> {
    public:
        int getid() const {
            return index;
        }
        bool init(ecs_context* ctx, int& i) {
            auto r = entity_<Components...>::init(ctx, i);
            if (r) {
                index = i;
            }
            return r;
        }
        bool init(ecs_context* ctx, int i, lua_State* L) {
            auto r = entity_<Components...>::init(ctx, i, L);
            if (r) {
                index = i;
            }
            return r;
        }
    private:
        int index;
    };

    namespace impl {
        template <typename ...Args>
        struct strict_select_range {
            struct iterator {
                ecs_context* ctx;
                lua_State* L;
                int index;
                entity<Args...>& e;
                iterator(entity<Args...>& e)
                    : ctx(NULL)
                    , L(NULL)
                    , index(0)
                    , e(e)
                { }
                iterator(ecs_context* ctx, lua_State* L, entity<Args...>& e)
                    : ctx(ctx)
                    , L(L)
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
                iterator& operator++() {
                    index++;
                    if (!e.init(ctx, index, L)) {
                        ctx = NULL;
                        L = NULL;
                    }
                    return *this;
                }
                entity<Args...>& operator*() {
                    return e;
                }
            };
            ecs_context* ctx;
            lua_State* L;
            entity<Args...> e;

            strict_select_range(ecs_context* ctx, lua_State* L)
                : ctx(ctx)
                , L(L)
                , e()
            {}

            iterator begin() {
                if (e.init(ctx, 0, L)) {
                    return {ctx, L, e};
                }
                return {e};
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
            return (Component*)entity_iter(ecs, component<Component>::id, index);
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

        template <typename ...Args>
        bool has() {
            entity<Args...> e;
            int index = 0;
            return e.init(ecs, index);
        }
    };
}
