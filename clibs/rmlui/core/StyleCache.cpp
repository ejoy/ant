#include <core/StyleCache.h>
#include <core/PropertyBinary.h>
#include <assert.h>
#include <vector>
extern "C" {
#include <style.h>
}

namespace Rml::Style {

    using AttribKey  = PropertyId;
    using AttribData = const uint8_t*;
    struct AttribDataView {
        AttribData data;
        size_t     size;
    };
    struct Attrib {
        AttribKey      key;
        AttribDataView data;
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
            auto s = b.string();
            attrib[i++] = {
                id,
                {s.data(), s.size()},
            };
        }
        style_handle_t s = style_create(c, (int)attrib.size(), (struct style_attrib*)attrib.data());
        for (auto& v : attrib) {
            delete[] v.data.data;
        }
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
        s = style_clone(c, s);
        assert(!is_null(s));
        return {s.idx};
    }

    void Cache::ReleaseMap(PropertyMap s) {
        style_release(c, {s.idx});
    }

    void Cache::SetProperty(PropertyMap s, const std::span<PropertyKV>& slice) {
        strbuilder<uint8_t> b;
        std::vector<Attrib> attrib(slice.size());
        size_t i = 0;
        for (auto const& [id, value] : slice) {
            PropertyEncode(b, (PropertyVariant const&)value);
            auto s = b.string();
            attrib[i++] = {
                id,
                {s.data(), s.size()},
            };
        }
        style_modify(c, {s.idx}, (int)attrib.size(), (struct style_attrib*)attrib.data());
        for (auto& v : attrib) {
            delete[] v.data.data;
        }
    }

    void Cache::DelProperty(PropertyMap s, const std::span<PropertyId>& slice) {
        std::vector<Attrib> attrib(slice.size());
        size_t i = 0;
        for (auto const& id : slice) {
            attrib[i++] = {
                id,
                {NULL, 0},
            };
        }
        style_modify(c, {s.idx}, (int)attrib.size(), (struct style_attrib*)attrib.data());
    }

    PropertyTempMap Cache::MergeMap(PropertyMap child, PropertyMap parent) {
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

    EvalHandle Cache::Eval(PropertyMap s) {
        int h = style_eval(c, {s.idx});
        return {h};
    }

    EvalHandle Cache::Eval(PropertyTempMap s) {
        int h = style_eval(c, {s.idx});
        return {h};
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
