#pragma once

#include <bee/nonstd/span.h>

namespace std {
    template <class T>
    class dynarray : public nonstd::span<T> {
    public:
        typedef       nonstd::span<T>                 mybase;
        typedef       T                               value_type;
        typedef       T&                              reference;
        typedef const T&                              const_reference;
        typedef       T*                              pointer;
        typedef const T*                              const_pointer;
        typedef       T*                              iterator;
        typedef const T*                              const_iterator;
        typedef std::reverse_iterator<iterator>       reverse_iterator;
        typedef std::reverse_iterator<const_iterator> const_reverse_iterator;
        typedef size_t                                size_type;
        typedef ptrdiff_t                             difference_type;

        explicit dynarray(size_type c)
            : mybase(alloc(c), c)
        { 
            auto i = mybase::begin();
            try {
                for (; i != mybase::end(); ++i) {
                    new (&*i) T;
                }
            }
            catch (...) {
                for (; i >= mybase::begin(); --i) {
                    i->~T();
                }
                throw;
            } 
        }

        dynarray(const dynarray& d)
            : mybase(alloc(d.size()), d.size())
        { 
            try { 
                uninitialized_copy(d.begin(), d.end(), mybase::begin());
            }
            catch (...) {
                delete[] reinterpret_cast<char*>(mybase::data());
                throw; 
            } 
        }

        dynarray(dynarray&& d)
            : mybase(d.data(), d.size())
        {
            d = mybase();
        }

        dynarray(std::initializer_list<T> l)
            : mybase(alloc(l.size()), l.size())
        {
            try {
                uninitialized_copy(l.begin(), l.end(), mybase::begin());
            }
            catch (...) {
                delete[] reinterpret_cast<char*>(mybase::store_);
                throw;
            }
        }

        template <class Vec>
        dynarray(const Vec& v, typename std::enable_if<std::is_same<typename Vec::value_type, T>::value>::type* =0)
            : mybase(alloc(v.size()), v.size())
        {
            try {
                uninitialized_copy(v.begin(), v.end(), mybase::begin());
            }
            catch (...) {
                delete[] reinterpret_cast<char*>(mybase::data());
                throw;
            }
        }

        ~dynarray()
        {
            for (auto& i : *this) {
                i.~T();
            }
            delete[] reinterpret_cast<char*>(mybase::data());
        }

        dynarray& operator=(const dynarray& d) {
            if (this != &d) {
                *(mybase*)this = mybase(alloc(d.size()), d.size());
                try {
                    uninitialized_copy(d.begin(), d.end(), mybase::begin());
                }
                catch (...) {
                    delete[] reinterpret_cast<char*>(mybase::data());
                    throw;
                }
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
        class bad_array_length : public bad_alloc {
        public:
            bad_array_length() throw() { }
            virtual ~bad_array_length() throw() { }
            virtual const char* what() const throw() { 
                return "std::bad_array_length"; 
            }
        };

        pointer alloc(size_type n)
        { 
            if (n > (std::numeric_limits<size_type>::max)()/sizeof(T))
            {
                throw bad_array_length();
            }
            return reinterpret_cast<pointer>(new char[n*sizeof(T)]); 
        }
    };
}
