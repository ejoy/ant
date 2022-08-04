#include <core/StyleCache.h>
#include <core/PropertyBinary.h>
#include <assert.h>
#include <vector>
extern "C" {
#include <style.h>
}

namespace Rml::Style {
    struct Attrib: public style_attrib {
        ~Attrib() {
            delete[] data;
        }
    };

    static bool is_null(style_handle_t s) {
        return s.idx == 0;
    }

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

    PropertyMap Cache::CreateMap() {
        style_handle_t s = style_create(c, 0, NULL);
        return {s.idx};
    }

    PropertyMap Cache::CreateMap(const PropertyVector& vec) {
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

    PropertyMap Cache::CreateMap(const std::span<PropertyMap>& maps) {
        style_handle_t s = STYLE_NULL;
        for (auto v : maps) {
            if (is_null(s)) {
                s.idx = v.idx;
            }
            else {
                s = style_inherit(c, s, {v.idx}, 0);
            }
        }
        if (is_null(s)) {
            return CreateMap();
        }
        style_handle_t r = style_clone(c, s);
        assert(!is_null(r));
        return {r.idx};
    }

    void Cache::ReleaseMap(PropertyMap s) {
        style_release(c, {s.idx});
    }

    bool Cache::SetProperty(PropertyMap s, PropertyId id, const Property& value) {
        strbuilder<uint8_t> b;
        PropertyEncode(b, (PropertyVariant const&)value);
        auto str = b.string();
        Attrib attrib = { str.data(), str.size(), (uint8_t)id, 0 };
        return !!style_modify(c, {s.idx}, 1, &attrib);
    }

    bool Cache::DelProperty(PropertyMap s, PropertyId id) {
        style_attrib attrib = { NULL, 0, (uint8_t)id, 0 };
        return !!style_modify(c, {s.idx}, 1, &attrib);
    }

    PropertyIdSet Cache::SetProperty(PropertyMap s, const PropertyVector& vec) {
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

    PropertyIdSet Cache::DelProperty(PropertyMap s, const PropertyIdSet& set) {
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

    PropertyTempMap Cache::MergeMap(PropertyMap child, PropertyMap parent) {
        style_handle_t s = style_inherit(c, {child.idx}, {parent.idx}, 0);
        return {s.idx};
    }

    PropertyTempMap Cache::MergeMap(PropertyMap child, PropertyTempMap parent) {
        style_handle_t s = style_inherit(c, {child.idx}, {parent.idx}, 0);
        return {s.idx};
    }

    PropertyTempMap Cache::MergeMap(PropertyTempMap child, PropertyMap parent) {
        style_handle_t s = style_inherit(c, {child.idx}, {parent.idx}, 0);
        return {s.idx};
    }

    PropertyTempMap Cache::InheritMap(PropertyTempMap child, PropertyTempMap parent) {
        style_handle_t s = style_inherit(c, {child.idx}, {parent.idx}, 1);
        return {s.idx};
    }

    PropertyTempMap Cache::InheritMap(PropertyTempMap child, PropertyMap parent) {
        style_handle_t s = style_inherit(c, {child.idx}, {parent.idx}, 1);
        return {s.idx};
    }

    EvalHandle Cache::Eval(PropertyTempMap s) {
        int h = style_eval(c, {s.idx});
        return {h};
    }

    EvalHandle Cache::TryEval(PropertyTempMap s) {
        int h = style_eval(c, {s.idx});
        assert(h >= 0);
        return {h};
    }

    std::optional<Property> Cache::Find(PropertyMap s, PropertyId id) {
        int h = style_eval(c, {s.idx});
        assert(h >= 0);
        void* data = style_find(c, h, (uint8_t)id);
        if (!data) {
            return std::nullopt;
        }
        strparser<uint8_t> p {(const uint8_t*)data};
        return PropertyDecode(tag_v<Property>, p);
    }

    std::optional<Property> Cache::Find(EvalHandle attrib, PropertyId id) {
        void* data = style_find(c, attrib.handle, (uint8_t)id);
        if (!data) {
            return std::nullopt;
        }
        strparser<uint8_t> p {(const uint8_t*)data};
        return PropertyDecode(tag_v<Property>, p);
    }

    std::optional<PropertyKV> Cache::Index(EvalHandle attrib, size_t index) {
        PropertyId id;
        void* data = style_index(c, attrib.handle, (int)index, (uint8_t*)&id);
        if (!data) {
            return std::nullopt;
        }
        strparser<uint8_t> p {(const uint8_t*)data};
        return PropertyKV { id, PropertyDecode(tag_v<Property>, p)};
    }

    PropertyIdSet Cache::Diff(PropertyMap a, PropertyMap b) {
        PropertyIdSet mark;
        PropertyIdSet ids;
        int ha = style_eval(c, {a.idx});
        int hb = style_eval(c, {b.idx});
        assert (ha >= 0 && hb >= 0);
        
        for (int i = 0;; ++i) {
            PropertyId id;
            void* data_a = style_index(c, ha, i, (uint8_t*)&id);
            if (!data_a) {
                break;
            }
            mark.insert(id);
            void* data_b = style_find(c, hb, (uint8_t)id);
            if (!data_b || data_a != data_b) {
                ids.insert(id);
            }
        }

        for (int i = 0;; ++i) {
            PropertyId id;
            void* data_b = style_index(c, hb, i, (uint8_t*)&id);
            if (!data_b) {
                break;
            }
            if (!mark.contains(id)) {
                void* data_a = style_find(c, ha, (uint8_t)id);
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

    void Cache::Dump() {
        style_dump(c);
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
