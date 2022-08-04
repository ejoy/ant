#pragma once

#include <core/ID.h>
#include <core/PropertyIdSet.h>
#include <core/PropertyVector.h>
#include <core/Property.h>
#include <span>
#include <optional>

struct style_cache;

namespace Rml::Style {
    using PropertyMap = struct { uint64_t idx; };
    using PropertyTempMap = struct { uint64_t idx; };
    constexpr inline PropertyTempMap Null = {0};

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
        bool                      SetProperty(PropertyMap s, PropertyId id, const Property& value);
        bool                      DelProperty(PropertyMap s, PropertyId id);
        PropertyIdSet             SetProperty(PropertyMap s, const PropertyVector& vec);
        PropertyIdSet             DelProperty(PropertyMap s, const PropertyIdSet& set);
        PropertyTempMap           MergeMap(PropertyMap child, PropertyMap parent);
        PropertyTempMap           MergeMap(PropertyMap child, PropertyTempMap parent);
        PropertyTempMap           MergeMap(PropertyTempMap child, PropertyMap parent);
        PropertyTempMap           InheritMap(PropertyTempMap child, PropertyTempMap parent);
        PropertyTempMap           InheritMap(PropertyTempMap child, PropertyMap parent);
        void                      Dump();
        EvalHandle                Eval(PropertyTempMap s);
        EvalHandle                TryEval(PropertyTempMap s);
        std::optional<Property>   Find(PropertyMap s, PropertyId id);
        std::optional<Property>   Find(EvalHandle attrib, PropertyId id);
        std::optional<PropertyKV> Index(EvalHandle attrib, size_t index);
        PropertyIdSet             Diff(PropertyMap a, PropertyMap b);
        void                      Flush();

    private:
        style_cache* c;
    };

    void Initialise(const PropertyIdSet& inherit);
    void Shutdown();
    Cache& Instance();
}
