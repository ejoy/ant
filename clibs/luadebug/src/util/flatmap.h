#pragma once

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <functional>
#include <limits>
#include <stdexcept>

namespace luadebug {
    template <typename T>
    struct flatmap_hash {
        size_t operator()(T v) const noexcept {
            if constexpr (std::is_integral_v<T>) {
                uint64_t x = static_cast<uint64_t>(v);
                x ^= x >> 33U;
                x *= UINT64_C(0xff51afd7ed558ccd);
                x ^= x >> 33U;
                x *= UINT64_C(0xc4ceb9fe1a85ec53);
                x ^= x >> 33U;
                return static_cast<size_t>(x);
            }
            else {
                static_assert(std::is_trivial_v<T>);
                uint64_t i = 0;
                memcpy(&i, &v, sizeof(v));
                flatmap_hash<uint64_t> h;
                return h(i);
            }
        }
    };

    template <typename Key, typename T, typename KeyHash = flatmap_hash<Key>, typename KeyEqual = std::equal_to<Key>>
    class flatmap
        : public KeyHash
        , public KeyEqual {
    private:
        using key_type    = Key;
        using mapped_type = T;
        struct bucket_kv {
            key_type key;
            mapped_type obj;
            uint8_t dib;
            bucket_kv(const key_type& key, mapped_type&& obj, uint8_t dib)
                : key(key)
                , obj(std::forward<mapped_type>(obj))
                , dib(dib) {}
        };
        struct bucket_vk {
            mapped_type obj;
            key_type key;
            uint8_t dib;
            bucket_vk(const key_type& key, mapped_type&& obj, uint8_t dib)
                : obj(std::forward<mapped_type>(obj))
                , key(key)
                , dib(dib) {}
        };
        static constexpr size_t kInvalidSlot   = size_t(-1);
        static constexpr size_t kMaxLoadFactor = 80;
        static constexpr uint8_t kMaxDistance  = 128;
        static constexpr size_t kMaxTryRehash  = 1;

    public:
        using bucket = typename std::conditional<sizeof(bucket_kv) <= sizeof(bucket_vk), bucket_kv, bucket_vk>::type;
        static_assert(sizeof(bucket) <= 3 * sizeof(size_t));

        flatmap() noexcept
            : KeyHash()
            , KeyEqual() {}

        flatmap(flatmap&& rhs) {
            m_mask    = rhs.m_mask;
            m_maxsize = rhs.m_maxsize;
            m_size    = rhs.m_size;
            if (rhs.m_mask == 0) {
                m_buckets = reinterpret_cast<bucket*>(&m_mask);
            }
            else {
                m_buckets = rhs.m_buckets;
            }
            rhs.m_mask    = 0;
            rhs.m_maxsize = 0;
            rhs.m_size    = 0;
            rhs.m_buckets = reinterpret_cast<bucket*>(&rhs.m_mask);
        }

        flatmap& operator=(flatmap&& rhs) {
            std::swap(*this, rhs);
            return *this;
        }

        flatmap(const flatmap&)            = delete;
        flatmap& operator=(const flatmap&) = delete;

        ~flatmap() noexcept {
            if (m_size == 0) {
                return;
            }
            if constexpr (!std::is_trivially_destructible<bucket>::value) {
                for (size_t i = 0; i < m_mask + 1; ++i) {
                    if (m_buckets[i].dib != 0) {
                        m_buckets[i].key.~key_type();
                        m_buckets[i].obj.~mapped_type();
                        --m_size;
                        if (m_size == 0) {
                            break;
                        }
                    }
                }
            }
            std::free(m_buckets);
        }

        template <typename MappedType>
        bool insert(const key_type& key, MappedType obj) {
            if (m_size >= m_maxsize) {
                increase_size();
            }
            uint8_t dib = 1;
            size_t slot = KeyHash::operator()(key) & m_mask;
            for (;;) {
                if (m_buckets[slot].dib == 0) {
                    new (&m_buckets[slot]) bucket { key, std::forward<mapped_type>(obj), dib };
                    ++m_size;
                    return true;
                }
                if (KeyEqual::operator()(m_buckets[slot].key, key)) {
                    return false;
                }
                if (m_buckets[slot].dib < dib) {
                    bucket tmp { key, std::forward<mapped_type>(obj), dib };
                    std::swap(tmp, m_buckets[slot]);
                    ++tmp.dib;
                    internal_insert<kMaxTryRehash>((slot + 1) & m_mask, std::move(tmp));
                    return true;
                }
                ++dib;
                slot = (slot + 1) & m_mask;
            }
        }

        template <typename MappedType>
        void insert_or_assign(const key_type& key, MappedType obj) {
            if (m_size >= m_maxsize) {
                increase_size();
            }
            uint8_t dib = 1;
            size_t slot = KeyHash::operator()(key) & m_mask;
            for (;;) {
                if (m_buckets[slot].dib == 0) {
                    new (&m_buckets[slot]) bucket { key, std::forward<mapped_type>(obj), dib };
                    ++m_size;
                    return;
                }
                if (KeyEqual::operator()(m_buckets[slot].key, key)) {
                    m_buckets[slot].obj = std::forward<mapped_type>(obj);
                    return;
                }
                if (m_buckets[slot].dib < dib) {
                    bucket tmp { key, std::forward<mapped_type>(obj), dib };
                    std::swap(tmp, m_buckets[slot]);
                    ++tmp.dib;
                    internal_insert<kMaxTryRehash>((slot + 1) & m_mask, std::move(tmp));
                    return;
                }
                ++dib;
                slot = (slot + 1) & m_mask;
            }
        }

        [[nodiscard]] bool contains(const key_type& key) const noexcept {
            auto slot = find_key(key);
            return slot != kInvalidSlot;
        }

        [[nodiscard]] size_t size() const {
            return m_size;
        }

        [[nodiscard]] bool empty() const {
            return size() == 0;
        }

        [[nodiscard]] mapped_type* find(const key_type& key) noexcept {
            auto slot = find_key(key);
            if (slot == kInvalidSlot) {
                return nullptr;
            }
            return &m_buckets[slot].obj;
        }

        [[nodiscard]] const mapped_type* find(const key_type& key) const noexcept {
            return const_cast<flatmap*>(this)->find(key);
        }

        void erase(const key_type& key) noexcept {
            auto slot = find_key(key);
            if (slot == kInvalidSlot) {
                return;
            }

            size_t next_slot = (slot + 1) & m_mask;
            while (m_buckets[next_slot].dib > 1) {
                m_buckets[slot] = std::move(m_buckets[next_slot]);
                --m_buckets[slot].dib;

                slot      = next_slot;
                next_slot = (next_slot + 1) & m_mask;
            }

            m_buckets[slot].key.~key_type();
            m_buckets[slot].obj.~mapped_type();
            m_buckets[slot].dib = 0;
            m_size--;
        }

        void clear() {
            if (m_mask != 0) {
                std::free(m_buckets);
            }
            m_mask    = 0;
            m_maxsize = 0;
            m_size    = 0;
            m_buckets = reinterpret_cast<bucket*>(&m_mask);
        }

        void rehash(size_t c) {
            rehash(c, true);
        }

        void reserve(size_t c) {
            rehash(c * 100 / kMaxLoadFactor, false);
        }

        struct iterator {
            flatmap const& m;
            size_t n;
            iterator(flatmap const& m, size_t n)
                : m(m)
                , n(n) {
                next_valid();
            }
            bool operator!=(iterator& rhs) const {
                return &m != &rhs.m || n != rhs.n;
            }
            void operator++() {
                n++;
                next_valid();
            }
            std::pair<key_type, mapped_type> operator*() {
                auto& bucket = m.m_buckets[n];
                return { bucket.key, bucket.obj };
            }
            void next_valid() {
                while (n != (m.m_mask + 1) && m.m_buckets[n].dib == 0) {
                    n++;
                }
            }
        };
        using const_iterator = iterator;

        [[nodiscard]] const_iterator begin() const {
            return const_iterator { *this, 0 };
        }
        [[nodiscard]] const_iterator end() const {
            return const_iterator { *this, m_mask + 1 };
        }

        [[nodiscard]] iterator begin() {
            return iterator { *this, 0 };
        }
        [[nodiscard]] iterator end() {
            return iterator { *this, m_mask + 1 };
        }

        struct rawdata {
            struct {
                size_t mask;
                size_t maxsize;
                size_t size;
            } h;
            bucket* buckets;
        };
        [[nodiscard]] rawdata const& toraw() const {
            return *reinterpret_cast<const rawdata*>(&m_mask);
        }
        [[nodiscard]] rawdata& toraw() {
            return *reinterpret_cast<rawdata*>(&m_mask);
        }

#if 0
    [[nodiscard]] size_t max_distance() const noexcept {
        uint8_t distance = 0;
        for (size_t i = 0; i < m_mask + 1; ++i) {
            distance = (std::max)(m_buckets[i].dib, distance);
        }
        return distance;
    }
#endif

    private:
        [[nodiscard]] size_t find_key(const key_type& key) const noexcept {
            size_t slot = KeyHash::operator()(key) & m_mask;
            for (uint32_t dib = 1;; ++dib) {
                if (m_buckets[slot].dib != 0 && KeyEqual::operator()(key, m_buckets[slot].key)) {
                    return slot;
                }
                slot = (slot + 1) & m_mask;
                if (dib > m_buckets[slot].dib) {
                    return kInvalidSlot;
                }
            }
        }

        [[nodiscard]] size_t calc_maxsize(size_t maxsize) const noexcept {
            if (maxsize <= (std::numeric_limits<size_t>::max)() / 100) {
                return maxsize * kMaxLoadFactor / 100;
            }
            return (maxsize / 100) * kMaxLoadFactor;
        }

        template <size_t REHASH>
        void internal_insert(size_t slot, bucket&& tmp) {
            for (;;) {
                if (m_buckets[slot].dib == 0) {
                    new (&m_buckets[slot]) bucket(std::forward<bucket>(tmp));
                    ++m_size;
                    return;
                }
                if (m_buckets[slot].dib < tmp.dib) {
                    std::swap(tmp, m_buckets[slot]);
                }
                if (tmp.dib >= kMaxDistance - 1) {
                    if constexpr (REHASH > 0) {
                        increase_size();
                        return internal_insert<REHASH - 1>(std::forward<bucket>(tmp));
                    }
                    throw_overflow();
                }
                ++tmp.dib;
                slot = (slot + 1) & m_mask;
            }
        }

        template <size_t REHASH>
        void internal_insert(bucket&& b) {
            size_t slot = KeyHash::operator()(b.key) & m_mask;
            b.dib       = 1;
            return internal_insert<REHASH>(slot, std::forward<bucket>(b));
        }

        void increase_size() {
            rehash((m_mask + 1) * 2, true);
        }

        void rehash(size_t c, bool force) {
            size_t minsize    = (std::max)(c, m_size);
            size_t newmaxsize = 8;
            while (calc_maxsize(newmaxsize) < minsize && newmaxsize != 0) {
                newmaxsize *= 2;
            }
            if (newmaxsize == 0) {
                throw_overflow();
            }
            if (!force && newmaxsize <= m_mask + 1) {
                return;
            }

            bucket* oldbuckets = m_buckets;
            size_t oldmaxsize  = m_mask + 1;

            m_buckets = alloc_bucket(newmaxsize);
            m_size    = 0;
            m_maxsize = size_t(newmaxsize * kMaxLoadFactor / 100);
            m_mask    = newmaxsize - 1;
            if (oldmaxsize <= 1) {
                return;
            }

            free_bucket guard { oldbuckets };
            for (size_t i = 0; i < oldmaxsize; ++i) {
                if (oldbuckets[i].dib != 0) {
                    internal_insert<0>(std::move(oldbuckets[i]));
                }
            }
        }

        struct free_bucket {
            ~free_bucket() { std::free(b); }
            bucket* b;
        };

        static bucket* alloc_bucket(size_t n) {
            void* t = std::malloc(n * sizeof(bucket));
            if (!t) {
                throw std::bad_alloc {};
            }
            std::memset(t, 0, n * sizeof(bucket));
            return reinterpret_cast<bucket*>(t);
        }

        void throw_overflow() const {
            throw std::overflow_error("flatmap overflow");
        }

    private:
        size_t m_mask     = 0;
        size_t m_maxsize  = 0;
        size_t m_size     = 0;
        bucket* m_buckets = reinterpret_cast<bucket*>(&m_mask);
    };

    template <typename Key, typename KeyHash = flatmap_hash<Key>, typename KeyEqual = std::equal_to<Key>>
    class flatset : public flatmap<Key, uint8_t, KeyHash, KeyEqual> {
    private:
        using key_type = Key;
        using mybase   = flatmap<Key, uint8_t, KeyHash, KeyEqual>;

    public:
        bool insert(const key_type& key) {
            return mybase::insert(key, 0);
        }
    };
}
