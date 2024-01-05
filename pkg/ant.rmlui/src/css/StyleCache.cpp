#include <css/StyleCache.h>
#include <css/PropertyView.h>
#include <assert.h>
#include <array>
#include <vector>
extern "C" {
#include <style.h>
}

constexpr inline style_handle_t STYLE_NULL = {0};

namespace Rml::Style {
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
        std::vector<int> attrib_id(vec.size());
        size_t i = 0;
        for (auto const& [id, value] : vec) {
            PropertyGuard prop = PropertyEncode(value);
            style_attrib attrib = { prop.RawData(), prop.RawSize(), (uint8_t)id };
            attrib_id[i] = style_attrib_id(c, &attrib);
            i++;
        }
        style_handle_t s = style_create(c, (int)attrib_id.size(), attrib_id.data());
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

    bool Cache::Compare(Value a, Combination b) {
        return 0 != style_compare(c, {a.idx}, {b.idx});
    }

    void Cache::Clone(Value to, Value from) {
        style_assign(c, {to.idx}, {from.idx});
    }

    void Cache::Release(ValueOrCombination s) {
        style_release(c, {s.idx});
    }

    bool Cache::SetProperty(Value s, PropertyId id, const Property& value) {
        auto prop = PropertyEncode(value);
        style_attrib attrib = { prop.RawData(), prop.RawSize(), (uint8_t)id };
        int attrib_id = style_attrib_id(c, &attrib);
        return !!style_modify(c, {s.idx}, 1, &attrib_id, 0, nullptr);
    }

    bool Cache::SetProperty(Value s, PropertyId id, const PropertyView& prop) {
        style_attrib attrib = { prop.RawData(), prop.RawSize(), (uint8_t)id };
        int attrib_id = style_attrib_id(c, &attrib);
        return !!style_modify(c, {s.idx}, 1, &attrib_id, 0, nullptr);
    }

    bool Cache::DelProperty(Value s, PropertyId id) {
        int removed_key[1] = { (int)(uint8_t)id };
        return !!style_modify(c, {s.idx}, 0, nullptr, 1, removed_key);
    }

    PropertyIdSet Cache::SetProperty(Value s, const PropertyVector& vec) {
        std::vector<int> attrib_id(vec.size());
        size_t i = 0;
        for (auto const& [id, value] : vec) {
            PropertyGuard prop = PropertyEncode(value);
            style_attrib attrib = { prop.RawData(), prop.RawSize(), (uint8_t)id };
            attrib_id[i] = style_attrib_id(c, &attrib);
            i++;
        }
        if (!style_modify(c, {s.idx}, (int)attrib_id.size(), attrib_id.data(), 0, nullptr)) {
            return {};
        }
        PropertyIdSet change;
        for (size_t i = 0; i < attrib_id.size(); ++i) {
            if (attrib_id[i]) {
                change.insert(vec[i].id);
            }
        }
        return change;
    }

    PropertyIdSet Cache::DelProperty(Value s, const PropertyIdSet& set) {
        std::vector<int> removed_key(set.size());
        size_t i = 0;
        for (auto id : set) {
            removed_key[i] = (int)(uint8_t)id;
            i++;
        }
        if (!style_modify(c, {s.idx}, 0, nullptr, (int)removed_key.size(), removed_key.data())) {
            return {};
        }
        PropertyIdSet change;
        i = 0;
        for (auto id : set) {
            if (removed_key[i]) {
                change.insert(id);
            }
            i++;
        }
        return change;
    }

    std::optional<PropertyView> Cache::Find(ValueOrCombination s, PropertyId id) {
        int attrib_id = style_find(c, {s.idx}, (uint8_t)id);
        if (attrib_id == -1) {
            return std::nullopt;
        }
        style_attrib attrib;
        style_attrib_value(c, attrib_id, &attrib);
        return PropertyView { attrib.data, attrib.sz };
    }

    bool Cache::Has(ValueOrCombination s, PropertyId id) {
        int attrib_id = style_find(c, {s.idx}, (uint8_t)id);
        return attrib_id != -1;
    }

    void Cache::Foreach(ValueOrCombination s, PropertyIdSet& set) {
        for (int i = 0;; ++i) {
            int attrib_id = style_index(c, {s.idx}, i);
            if (attrib_id == -1) {
                break;
            }
            style_attrib attrib;
            style_attrib_value(c, attrib_id, &attrib);
            set.insert((PropertyId)attrib.key);
        }
    }

    void Cache::Foreach(ValueOrCombination s, PropertyUnit unit, PropertyIdSet& set) {
        for (int i = 0;; ++i) {
            int attrib_id = style_index(c, {s.idx}, i);
            if (attrib_id == -1) {
                break;
            }
            style_attrib attrib;
            style_attrib_value(c, attrib_id, &attrib);
            PropertyView prop { attrib.data, attrib.sz };
            if (prop.IsFloatUnit(unit)) {
                set.insert((PropertyId)attrib.key);
            }
        }
    }

    static auto Fetch(style_cache* c, ValueOrCombination t) {
        std::array<void*, (size_t)EnumCountV<PropertyId>> datas;
        datas.fill(nullptr);
        for (int i = 0;; ++i) {
            int attrib_id = style_index(c, {t.idx}, i);
            if (attrib_id == -1) {
                break;
            }
            style_attrib attrib;
            style_attrib_value(c, attrib_id, &attrib);
            datas[(size_t)attrib.key] = attrib.data;
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
