#pragma once

#include <iterator>

namespace nonstd {
	template <class T>
	class span {
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

		explicit span(pointer p, size_type c)
			: m_data(p)
			, m_size(c)
		{ }
		span(const span& d)
			: m_data(d.m_data)
			, m_size(d.m_size)
		{ }
		span(span&& d)
			: m_data(d.m_data)
			, m_size(d.m_size)
		{
			d.m_data = nullptr;
			d.m_size = 0;
		}
		~span() { }
		span& operator=(const span& d) {
			if (this != &d) {
				m_data = d.m_data;
				m_size = d.m_size;
			}
			return *this;
		}
		span& operator=(span&& d) {
			if (this != &d) {
				m_data = d.m_data;
				m_size = d.m_size;
				d.m_data = nullptr;
				d.m_size = 0;
			}
			return *this;
		}

		iterator               begin()                       { return m_data; }
		const_iterator         begin()                 const { return m_data; }
		const_iterator         cbegin()                const { return m_data; }
		iterator               end()                         { return begin() + size(); }
		const_iterator         end()                   const { return cbegin() + size(); }
		const_iterator         cend()                  const { return cbegin() + size(); }
		reverse_iterator       rbegin()                      { return reverse_iterator(end()); }
		const_reverse_iterator rbegin()                const { return reverse_iterator(cend()); }
		reverse_iterator       rend()                        { return reverse_iterator(begin()); }
		const_reverse_iterator rend()                  const { return reverse_iterator(cbegin()); }
		size_type              size()                  const { return m_size; }
		size_type              max_size()              const { return m_size; }
		bool                   empty()                 const { return size() == 0; }
		reference              operator[](size_type n)       { assert(size() > n); return m_data[n]; }
		const_reference        operator[](size_type n) const { assert(size() > n); return m_data[n]; }
		reference              front()                       { assert(size() > 0); return m_data[0]; }
		const_reference        front()                 const { assert(size() > 0); return m_data[0]; }
		reference              back()                        { assert(size() > 0); return m_data[size() - 1]; }
		const_reference        back()                  const { assert(size() > 0); return m_data[size() - 1]; }
		pointer                data()                        { return m_data; }
		const_pointer          data()                  const { return m_data; }
	protected:
		pointer   m_data;
		size_type m_size;
	};
}
