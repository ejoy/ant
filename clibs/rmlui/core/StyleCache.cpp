#include <core/StyleCache.h>
#include <core/PropertyBinary.h>
#include <assert.h>
#include <vector>
extern "C" {
#include <style.h>
}

constexpr inline style_handle_t STYLE_NULL = {0};

namespace Rml::Style {
    struct Attrib: public style_attrib {
        ~Attrib() {
            delete[] data;
        }
    };

    Cache::Cache(const PropertyIdSet& inherit) {
        uint8_t inherit_mask[128] = {0};
        for (auto id : inherit) {
            inherit_mask[(size_t)id] = 1;
        }
        c = style_newcache(inherit_mask);
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
        strbuilder<uint8_t> b;
        std::vector<Attrib> attrib(vec.size());
        size_t i = 0;
        for (auto const& [id, value] : vec) {
            PropertyEncode(b, (PropertyVariant const&)value);
            auto str = b.string();
            attrib[i].data = str.data();
            attrib[i].sz = str.size();
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

    void Cache::Assgin(Value s, Combination v) {
        style_assign(c, {s.idx}, {v.idx});
    }

    void Cache::Release(ValueOrCombination s) {
        style_release(c, {s.idx});
    }

    bool Cache::SetProperty(Value s, PropertyId id, const Property& value) {
        strbuilder<uint8_t> b;
        PropertyEncode(b, (PropertyVariant const&)value);
        auto str = b.string();
        Attrib attrib = { str.data(), str.size(), (uint8_t)id, 0 };
        return !!style_modify(c, {s.idx}, 1, &attrib);
    }

    bool Cache::DelProperty(Value s, PropertyId id) {
        style_attrib attrib = { NULL, 0, (uint8_t)id, 0 };
        return !!style_modify(c, {s.idx}, 1, &attrib);
    }

    PropertyIdSet Cache::SetProperty(Value s, const PropertyVector& vec) {
        strbuilder<uint8_t> b;
        std::vector<Attrib> attrib(vec.size());
        size_t i = 0;
        for (auto const& [id, value] : vec) {
            PropertyEncode(b, (PropertyVariant const&)value);
            auto str = b.string();
            attrib[i].data = str.data();
            attrib[i].sz = str.size();
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

    std::optional<Property> Cache::Find(ValueOrCombination s, PropertyId id) {
        void* data = style_find(c, {s.idx}, (uint8_t)id);
        if (!data) {
            return std::nullopt;
        }
        strparser<uint8_t> p {(const uint8_t*)data};
        return PropertyDecode(tag_v<Property>, p);
    }

    std::optional<PropertyKV> Cache::Index(ValueOrCombination s, size_t index) {
        PropertyId id;
        void* data = style_index(c, {s.idx}, (int)index, (uint8_t*)&id);
        if (!data) {
            return std::nullopt;
        }
        strparser<uint8_t> p {(const uint8_t*)data};
        return PropertyKV { id, PropertyDecode(tag_v<Property>, p)};
    }

    PropertyIdSet Cache::Diff(ValueOrCombination a, ValueOrCombination b) {
        PropertyIdSet mark;
        PropertyIdSet ids;
        
        for (int i = 0;; ++i) {
            PropertyId id;
            void* data_a = style_index(c, {a.idx}, i, (uint8_t*)&id);
            if (!data_a) {
                break;
            }
            mark.insert(id);
            void* data_b = style_find(c, {b.idx}, (uint8_t)id);
            if (!data_b || data_a != data_b) {
                ids.insert(id);
            }
        }

        for (int i = 0;; ++i) {
            PropertyId id;
            void* data_b = style_index(c, {b.idx}, i, (uint8_t*)&id);
            if (!data_b) {
                break;
            }
            if (!mark.contains(id)) {
                void* data_a = style_find(c, {a.idx}, (uint8_t)id);
                if (!data_a || data_a != data_b) {
                    ids.insert(id);
                }
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
