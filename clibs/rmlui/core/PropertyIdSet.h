#pragma once

#include <core/ID.h>
#include <bitset>
#include <assert.h>

namespace Rml {

template <typename T, std::size_t N>
class enumset: public std::bitset<N> {
public:
	using mybase = std::bitset<N>;

	class const_iterator {
	public:
		using iterator_category = std::forward_iterator_tag;
		explicit const_iterator(const mybase& bitset)
			: index{ static_cast<std::size_t>(-1) }
			, bitset{ bitset }
		{}
		const_iterator operator++() {
			seek_next();
			return *this;
		}
		const_iterator operator++(int) {
			const_iterator prev_this = *this;
			seek_next();
			return prev_this;
		}
		T operator*() const { return static_cast<T>(index); }
		bool operator==(const const_iterator& rhs) const {
			return (index == rhs.index) && (bitset == rhs.bitset);
		}
		bool operator!=(const const_iterator& rhs) const {
			return !operator==(rhs);
		}
		friend const_iterator enumset::begin() const;
		friend const_iterator enumset::end() const;
	protected:
		std::size_t index;
	private:
		void seek_next() {
			while (++(index) < N) {
				if (bitset[index] == true) {
					break;
				}
			}
		}
		const mybase& bitset;
	};

	void insert(T v) {
		assert(size_t(v) < N);
		mybase::set((size_t)v);
	}

	void clear() {
		mybase::reset();
	}

	void erase(T v) {
		assert(size_t(v) < N);
		mybase::reset((size_t)v);
	}

	bool empty() const {
		return mybase::none();
	}
	bool contains(T v) const {
		return mybase::test((size_t)v);
	}

	size_t size() const {
		return mybase::count();
	}

	enumset operator&(const enumset& other) const {
		mybase result = (const mybase&)(*this) & (const mybase&)other;
		return enumset(result);
	}

    const_iterator begin() const {
        const_iterator iterator{ *this };
        iterator.seek_next();
        return iterator;
    }

    const_iterator end() const {
        const_iterator iterator{ *this };
        iterator.index = N;
        return iterator;
    }
};

using PropertyIdSet = enumset<PropertyId, size_t(PropertyId::NumDefinedIds)>;

}
