#pragma once

#include <core/ID.h>
#include <css/PropertyIdSet.h>
#include <css/Property.h>
#include <span>
#include <functional>

struct style_cache;

namespace Rml::Style {
    class TableRef {
    public:
        TableRef()
            : idx(0)
        {}
        TableRef(int idx)
            : idx(idx)
        {}
        ~TableRef() {
            Release();
        }
        TableRef(TableRef&& rhs)
            : idx(rhs.idx) {
            rhs.idx = 0;
        }
        TableRef(const TableRef& rhs)
            : idx(rhs.idx) {
            AddRef();
        }
        TableRef& operator=(TableRef&& rhs) {
            if (this != &rhs) {
                Release();
                idx = rhs.idx;
                rhs.idx = 0 ;
            }
            return *this;
        }
        TableRef& operator=(const TableRef& rhs) {
            if (this != &rhs) {
                Release();
                idx = rhs.idx;
                AddRef();
            }
            return *this;
        }
        void AddRef() const;
        void Release() const;

        int idx;
    };

    struct TableValue {
        TableValue(TableRef o): idx(o.idx) {}
        int idx;
    };

    class Cache {
    public:
        Cache(const PropertyIdSet& inherit);
        ~Cache();
        TableRef                   Create();
        TableRef                   Create(const PropertyVector& vec);
        TableRef                   Merge(const std::span<TableValue>& tables);
        TableRef                   Inherit(const TableRef& A, const TableRef& B, const TableRef& C);
        TableRef                   Inherit(const TableRef& A, const TableRef& B);
        TableRef                   Inherit(const TableRef& A);
        bool                       Assgin(const TableRef& to, const TableRef& from);
        bool                       Compare(const TableRef& a, const TableRef& b);
        void                       Clone(const TableRef& to, const TableRef& from);
        bool                       SetProperty(const TableRef& s, PropertyId id, const Property& value);
        bool                       DelProperty(const TableRef& s, PropertyId id);
        PropertyIdSet              SetProperty(const TableRef& s, const PropertyVector& vec);
        PropertyIdSet              DelProperty(const TableRef& s, const PropertyIdSet& set);
        Property                   Find(const TableRef& s, PropertyId id);
        bool                       Has(const TableRef& s, PropertyId id);
        void                       Foreach(const TableRef& s, PropertyIdSet& set);
        void                       Foreach(const TableRef& s, PropertyUnit unit, PropertyIdSet& set);
        PropertyIdSet              Diff(const TableRef& a, const TableRef& b);
        void                       Flush();
        Property                   CreateProperty(PropertyId id, std::span<uint8_t> value);
        PropertyId                 GetPropertyId(Property prop);
        std::span<const std::byte> GetPropertyData(Property prop);
        void                       PropertyAddRef(Property prop);
        void                       PropertyRelease(Property prop);
        void                       TableAddRef(const TableRef& s);
        void                       TableRelease(const TableRef& s);

    private:
        style_cache* c;
    };

    void Initialise(const PropertyIdSet& inherit);
    void Shutdown();
    Cache& Instance();
}
