#pragma once

struct lua_State;

#include "luaecs.h"
#include <type_traits>
#include <tuple>
#include <array>
#include <optional>
#include <cstdint>

namespace ecs_api {
    namespace flags {
        struct absent {};
    }
    constexpr int EID = 0xFFFFFFFF;

    template <typename T>
    struct component_meta {};

    template <typename T>
    constexpr int component_id = component_meta<T>::id;

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

    struct context: public ecs_context {
    private:
        context() noexcept {}
    public:
        static inline context& create(ecs_context* ctx) noexcept {
            return *(context*)ctx;
        }
        ecs_context* ctx() const noexcept {
            return const_cast<ecs_context*>((const ecs_context*)this);
        }
        void sync() noexcept {
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && component_meta<T>::tag
            )
        void next(int& i, ecs_token& token) noexcept {
            i = entity_next(ctx(), component_meta<T>::id, i, &token);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && !component_meta<T>::tag
            )
        T* fetch(int i, ecs_token& token) noexcept {
            return (T*)entity_fetch(ctx(), component_meta<T>::id, i, &token);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && component_meta<T>::tag
            )
        bool component(ecs_token token, [[maybe_unused]] int i) noexcept {
            return entity_component_index(ctx(), token, component_meta<T>::id) >= 0;
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && !component_meta<T>::tag
            )
        T* component(ecs_token token, [[maybe_unused]] int i) noexcept {
            return (T*)entity_component(ctx(), token, component_meta<T>::id);
        }
        void disable_tag(int tagid, int i) noexcept {
            entity_disable_tag(ctx(), tagid, i);
        }
        void disable_tag(ecs_token token, [[maybe_unused]] int i, int tagid) noexcept {
            int index = entity_component_index(ctx(), token, tagid);
            if (index >= 0) {
                disable_tag(tagid, index);
            }
        }
    };

    template <typename MainKey, typename...Components>
    struct cached_context {
    private:
        struct ecs_context* context;
        struct ecs_cache* c;
    public:
        cached_context(struct ecs_context* ctx) noexcept {
            std::array<int, 1+sizeof...(Components)> keys {component_meta<MainKey>::id, component_meta<Components>::id...};
            struct ecs_cache* c = entity_cache_create(ctx, keys.data(), static_cast<int>(keys.size()));
            this->context = ctx;
            this->c = c;
        }
        ~cached_context() noexcept {
            entity_cache_release(ctx(), c);
        }
        ecs_context* ctx() const noexcept {
            return context;
        }
        void sync() noexcept {
            entity_cache_sync(ctx(), c);
        }

        template <typename T>
            requires (
                !std::is_function_v<T>
                && component_meta<T>::tag
            )
        void next(int& i, ecs_token& token) noexcept {
            i = entity_next(ctx(), component_meta<T>::id, i, &token);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && std::is_same_v<T, MainKey>
                && !component_meta<T>::tag
            )
        T* fetch(int i, ecs_token& token) noexcept {
            return (T*)entity_fetch(ctx(), component_meta<T>::id, i, &token);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && impl::has_element_v<T, Components...>
                && component_meta<T>::id != EID
                && component_meta<T>::tag
            )
        bool component([[maybe_unused]] ecs_token token, int i) noexcept {
            return entity_cache_fetch_index(ctx(), c, i, component_meta<T>::id) >= 0;
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && impl::has_element_v<T, Components...>
                && component_meta<T>::id != EID
                && !component_meta<T>::tag
            )
        T* component([[maybe_unused]] ecs_token token, int i) noexcept {
            return (T*)entity_cache_fetch(ctx(), c, i, component_meta<T>::id);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && component_meta<T>::id == EID
                && impl::has_element_v<T, Components...>
            )
        T* component(ecs_token token, [[maybe_unused]] int i) noexcept {
            return (T*)entity_component(ctx(), token, EID);
        }
        void disable_tag(int tagid, int i) noexcept {
            entity_disable_tag(ctx(), tagid, i);
        }
        void disable_tag([[maybe_unused]] ecs_token token, int i, int tagid) noexcept {
            int index = entity_cache_fetch_index(ctx(), c, i, tagid);
            if (index >= 0) {
                disable_tag(tagid, index);
            }
        }
    };

    namespace impl {
        template <typename...Ts>
        using components = decltype(std::tuple_cat(
            std::declval<std::conditional_t<std::is_empty_v<Ts> || std::is_function_v<Ts>,
                std::tuple<>,
                std::tuple<Ts*>
            >>()...
        ));

        template <std::size_t Is, typename T>
        static constexpr std::size_t next() noexcept {
            if constexpr (std::is_empty_v<T> || std::is_function_v<T>) {
                return Is;
            }
            else {
                return Is+1;
            }
        }
    }

    struct create_t {};
    struct first_t {};

    template <typename Context, typename MainKey, typename ...SubKey>
    struct basic_entity {
    public:
        static constexpr int kInvalidIndex = -1;
        basic_entity(Context& ctx) noexcept
            : ctx(ctx)
        { }
        template <typename Component>
            requires (
                component_meta<Component>::id == EID
                && component_meta<MainKey>::id == EID
                && sizeof...(SubKey) == 0
            )
        basic_entity(ecs_context* ctx, Component eid) noexcept
            : ctx(context::create(ctx)) {
            index = entity_index(ctx, (void*)eid, &token);
            if (index >= 0) {
                std::get<Component*>(c) = (Component*)eid;
            }
        }
        template <typename Tag>
            requires (
                std::is_same_v<Tag, create_t>
                && sizeof...(SubKey) == 0
            )
        basic_entity(ecs_context* ctx, Tag) noexcept
            : ctx(context::create(ctx)) {
            index = entity_new(ctx, component_meta<MainKey>::id, NULL);
            if (index == kInvalidIndex) {
                return;
            }
            auto v = this->ctx.template fetch<MainKey>(index, token);
            if (v) {
                assert(v);
                assgin<0>(v);
            }
        }
        template <typename Tag>
            requires (
                std::is_same_v<Tag, first_t>
            )
        basic_entity(ecs_context* ctx, Tag) noexcept
            : ctx(context::create(ctx)) {
            next();
        }
        bool fetch_sibiling(int id) noexcept {
            if constexpr (sizeof...(SubKey) == 0) {
                return true;
            }
            else {
                if (init_component<impl::next<0, MainKey>(), SubKey...>(id)) {
                    return true;
                }
                return false;
            }
        }
        void next() noexcept {
            if constexpr (component_meta<MainKey>::tag) {
                for (;;) {
                    ctx.template next<MainKey>(index, token);
                    if (index == kInvalidIndex) {
                        return;
                    }
                    if (fetch_sibiling(index)) {
                        return;
                    }
                }
            }
            else {
                for (++index;;++index) {
                    auto v = ctx.template fetch<MainKey>(index, token);
                    if (!v) {
                        index = kInvalidIndex;
                        return;
                    }
                    assgin<0>(v);
                    if (fetch_sibiling(index)) {
                        return;
                    }
                }
            }
        }
        void remove() const noexcept {
            entity_remove(ctx.ctx(), token);
        }
        int get_index() const noexcept {
            return index;
        }
        ecs_token get_token() const noexcept {
            return token;
        }
        bool invalid() const {
            return index == kInvalidIndex;
        }
        template <typename T>
            requires (component_meta<T>::id == EID)
        T get() noexcept {
            return (T)std::get<T*>(c);
        }
        template <typename T>
            requires (component_meta<T>::id != EID && !std::is_empty_v<T>)
        T& get() noexcept {
            return *std::get<T*>(c);
        }
        template <typename T>
            requires (component_meta<T>::tag)
        bool component() const noexcept {
            return ctx.template component<T>(token, index);
        }
        template <typename T>
            requires (component_meta<T>::id != EID && !component_meta<T>::tag && !std::is_empty_v<T>)
        T* component() const noexcept {
            return ctx.template component<T>(token, index);
        }
        template <typename T>
            requires (component_meta<T>::id == EID)
        T component() const noexcept {
            return (T)ctx.template component<T>(token, index);
        }
        template <typename T>
            requires (component_meta<T>::tag)
        void enable_tag() noexcept {
            entity_enable_tag(ctx.ctx(), token, component_meta<T>::id);
        }
        template <typename T>
            requires (component_meta<T>::tag)
        void disable_tag() noexcept {
            if constexpr (component_meta<MainKey>::id == component_meta<T>::id) {
                ctx.disable_tag(component_meta<MainKey>::id, index);
            }
            else {
                ctx.disable_tag(token, index, component_meta<T>::id);
            }
        }
    private:
        template <std::size_t Is, typename T>
        void assgin(T* v) noexcept {
            if constexpr (!std::is_empty_v<T>) {
                std::get<Is>(c) = v;
            }
        }
        template <std::size_t Is, typename Component, typename ...Components>
        bool init_component(int i) noexcept {
            if constexpr (std::is_function_v<Component>) {
                using C = typename std::invoke_result<Component, flags::absent>::type;
                auto v = ctx.template component<C>(token, i);
                if (v) {
                    return false;
                }
                if constexpr (sizeof...(Components) > 0) {
                    return init_component<Is, Components...>(i);
                }
                return true;
            }
            else if constexpr (component_meta<Component>::tag) {
                auto v = ctx.template component<Component>(token, i);
                if (!v) {
                    return false;
                }
                if constexpr (sizeof...(Components) > 0) {
                    return init_component<impl::next<Is, Component>(), Components...>(i);
                }
                return true;
            }
            else {
                auto v = ctx.template component<Component>(token, i);
                if (!v) {
                    return false;
                }
                assgin<Is>(v);
                if constexpr (sizeof...(Components) > 0) {
                    return init_component<impl::next<Is, Component>(), Components...>(i);
                }
                return true;
            }
        }
    public:
        impl::components<MainKey, SubKey...> c;
        Context& ctx;
        ecs_token token;
        int index = kInvalidIndex;
    };

    template <typename MainKey, typename ...SubKey>
    using entity = basic_entity<context, MainKey, SubKey...>;

    template <typename MainKey, typename ...SubKey>
    using cached_entity = basic_entity<cached_context<MainKey, SubKey...>, MainKey, SubKey...>;

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
                    ctx.sync();
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
                return { begin_t{}, ctx };
            }
            iterator end() noexcept {
                return { end_t{}, ctx };
            }
            Context& ctx;
        };
        
        template <typename ...Args>
        using selector = basic_selector<context, Args...>;

        template <typename ...Args>
        using cached_selector = basic_selector<cached_context<Args...>, Args...>;

        template <typename Component>
        struct array_range {
            array_range(ecs_context* ctx) noexcept {
                first = (Component*)entity_fetch(ctx, component_meta<Component>::id, 0, NULL);
                if (!first) {
                    last = nullptr;
                    return;
                }
                last = first + (size_t)entity_count(ctx, component_meta<Component>::id);
            }
            Component* begin() noexcept {
                return first;
            }
            Component* end() noexcept {
                return last;
            }
            Component* first;
            Component* last;
        };
    }

    template <typename Component>
    void clear_type(ecs_context* ctx) noexcept {
        entity_clear_type(ctx, component_meta<Component>::id);
    }

    template <typename Component, size_t N>
        requires (component_meta<Component>::tag)
    void group_enable(ecs_context* ctx, int (&ids)[N]) noexcept {
        entity_group_enable(ctx, component_meta<Component>::id, N, ids);
    }

    template <typename Component>
    size_t count(ecs_context* ctx) noexcept {
        return (size_t)entity_count(ctx, component_meta<Component>::id);
    }

    template <typename Component>
    auto create_entity(ecs_context* ctx) noexcept {
        return entity<Component>(ctx, create_t {});
    }

    template <typename ...Args>
    auto first_entity(ecs_context* ctx) noexcept {
        return entity<Args...>(ctx, first_t {});
    }

    template <typename Component>
        requires (component_meta<Component>::id == EID)
    auto find_entity(ecs_context* ctx, Component eid) noexcept {
        return entity<Component>(ctx, eid);
    }

    template <typename Component>
        requires (!component_meta<Component>::tag)
    auto array(ecs_context* ctx) noexcept {
        return impl::array_range<Component>(ctx);
    }

    template <typename ...Args>
    auto select(ecs_context* ctx) noexcept {
        return impl::selector<Args...>(context::create(ctx));
    }

    template <typename Context, typename ...Args>
    auto select(Context& ctx) noexcept {
        return impl::basic_selector<Context, Args...>(ctx);
    }

    template <typename ...Args>
    auto cached_select(cached_context<Args...>& cache) noexcept {
        return impl::cached_selector<Args...>(cache);
    }
}
