#pragma once

struct lua_State;

#include "luaecs.h"
#include <type_traits>

namespace ecs_api {
    template <typename T>
    struct component {};

    template <typename ...Components>
    struct entity_;

    template <>
    struct entity_<> {};

    template <typename Component, typename ...Components>
    struct entity_<Component, Components...> : public entity_<Components...> {
        Component* c;
        template <typename T>
        T& get() {
            if constexpr (std::is_same<T, Component>::value) {
                return *c;
            }
            else {
                return entity_<Components...>::template get<T>();
            }
        }
    };

    template <typename ...Components>
    struct entity : public entity_<Components...> {
        int index;
    };

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

        template <typename ...Components>
        struct visit_entity_;

        template <>
        struct visit_entity_ <> {
            bool operator()(entity_<>& e, ecs_context* ctx, int mainkey, int i) { return true; }
            void operator()(entity_<>& e, ecs_context* ctx, int mainkey, int i, lua_State* L) {}
        };

        template <typename Component, typename ...Components>
        struct visit_entity_<Component, Components...> {
            bool operator()(entity_<Component, Components...>& e, ecs_context* ctx, int mainkey, int i) {
                e.c = sibling<Component>(ctx, mainkey, i);
                if (e.c == NULL) {
                    return false;
                }
                return visit_entity_<Components...>()(e, ctx, mainkey, i);
            }
            void operator()(entity_<Component, Components...>& e, ecs_context* ctx, int mainkey, int i, lua_State* L) {
                e.c = sibling<Component>(ctx, mainkey, i, L);
                return visit_entity_<Components...>()(e, ctx, mainkey, i, L);
            }
        };

        enum class visit_result {
            succ,
            failed,
            eof,
        };

        template <typename MainKey, typename ...SubKey>
        visit_result visit_entity(ecs_context* ctx, int i, entity_<MainKey, SubKey...>& e) {
            e.c = (MainKey*)entity_iter(ctx, component<MainKey>::id, i);
            if (!e.c) {
                return visit_result::eof;
            }
            if (visit_entity_<SubKey...>()(e, ctx, component<MainKey>::id, i)) {
                return visit_result::succ;
            }
            else {
                return visit_result::failed;
            }
        }

        template <typename MainKey, typename ...SubKey>
        bool visit_entity(ecs_context* ctx, int i, entity_<MainKey, SubKey...>& e, lua_State* L) {
            e.c = (MainKey*)entity_iter(ctx, component<MainKey>::id, i);
            if (!e.c) {
                return false;
            }
            visit_entity_<SubKey...>()(e, ctx, component<MainKey>::id, i, L);
            return true;
        }

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
                    if (visit_entity(ctx, index, e, L)) {
                        e.index = index;
                    }
                    else {
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
                if (visit_entity(ctx, 0, e, L)) {
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
                    for (;;) {
                        auto r = visit_entity(ctx, index, e);
                        switch (r) {
                        case visit_result::succ:
                            e.index = index;
                            return;
                        case visit_result::failed:
                            index++;
                            break;
                        case visit_result::eof:
                            ctx = NULL;
                            return;
                        }
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
            return impl::sibling<Component>(ecs, component<MainKey>::id, e.index);
        }

        template <typename Component, typename MainKey, typename ...SubKey>
        void enable_tag(entity<MainKey, SubKey...> const& e) {
            static_assert(component<Component>::tag);
            entity_enable_tag(ecs, component<MainKey>::id, e.index, component<Component>::id);
        }

        template <typename MainKey, typename ...SubKey>
        void enable_tag(entity<MainKey, SubKey...> const& e, int id) {
            entity_enable_tag(ecs, component<MainKey>::id, e.index, id);
        }

        template <typename Component, typename MainKey, typename ...SubKey>
        void disable_tag(entity<MainKey, SubKey...> const& e) {
            static_assert(component<Component>::tag);
            entity_disable_tag(ecs, component<MainKey>::id, e.index, component<Component>::id);
        }

        template <typename MainKey, typename ...SubKey>
        void disable_tag(entity<MainKey, SubKey...> const& e, int id) {
            entity_disable_tag(ecs, component<MainKey>::id, e.index, id);
        }

        template <typename Component>
        void clear_type() {
            entity_clear_type(ecs, component<Component>::id);
        }

        template <typename MainKey, typename ...SubKey>
        void remove(entity<MainKey, SubKey...> const& e) {
            entity_remove(ecs, component<MainKey>::id, e.index);
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
        bool visit_entity(entity<Args...>& e, int i, lua_State* L) {
            return impl::visit_entity(ecs, i, e, L);
        }

        template <typename ...Args>
        bool has() {
            entity<Args...> e;
            for (int index = 0;; ++index) {
                auto r = impl::visit_entity(ecs, index, e);
                switch (r) {
                case impl::visit_result::succ:
                    return true;
                case impl::visit_result::failed:
                    break;
                case impl::visit_result::eof:
                    return false;
                }
            }
        }
    };
}
