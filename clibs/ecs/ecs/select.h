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
        entity(ecs_context* ctx)
            : ctx(ctx)
        { }
        static constexpr int kInvalidIndex = -1;
        bool init(int id) {
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
        int find(int id) {
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
        int next(int i) {
            index = i;
            if (index == kInvalidIndex) {
                return kInvalidIndex;
            }
            ++index;
            return find(index);
        }
        void remove() const {
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
            requires (component<T>::id == EID)
        bool has() const {
            return true;
        }
        template <typename T>
            requires (component<T>::id != EID)
        bool has() const {
            return !!impl::sibling<T>(ctx, component<MainKey>::id, index);
        }
        template <typename T>
            requires (component<T>::tag)
        bool sibling() const {
            return !!impl::sibling<T>(ctx, component<MainKey>::id, index);
        }
        template <typename T>
            requires (component<T>::id != EID && !component<T>::tag && !std::is_empty<T>::value)
        T* sibling() const {
            return impl::sibling<T>(ctx, component<MainKey>::id, index);
        }
        template <typename T>
            requires (component<T>::id == EID)
        T sibling() const {
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
        void enable_tag() {
            entity_enable_tag(ctx, component<MainKey>::id, index, component<T>::id);
        }
        void enable_tag(int id) {
            entity_enable_tag(ctx, component<MainKey>::id, index, id);
        }
        template <typename T>
            requires (component<T>::tag)
        void disable_tag() {
            entity_disable_tag(ctx, component<MainKey>::id, index, component<T>::id);
        }
        void disable_tag(int id) {
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
        bool init_sibling(int i) {
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
    private:
        impl::components<MainKey, SubKey...> c;
        ecs_context* ctx;
        int index = kInvalidIndex;
    };

    namespace impl {
        template <typename ...Args>
        struct select_range {
            using entity_type = entity<Args...>;
            struct begin_t {};
            struct end_t {};
            struct iterator {
                entity_type& e;
                int index;
                iterator(begin_t, entity_type& e)
                    : e(e)
                    , index(e.find(0))
                { }
                iterator(end_t, entity_type& e)
                    : e(e)
                    , index(entity_type::kInvalidIndex)
                { }
                bool operator!=(iterator const& o) const {
                    return index != o.index;
                }
                bool operator==(iterator const& o) const {
                    return !(*this != o);
                }
                iterator& operator++() {
                    index = e.next(index);
                    return *this;
                }
                entity_type& operator*() {
                    return e;
                }
            };
            select_range(ecs_context* ctx)
                : e(ctx)
            {}
            iterator begin() {
                return {begin_t{}, e};
            }
            iterator end() {
                return {end_t{}, e};
            }
            entity_type e;
        };
    }

    template <typename Component>
    void clear_type(ecs_context* ctx) {
        entity_clear_type(ctx, component<Component>::id);
    }

    template <typename Component, size_t N>
        requires (component<Component>::tag)
    void group_enable(ecs_context* ctx, int (&ids)[N]) {
        entity_group_enable(ctx, component<Component>::id, N, ids);
    }

    template <typename Component>
    size_t count(ecs_context* ctx) {
        return (size_t)entity_count(ctx, component<Component>::id);
    }

    template <typename Component>
        requires (component<Component>::id == EID)
    int index(ecs_context* ctx, Component eid) {
        return entity_index(ctx, eid);
    }

    template <typename ...Args>
    auto select(ecs_context* ctx) {
        return impl::select_range<Args...>(ctx);
    }
}
