#pragma once

#include <cassert>
#include <exception>
#include <limits>
#include <iterator>

namespace std {
	template <class T>
	class array_view {
	public:
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

		explicit array_view(pointer p, size_type c) 
			: store_(p)
			, count_(c)
		{ }
		array_view(const array_view& d) 
			: store_(d.store_)
			, count_(d.count_)
		{ }
		array_view(array_view&& d) 
			: store_(d.store_)
			, count_(d.count_)
		{
			d.store_ = nullptr;
			d.count_ = 0;
		}
		~array_view() { }
		array_view& operator=(const array_view& d) {
			if (this != &d) {
				store_ = d.store_;
				count_ = d.count_;
			}
			return *this;
		}
		array_view& operator=(array_view&& d) {
			if (this != &d) {
				store_ = d.store_;
				count_ = d.count_;
				d.store_ = nullptr;
				d.count_ = 0;
			}
			return *this;
		}

		iterator               begin()                       { return store_; }
		const_iterator         begin()                 const { return store_; }
		const_iterator         cbegin()                const { return store_; }
		iterator               end()                         { return begin() + size(); }
		const_iterator         end()                   const { return cbegin() + size(); }
		const_iterator         cend()                  const { return cbegin() + size(); }
		reverse_iterator       rbegin()                      { return reverse_iterator(end()); }
		const_reverse_iterator rbegin()                const { return reverse_iterator(cend()); }
		reverse_iterator       rend()                        { return reverse_iterator(begin()); }
		const_reverse_iterator rend()                  const { return reverse_iterator(cbegin()); }
		size_type              size()                  const { return count_; }
		size_type              max_size()              const { return count_; }
		bool                   empty()                 const { return size() == 0; }
		reference              operator[](size_type n)       { assert(size() > n); return store_[n]; }
		const_reference        operator[](size_type n) const { assert(size() > n); return store_[n]; }
		reference              front()                       { assert(size() > 0); return store_[0]; }
		const_reference        front()                 const { assert(size() > 0); return store_[0]; }
		reference              back()                        { assert(size() > 0); return store_[size() - 1]; }
		const_reference        back()                  const { assert(size() > 0); return store_[size() - 1]; }
		const_reference        at(size_type n)         const { check(n); return store_[n]; }
		reference              at(size_type n)               { check(n); return store_[n]; }
		pointer                data()                        { return store_; }
		const_pointer          data()                  const { return store_; }
		void                   fill(const T& v)              { fill_n(begin(), size(), v); }

	private:
		pointer   store_;
		size_type count_;
		void check(size_type n) {
			if (n >= size()) {
				throw out_of_range("std::array_view");
			}
		}
	};
}
