#pragma once

#include <cassert>
#include <exception>
#include <limits>
#include <iterator>

namespace std {

	class bad_array_length : public std::bad_alloc
	{
	public:
		bad_array_length() throw()
		{ }

		virtual ~bad_array_length() throw()
		{ }

		virtual const char* what() const throw()
		{ 
			return "std::bad_array_length"; 
		}
	};

	template <class T>
	class dynarray
	{
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

		dynarray();
		const dynarray operator=(const dynarray&);

		explicit dynarray(size_type c)
			: store_(alloc(c))
			, count_(c)
		{ 
			size_type i = 0;
			try {
				for (i = 0; i < count_; ++i)
				{
					new (store_+i) T;
				}
			}
			catch (...) {
				for (; i > 0; --i)
					(store_+(i-1))->~T();
				throw;
			} 
		}

		dynarray(const dynarray& d)
			: store_(alloc(d.size()))
			, count_(d.size())
		{ 
			try { 
				uninitialized_copy(d.begin(), d.end(), begin());
			}
			catch (...) {
				delete[] reinterpret_cast<char*>(store_);
				throw; 
			} 
		}

		dynarray(dynarray&& d)
			: store_(d.store_)
			, count_(d.count_)
		{
			d.store_ = nullptr;
			d.count_ = 0;
		}

		~dynarray()
		{
			for (size_type i = 0; i < size(); ++i)
			{
				(store_+i)->~T();
			}
			delete[] reinterpret_cast<char*>(store_);
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
		reference              back()                        { assert(size() > 0); return store_[size()-1]; }
		const_reference        back()                  const { assert(size() > 0); return store_[size()-1]; }
		const_reference        at(size_type n)         const { check(n); return store_[n]; }
		reference              at(size_type n)               { check(n); return store_[n]; }
		pointer                data()                        { return store_; }
		const_pointer          data()                  const { return store_; }
		void                   fill(const T& v)              { fill_n(begin(), size(), v); }

	private:
		pointer   store_;
		size_type count_;

		void check(size_type n)
		{ 
			if (n >= size())
			{
				throw out_of_range("std::dynarray"); 
			}
		}

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
