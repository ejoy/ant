#pragma once

#include <core/ID.h>
#include <core/PropertyIdSet.h>
#include <core/PropertyVector.h>
#include <core/Property.h>
#include <span>
#include <optional>

struct style_cache;

namespace Rml::Style {
    struct PropertyMap { int idx; };
    struct PropertyCombination { int idx; };
    struct PropertyAny {
        PropertyAny(PropertyMap o): idx(o.idx) {}
        PropertyAny(PropertyCombination o): idx(o.idx) {}
        int idx;
    };

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
        PropertyCombination       Merge(const std::span<PropertyMap>& maps);
        PropertyCombination       Merge(PropertyMap A, PropertyMap B, PropertyMap C);
        PropertyCombination       Inherit(PropertyCombination child, PropertyCombination parent);
        PropertyCombination       Inherit(PropertyCombination child);
        void                      ReleaseMap(PropertyAny s);
        void                      AssginMap(PropertyMap s, PropertyCombination v);
        bool                      SetProperty(PropertyMap s, PropertyId id, const Property& value);
        bool                      DelProperty(PropertyMap s, PropertyId id);
        PropertyIdSet             SetProperty(PropertyMap s, const PropertyVector& vec);
        PropertyIdSet             DelProperty(PropertyMap s, const PropertyIdSet& set);
        std::optional<Property>   Find(PropertyAny s, PropertyId id);
        std::optional<PropertyKV> Index(PropertyAny s, size_t index);
        PropertyIdSet             Diff(PropertyAny a, PropertyAny b);
        void                      Flush();

    private:
        style_cache* c;
    };

    void Initialise(const PropertyIdSet& inherit);
    void Shutdown();
    Cache& Instance();
}
