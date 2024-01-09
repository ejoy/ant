#include <css/StyleCache.h>
#include <css/Property.h>
#include <assert.h>
#include <array>
#include <vector>
extern "C" {
#include <style.h>
}

constexpr inline style_handle_t STYLE_NULL = {0};

namespace Rml::Style {
    void TableRef::AddRef() const {
        if (idx == 0) {
            return;
        }
        Instance().TableAddRef(*this);
    }

    void TableRef::Release() const {
        if (idx == 0) {
            return;
        }
        Instance().TableRelease(*this);
    }

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

    TableRef Cache::Create() {
        style_handle_t s = style_create(c, 0, NULL);
        return {s.idx};
    }

    TableRef Cache::Create(const PropertyVector& vec) {
        style_handle_t s = style_create(c, (int)vec.size(), (int*)vec.data());
        return { s.idx };
    }

    TableRef Cache::Merge(const std::span<TableValue>& tables) {
        if (tables.empty()) {
            style_handle_t s = style_null(c);
            return {s.idx};
        }
        style_handle_t s = {tables[0].idx};
        for (size_t i = 1; i < tables.size(); ++i) {
            s = style_inherit(c, s, {tables[i].idx}, 0);
        }
        style_addref(c, s);
        return {s.idx};
    }

    TableRef Cache::Inherit(const TableRef& A, const TableRef& B, const TableRef& C) {
        style_handle_t s = style_inherit(c, {A.idx}, style_inherit(c, {B.idx}, {C.idx}, 0), 0);
        style_addref(c, s);
        return {s.idx};
    }

    TableRef Cache::Inherit(const TableRef& A, const TableRef& B) {
        style_handle_t s = style_inherit(c, {A.idx}, {B.idx}, 1);
        style_addref(c, s);
        return {s.idx};
    }

    TableRef Cache::Inherit(const TableRef& A) {
        style_addref(c, {A.idx});
        return {A.idx};
    }

    bool Cache::Assgin(const TableRef& to, const TableRef& from) {
        return 0 != style_assign(c, {to.idx}, {from.idx});
    }

    bool Cache::Compare(const TableRef& a, const TableRef& b) {
        return 0 != style_compare(c, {a.idx}, {b.idx});
    }

    void Cache::Clone(const TableRef& to, const TableRef& from) {
        style_assign(c, {to.idx}, {from.idx});
    }

    bool Cache::SetProperty(const TableRef& s, PropertyId id, const Property& prop) {
        int attrib_id = prop.RawAttribId();
        return !!style_modify(c, {s.idx}, 1, &attrib_id, 0, nullptr);
    }

    bool Cache::DelProperty(const TableRef& s, PropertyId id) {
        int removed_key[1] = { (int)(uint8_t)id };
        return !!style_modify(c, {s.idx}, 0, nullptr, 1, removed_key);
    }

    PropertyIdSet Cache::SetProperty(const TableRef& s, const PropertyVector& vec) {
        std::vector<int> attrib_id(vec.size());
        size_t i = 0;
        for (auto const& v : vec) {
            attrib_id[i] = v.RawAttribId();
            i++;
        }
        if (!style_modify(c, {s.idx}, (int)attrib_id.size(), attrib_id.data(), 0, nullptr)) {
            return {};
        }
        PropertyIdSet change;
        for (size_t i = 0; i < attrib_id.size(); ++i) {
            if (attrib_id[i]) {
                change.insert(GetPropertyId(vec[i]));
            }
        }
        return change;
    }

    PropertyIdSet Cache::DelProperty(const TableRef& s, const PropertyIdSet& set) {
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

    Property Cache::Find(const TableRef& s, PropertyId id) {
        int attrib_id = style_find(c, {s.idx}, (uint8_t)id);
        return { attrib_id };
    }

    bool Cache::Has(const TableRef& s, PropertyId id) {
        int attrib_id = style_find(c, {s.idx}, (uint8_t)id);
        return attrib_id != -1;
    }

    void Cache::Foreach(const TableRef& s, PropertyIdSet& set) {
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

    void Cache::Foreach(const TableRef& s, PropertyUnit unit, PropertyIdSet& set) {
        for (int i = 0;; ++i) {
            Property prop { style_index(c, {s.idx}, i) };
            if (!prop) {
                break;
            }
            if (prop.IsFloatUnit(unit)) {
                set.insert(GetPropertyId(prop));
            }
        }
    }

    static auto Fetch(style_cache* c, const TableRef& t) {
        std::array<int, (size_t)EnumCountV<PropertyId>> datas;
        datas.fill(-1);
        for (int i = 0;; ++i) {
            int attrib_id = style_index(c, {t.idx}, i);
            if (attrib_id == -1) {
                break;
            }
            style_attrib attrib;
            style_attrib_value(c, attrib_id, &attrib);
            datas[(size_t)attrib.key] = attrib_id;
        }
        return datas;
    }

    PropertyIdSet Cache::Diff(const TableRef& a, const TableRef& b) {
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

    Property Cache::CreateProperty(PropertyId id, std::span<uint8_t> value) {
        style_attrib v;
        v.key = (uint8_t)id;
        v.data = (void*)value.data();
        v.sz = value.size();
        int attrib_id = style_attrib_id(c, &v);
        return { attrib_id };
    }
        
    PropertyId Cache::GetPropertyId(Property prop) {
        style_attrib v;
        style_attrib_value(c, prop.RawAttribId(), &v);
        return (PropertyId)v.key;
    }

    std::span<const std::byte> Cache::GetPropertyData(Property prop) {
        style_attrib v;
        style_attrib_value(c, prop.RawAttribId(), &v);
        return { (const std::byte*)v.data, v.sz };
    }

    void Cache::PropertyAddRef(Property prop) {
        style_attrib_addref(c, prop.RawAttribId());
    }

    void Cache::PropertyRelease(Property prop) {
        style_attrib_release(c, prop.RawAttribId());
    }

    void Cache::TableAddRef(const TableRef& s) {
        style_addref(c, { s.idx });
    }

    void Cache::TableRelease(const TableRef& s) {
        style_release(c, { s.idx });
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
