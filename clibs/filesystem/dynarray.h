#pragma once

#include <span>
#include <new>
#include <limits>
#include <memory.h>

namespace std {
    template <class T>
    class dynarray : public std::span<T> {
    public:
        typedef       std::span<T>                    mybase;
        typedef       T                               value_type;
        typedef       T& reference;
        typedef const T& const_reference;
        typedef       T* pointer;
        typedef const T* const_pointer;
        typedef       T* iterator;
        typedef const T* const_iterator;
        typedef std::reverse_iterator<iterator>       reverse_iterator;
        typedef std::reverse_iterator<const_iterator> const_reverse_iterator;
        typedef size_t                                size_type;
        typedef ptrdiff_t                             difference_type;

        static_assert(std::is_trivially_copyable<value_type>::value, "dynarray::value_type must be trivially copyable.");

        explicit dynarray(size_type c)
            : mybase(alloc(c), c)
        {}

        dynarray(const dynarray& d)
            : mybase(alloc(d.size()), d.size()) {
            uninitialized_copy(&*d.begin(), &*d.end(), &*mybase::begin());
        }
        dynarray(dynarray&& d)
            : mybase(d.data(), d.size()) {
            d = mybase();
        }
        dynarray(std::initializer_list<T> l)
            : mybase(alloc(l.size()), l.size()) {
            uninitialized_copy(l.begin(), l.end(), mybase::begin());
        }
        template <class Vec>
        dynarray(const Vec& v, typename std::enable_if<std::is_same<typename Vec::value_type, T>::value>::type* = 0)
            : mybase(alloc(v.size()), v.size()) {
            uninitialized_copy(&*v.begin(), &*v.end(), &*mybase::begin());
        }
        ~dynarray() {
            delete[] reinterpret_cast<char*>(mybase::data());
        }
        dynarray& operator=(const dynarray& d) {
            if (this != &d) {
                *(mybase*)this = mybase(alloc(d.size()), d.size());
                uninitialized_copy(&*d.begin(), &*d.end(), &*mybase::begin());
            }
            return *this;
        }
        dynarray& operator=(dynarray&& d) {
            if (this != &d) {
                *(mybase*)this = mybase(d.data(), d.size());
                *(mybase*)&d = mybase();
            }
            return *this;
        }
    private:
        class bad_array_length : public std::bad_alloc {
        public:
            bad_array_length() throw() { }
            virtual ~bad_array_length() throw() { }
            virtual const char* what() const throw() {
                return "bad_array_length";
            }
        };
        pointer alloc(size_type n) {
            if (n > (std::numeric_limits<size_type>::max)() / sizeof(T)) {
                throw bad_array_length();
            }
            return reinterpret_cast<pointer>(new char[n * sizeof(T)]);
        }
        void uninitialized_copy(const_iterator f, const_iterator l, iterator v) {
            memcpy(v, f, sizeof(value_type) * (l - f));
        }
    };
}
