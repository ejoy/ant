#pragma once

#include <core/ID.h>
#include <core/PropertyIdSet.h>
#include <core/PropertyDictionary.h>
#include <core/Property.h>
#include <span>
#include <optional>

struct style_cache;

namespace Rml::Style {
    using PropertyMap = struct { uint64_t idx; };
    using PropertyTempMap = struct { uint64_t idx; };

    struct EvalHandle {
        int handle;
        explicit operator bool() const {
            return handle >= 0;
        }
    };

    class Cache {
    public:
        Cache(const PropertyIdSet& inherit);
        ~Cache();
        PropertyMap               CreateMap();
        PropertyMap               CreateMap(const PropertyVector& vec);
        PropertyMap               CreateMap(const std::span<PropertyMap>& maps);
        void                      ReleaseMap(PropertyMap s);
        void                      SetProperty(PropertyMap s, const std::span<PropertyKV>& slice);
        void                      DelProperty(PropertyMap s, const std::span<PropertyId>& slice);
        PropertyTempMap           MergeMap(PropertyMap child, PropertyMap parent);
        PropertyTempMap           MergeMap(PropertyTempMap child, PropertyMap parent);
        PropertyTempMap           InheritMap(PropertyTempMap child, PropertyTempMap parent);
        void                      Flush();
        void                      Dump();
        EvalHandle                Eval(PropertyMap s);
        EvalHandle                Eval(PropertyTempMap s);
        std::optional<Property>   Find(EvalHandle attrib, PropertyId id);
        std::optional<PropertyKV> Index(EvalHandle attrib, size_t index);
    private:
        style_cache* c;
    };

    void Initialise(const PropertyIdSet& inherit);
    void Shutdown();
    Cache& Instance();
}


namespace Rml {
    
inline PropertyDictionary ToDict(Style::PropertyMap map) {
	auto& c = Style::Instance();
	auto h = c.Eval(map);
	assert(h);
    PropertyDictionary dict;
    for (size_t i = 0;; ++i) {
        auto r = c.Index(h, i);
        if (!r) {
            break;
        }
        dict.emplace(r->id, r->value);
    }
    return dict;
}

}
