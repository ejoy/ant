#pragma once

#include <core/ID.h>
#include <core/PropertyIdSet.h>
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

    struct PropertyKV {
        PropertyId id;
        Property   value;
    };

    class Cache {
    public:
        Cache(const PropertyIdSet& inherit);
        ~Cache();
        PropertyMap             CreateMap();
        PropertyMap             CreateMap(const std::span<PropertyKV>& slice);
        PropertyMap             CreateMap(const std::span<PropertyMap>& maps);
        void                    ReleaseMap(PropertyMap s);
        void                    SetProperty(PropertyMap s, const std::span<PropertyKV>& slice);
        void                    DelProperty(PropertyMap s, const std::span<PropertyId>& slice);
        PropertyTempMap         MergeMap(PropertyMap child, PropertyMap parent);
        PropertyTempMap         MergeMap(PropertyTempMap child, PropertyMap parent);
        PropertyTempMap         InheritMap(PropertyTempMap child, PropertyTempMap parent);
        void                    Flush();
        EvalHandle              Eval(PropertyMap s);
        EvalHandle              Eval(PropertyTempMap s);
        std::optional<Property> Find(EvalHandle attrib, PropertyId id);
    private:
        style_cache* c;
    };

    void Initialise(const PropertyIdSet& inherit);
    void Shutdown();
    Cache& Instance();
}
