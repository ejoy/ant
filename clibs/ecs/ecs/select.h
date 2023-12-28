#pragma once

#include "luaecs.h"
#include <type_traits>
#include <tuple>
#include <array>
#include <span>
#include <optional>
#include <cstdint>

namespace ecs {
    namespace flags {
        struct absent {};
    }
    namespace COMPONENT {
        constexpr int INVALID = 0x80000000;
        constexpr int EID = 0xFFFFFFFF;
        constexpr int REMOVED = 0x00000000;
    }

    template <typename T>
    constexpr inline int component_id = COMPONENT::INVALID;

    template <typename T>
    constexpr bool is_tag = (component_id<T> != COMPONENT::INVALID) && std::is_empty_v<T>;

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
                && is_tag<T>
            )
        void next(int& i, ecs_token& token) noexcept {
            i = entity_next(ctx(), component_id<T>, i, &token);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && !is_tag<T>
            )
        T* fetch(int i, ecs_token& token) noexcept {
            return (T*)entity_fetch(ctx(), component_id<T>, i, &token);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && !is_tag<T>
            )
        T* fetch(int i) noexcept {
            return (T*)entity_fetch(ctx(), component_id<T>, i, nullptr);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
            )
        int component_index(ecs_token token, [[maybe_unused]] int i) noexcept {
            return entity_component_index(ctx(), token, component_id<T>);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && is_tag<T>
            )
        bool component(ecs_token token, [[maybe_unused]] int i) noexcept {
            return entity_component_index(ctx(), token, component_id<T>) >= 0;
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && !is_tag<T>
            )
        T* component(ecs_token token, [[maybe_unused]] int i) noexcept {
            return (T*)entity_component(ctx(), token, component_id<T>);
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
            std::array<int, 1+sizeof...(Components)> keys {component_id<MainKey>, component_id<Components>...};
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
                && is_tag<T>
            )
        void next(int& i, ecs_token& token) noexcept {
            i = entity_next(ctx(), component_id<T>, i, &token);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && std::is_same_v<T, MainKey>
                && !is_tag<T>
            )
        T* fetch(int i, ecs_token& token) noexcept {
            return (T*)entity_fetch(ctx(), component_id<T>, i, &token);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && impl::has_element_v<T, Components...>
                && component_id<T> != COMPONENT::EID
            )
        int component_index(ecs_token token, [[maybe_unused]] int i) noexcept {
            return entity_cache_fetch_index(ctx(), c, i, component_id<T>);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && impl::has_element_v<T, Components...>
                && component_id<T> != COMPONENT::EID
                && is_tag<T>
            )
        bool component([[maybe_unused]] ecs_token token, int i) noexcept {
            return entity_cache_fetch_index(ctx(), c, i, component_id<T>) >= 0;
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && impl::has_element_v<T, Components...>
                && component_id<T> != COMPONENT::EID
                && !is_tag<T>
            )
        T* component([[maybe_unused]] ecs_token token, int i) noexcept {
            return (T*)entity_cache_fetch(ctx(), c, i, component_id<T>);
        }
        template <typename T>
            requires (
                !std::is_function_v<T>
                && component_id<T> == COMPONENT::EID
                && impl::has_element_v<T, Components...>
            )
        T* component(ecs_token token, [[maybe_unused]] int i) noexcept {
            return (T*)entity_component(ctx(), token, COMPONENT::EID);
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
            std::declval<std::conditional_t<std::is_function_v<Ts> || is_tag<Ts>,
                std::tuple<>,
                std::tuple<Ts*>
            >>()...
        ));

        template <std::size_t Is, typename T>
        static constexpr std::size_t next() noexcept {
            if constexpr (is_tag<T>) {
                return Is;
            }
            else {
                return Is+1;
            }
        }
    }

    struct find_t {};
    struct create_t {};
    struct first_t {};
    struct index_t {};

    template <typename Context, typename MainKey, typename ...SubKey>
    struct basic_entity {
    public:
        static constexpr int kInvalidIndex = -1;
        basic_entity(Context& ctx) noexcept
            : ctx(ctx)
        { }
        template <typename Component>
            requires (
                component_id<Component> == COMPONENT::EID
                && component_id<MainKey> == COMPONENT::EID
                && sizeof...(SubKey) == 0
            )
        basic_entity(find_t, ecs_context* ctx, Component eid) noexcept
            : ctx(context::create(ctx)) {
            index = entity_index(ctx, (void*)eid, &token);
            if (index >= 0) {
                std::get<Component*>(c) = (Component*)eid;
            }
        }
        template <typename ...Args>
            requires (
                sizeof...(SubKey) == 0
            )
        basic_entity(create_t, ecs_context* ctx, Args... args) noexcept
            : ctx(context::create(ctx)) {
            index = entity_new(ctx, component_id<MainKey>, &token);
            if (index == kInvalidIndex) {
                return;
            }
            if constexpr (!is_tag<MainKey>) {
                auto v = this->ctx.template fetch<MainKey>(index);
                assert(v);
                if (v) {
                    assgin<0>(v);
                    new (v) MainKey(std::forward<Args>(args)...);
                }
            }
        }
        basic_entity(first_t, ecs_context* ctx) noexcept
            : ctx(context::create(ctx)) {
            next();
        }
        template <typename ...Args>
            requires (
                sizeof...(SubKey) == 0
            )
        basic_entity(index_t, ecs_context* c, int idx) noexcept
            : ctx(context::create(c))
            , index(idx) {
            if constexpr (is_tag<MainKey>) {
                ctx.template next<MainKey>(index, token);
            }
            else {
                auto v = ctx.template fetch<MainKey>(index, token);
                if (!v) {
                    index = kInvalidIndex;
                    return;
                }
                assgin<0>(v);
            }
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
            if constexpr (is_tag<MainKey>) {
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
        template <typename T>
        int get_index() const noexcept {
            if constexpr (component_id<MainKey> == component_id<T>) {
                return index;
            }
            else {
                return ctx.template component_index<T>(token, index);
            }
        }
        ecs_token get_token() const noexcept {
            return token;
        }
        bool invalid() const {
            return index == kInvalidIndex;
        }
        template <typename T>
            requires (component_id<T> == COMPONENT::EID)
        T get() noexcept {
            return (T)std::get<T*>(c);
        }
        template <typename T>
            requires (component_id<T> != COMPONENT::EID && !is_tag<T>)
        T& get() noexcept {
            return *std::get<T*>(c);
        }
        template <typename T>
            requires (
                !impl::has_element_v<T, MainKey, SubKey...>
            )
        int component_index() const noexcept {
            return ctx.template component_index<T>(token, index);
        }
        template <typename T>
            requires (
                !impl::has_element_v<T, MainKey, SubKey...>
                && component_id<T> == COMPONENT::EID
            )
        T component() const noexcept {
            return (T)ctx.template component<T>(token, index);
        }
        template <typename T>
            requires (
                !impl::has_element_v<T, MainKey, SubKey...>
                && is_tag<T>
            )
        bool component() const noexcept {
            return ctx.template component<T>(token, index);
        }
        template <typename T>
            requires (
                !impl::has_element_v<T, MainKey, SubKey...>
                && component_id<T> != COMPONENT::EID
                && !is_tag<T>
            )
        T* component() const noexcept {
            return ctx.template component<T>(token, index);
        }
        template <typename T>
            requires (is_tag<T>)
        void enable_tag() noexcept {
            entity_enable_tag(ctx.ctx(), token, component_id<T>);
        }
        template <typename T>
            requires (is_tag<T>)
        void disable_tag() noexcept {
            if constexpr (component_id<MainKey> == component_id<T>) {
                ctx.disable_tag(component_id<MainKey>, index);
            }
            else {
                ctx.disable_tag(token, index, component_id<T>);
            }
        }
        void remove() noexcept {
            entity_enable_tag(ctx.ctx(), token, COMPONENT::REMOVED);
        }
    private:
        template <std::size_t Is, typename T>
        void assgin(T* v) noexcept {
            if constexpr (!is_tag<T>) {
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
            else if constexpr (is_tag<Component>) {
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
    }

    template <typename Component>
    void clear_type(ecs_context* ctx) noexcept {
        entity_clear_type(ctx, component_id<Component>);
    }

    template <typename Component, size_t N>
        requires (is_tag<Component>)
    void group_enable(ecs_context* ctx, int (&ids)[N]) noexcept {
        entity_group_enable(ctx, component_id<Component>, N, ids);
    }

    template <typename Component>
    size_t count(ecs_context* ctx) noexcept {
        return (size_t)entity_count(ctx, component_id<Component>);
    }

    template <typename Component, typename ...Args>
    auto create_entity(ecs_context* ctx, Args... args) noexcept {
        return entity<Component>(create_t {}, ctx, std::forward<Args>(args)...);
    }

    template <typename MainKey, typename ...SubKey>
    auto first_entity(ecs_context* ctx) noexcept {
        return entity<MainKey, SubKey...>(first_t {}, ctx);
    }

    template <typename Component>
        requires (component_id<Component> == COMPONENT::EID)
    auto find_entity(ecs_context* ctx, Component eid) noexcept {
        return entity<Component>(find_t {}, ctx, eid);
    }

    template <typename Component>
    auto index_entity(ecs_context* ctx, int index) noexcept {
        return entity<Component>(index_t {}, ctx, index);
    }

    template <typename Component>
        requires (!is_tag<Component>)
    std::span<Component> array(ecs_context* ctx) noexcept {
        Component* first = (Component*)entity_fetch(ctx, component_id<Component>, 0, NULL);
        if (!first) {
            return {};
        }
        Component* last = first + (size_t)entity_count(ctx, component_id<Component>);
        return { first, last };
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
