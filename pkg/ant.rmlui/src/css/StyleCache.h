#pragma once

#include <core/ID.h>
#include <css/PropertyIdSet.h>
#include <css/PropertyVector.h>
#include <css/Property.h>
#include <css/PropertyRaw.h>
#include <span>
#include <optional>
#include <functional>

struct style_cache;

namespace Rml::Style {
    struct Value { int idx; };
    struct Combination { int idx; };
    struct ValueOrCombination {
        ValueOrCombination(Value o): idx(o.idx) {}
        ValueOrCombination(Combination o): idx(o.idx) {}
        int idx;
    };

    class Cache {
    public:
        Cache(const PropertyIdSet& inherit);
        ~Cache();
        Value                      Create();
        Value                      Create(const PropertyVector& vec);
        Combination                Merge(const std::span<Value>& maps);
        Combination                Merge(Value A, Value B, Value C);
        Combination                Inherit(Combination child, Combination parent);
        Combination                Inherit(Combination child);
        void                       Release(ValueOrCombination s);
        bool                       Assgin(Value to, Combination from);
        void                       Clone(Value to, Value from);
        bool                       SetProperty(Value s, PropertyId id, const Property& value);
        bool                       SetProperty(Value s, PropertyId id, const PropertyRaw& value);
        bool                       DelProperty(Value s, PropertyId id);
        PropertyIdSet              SetProperty(Value s, const PropertyVector& vec);
        PropertyIdSet              DelProperty(Value s, const PropertyIdSet& set);
        std::optional<PropertyRaw> Find(ValueOrCombination s, PropertyId id);
        bool                       Has(ValueOrCombination s, PropertyId id);
        void                       Foreach(ValueOrCombination s, PropertyIdSet& set);
        void                       Foreach(ValueOrCombination s, PropertyUnit unit, PropertyIdSet& set);
        PropertyIdSet              Diff(ValueOrCombination a, ValueOrCombination b);
        void                       Flush();

    private:
        style_cache* c;
    };

    void Initialise(const PropertyIdSet& inherit);
    void Shutdown();
    Cache& Instance();
}
