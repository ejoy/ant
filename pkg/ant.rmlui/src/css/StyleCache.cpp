#include <css/StyleCache.h>
#include <css/PropertyRaw.h>
#include <assert.h>
#include <array>
#include <vector>
extern "C" {
#include <style.h>
}

constexpr inline style_handle_t STYLE_NULL = {0};

namespace Rml::Style {
    struct Attrib: public style_attrib {
        ~Attrib() {
            delete[] (uint8_t*)data;
        }
    };

    Cache::Cache(const PropertyIdSet& inherit) {
        uint8_t inherit_mask[128] = {0};
        for (auto id : inherit) {
            inherit_mask[(size_t)id] = 1;
        }
        c = style_newcache(inherit_mask, NULL, NULL);
        assert(c);
    }

    Cache::~Cache() {
        style_deletecache(c);
    }

    Value Cache::Create() {
        style_handle_t s = style_create(c, 0, NULL);
        return {s.idx};
    }

    Value Cache::Create(const PropertyVector& vec) {
        std::vector<Attrib> attrib(vec.size());
        size_t i = 0;
        for (auto const& [id, value] : vec) {
            auto prop = PropertyEncode(value);
            attrib[i].data = prop.RawData();
            attrib[i].sz = prop.RawSize();
            attrib[i].key = (uint8_t)id;
            i++;
        }
        style_handle_t s = style_create(c, (int)attrib.size(), attrib.data());
        return {s.idx};
    }

    Combination Cache::Merge(const std::span<Value>& maps) {
        if (maps.empty()) {
            style_handle_t s = style_null(c);
            return {s.idx};
        }
        style_handle_t s = {maps[0].idx};
        for (size_t i = 1; i < maps.size(); ++i) {
            s = style_inherit(c, s, {maps[i].idx}, 0);
        }
        return {s.idx};
    }

    Combination Cache::Merge(Value A, Value B, Value C) {
        style_handle_t s = style_inherit(c, {A.idx}, style_inherit(c, {B.idx}, {C.idx}, 0), 0);
        style_addref(c, s);
        return {s.idx};
    }

    Combination Cache::Inherit(Combination child, Combination parent) {
        style_handle_t s = style_inherit(c, {child.idx}, {parent.idx}, 1);
        style_addref(c, s);
        return {s.idx};
    }

    Combination Cache::Inherit(Combination child) {
        style_addref(c, {child.idx});
        return {child.idx};
    }

    bool Cache::Assgin(Value to, Combination from) {
        return 0 != style_assign(c, {to.idx}, {from.idx});
    }

    void Cache::Clone(Value to, Value from) {
        style_assign(c, {to.idx}, {from.idx});
    }

    void Cache::Release(ValueOrCombination s) {
        style_release(c, {s.idx});
    }

    bool Cache::SetProperty(Value s, PropertyId id, const Property& value) {
        auto prop = PropertyEncode(value);
        style_attrib attrib = { prop.RawData(), prop.RawSize(), (uint8_t)id, 0 };
        return !!style_modify(c, {s.idx}, 1, &attrib);
    }

    bool Cache::SetProperty(Value s, PropertyId id, const PropertyRaw& prop) {
        style_attrib attrib = { prop.RawData(), prop.RawSize(), (uint8_t)id, 0 };
        return !!style_modify(c, {s.idx}, 1, &attrib);
    }

    bool Cache::DelProperty(Value s, PropertyId id) {
        style_attrib attrib = { NULL, 0, (uint8_t)id, 0 };
        return !!style_modify(c, {s.idx}, 1, &attrib);
    }

    PropertyIdSet Cache::SetProperty(Value s, const PropertyVector& vec) {
        std::vector<Attrib> attrib(vec.size());
        size_t i = 0;
        for (auto const& [id, value] : vec) {
            auto prop = PropertyEncode(value);
            attrib[i].data = prop.RawData();
            attrib[i].sz = prop.RawSize();
            attrib[i].key = (uint8_t)id;
            i++;
        }
        if (!style_modify(c, {s.idx}, (int)attrib.size(), attrib.data())) {
            return {};
        }
        PropertyIdSet change;
        for (auto const& a: attrib) {
            if (a.change) {
                change.insert((PropertyId)a.key);
            }
        }
        return change;
    }

    PropertyIdSet Cache::DelProperty(Value s, const PropertyIdSet& set) {
        std::vector<Attrib> attrib(set.size());
        size_t i = 0;
        for (auto id : set) {
            attrib[i].data = NULL;
            attrib[i].sz = 0;
            attrib[i].key = (uint8_t)id;
            i++;
        }
        if (!style_modify(c, {s.idx}, (int)attrib.size(), attrib.data())) {
            return {};
        }
        PropertyIdSet change;
        for (auto const& a: attrib) {
            if (a.change) {
                change.insert((PropertyId)a.key);
            }
        }
        return change;
    }

    std::optional<PropertyRaw> Cache::Find(ValueOrCombination s, PropertyId id) {
        size_t size;
        void* data = style_find(c, {s.idx}, (uint8_t)id, &size);
        if (!data) {
            return std::nullopt;
        }
        return PropertyRaw { data, size };
    }

    bool Cache::Has(ValueOrCombination s, PropertyId id) {
        void* data = style_find(c, {s.idx}, (uint8_t)id, nullptr);
        return !!data;
    }

    void Cache::Foreach(ValueOrCombination s, PropertyIdSet& set) {
        for (int i = 0;; ++i) {
            PropertyId id;
            void* data = style_index(c, {s.idx}, i, (uint8_t*)&id, nullptr);
            if (!data) {
                break;
            }
            set.insert(id);
        }
    }

    void Cache::Foreach(ValueOrCombination s, PropertyUnit unit, PropertyIdSet& set) {
        for (int i = 0;; ++i) {
            PropertyId id;
            size_t size;
            void* data = style_index(c, {s.idx}, i, (uint8_t*)&id, &size);
            if (!data) {
                break;
            }
            PropertyRaw prop { data, size };
            if (prop.IsFloatUnit(unit)) {
                set.insert(id);
            }
        }
    }

    static auto Fetch(style_cache* c, ValueOrCombination t) {
        std::array<void*, (size_t)EnumCountV<PropertyId>> datas;
        datas.fill(nullptr);
        for (int i = 0;; ++i) {
            PropertyId id;
            void* data = style_index(c, {t.idx}, i, (uint8_t*)&id, nullptr);
            if (!data) {
                break;
            }
            datas[(size_t)id] = data;
        }
        return datas;
    }

    PropertyIdSet Cache::Diff(ValueOrCombination a, ValueOrCombination b) {
        PropertyIdSet ids;
        auto a_datas = Fetch(c, a);
        auto b_datas = Fetch(c, b);
        for (size_t i = 0; i < (size_t)EnumCountV<PropertyId>; ++i) {
            if (a_datas[i] != b_datas[i]) {
                ids.insert((PropertyId)i);
            }
        }
        return ids;
    }

    void Cache::Flush() {
        style_flush(c);
    }

    static Cache* cahce = nullptr;

    void Initialise(const PropertyIdSet& inherit) {
        assert(!cahce);
        cahce = new Cache(inherit);
    }

    void Shutdown() {
        delete cahce;
    }

    Cache& Instance() {
        return *cahce;
    }
}
