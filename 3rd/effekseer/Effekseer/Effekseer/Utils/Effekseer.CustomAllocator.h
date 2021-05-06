
#ifndef __EFFEKSEER_CUSTOM_ALLOCATOR_H__
#define __EFFEKSEER_CUSTOM_ALLOCATOR_H__

#include "../Effekseer.Base.Pre.h"
#include <list>
#include <map>
#include <memory>
#include <new>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

namespace Effekseer
{
/**
	@brief
	\~English get an allocator
	\~Japanese メモリ確保関数を取得する。
*/
MallocFunc GetMallocFunc();

/**
	\~English specify an allocator
	\~Japanese メモリ確保関数を設定する。
*/
void SetMallocFunc(MallocFunc func);

/**
	@brief
	\~English get a deallocator
	\~Japanese メモリ破棄関数を取得する。
*/
FreeFunc GetFreeFunc();

/**
	\~English specify a deallocator
	\~Japanese メモリ破棄関数を設定する。
*/
void SetFreeFunc(FreeFunc func);

/**
	@brief
	\~English get an allocator
	\~Japanese メモリ確保関数を取得する。
*/
AlignedMallocFunc GetAlignedMallocFunc();

/**
	\~English specify an allocator
	\~Japanese メモリ確保関数を設定する。
*/
void SetAlignedMallocFunc(AlignedMallocFunc func);

/**
	@brief
	\~English get a deallocator
	\~Japanese メモリ破棄関数を取得する。
*/
AlignedFreeFunc GetAlignedFreeFunc();

/**
	\~English specify a deallocator
	\~Japanese メモリ破棄関数を設定する。
*/
void SetAlignedFreeFunc(AlignedFreeFunc func);

/**
	@brief
	\~English get an allocator
	\~Japanese メモリ確保関数を取得する。
*/
MallocFunc GetMallocFunc();

/**
	\~English specify an allocator
	\~Japanese メモリ確保関数を設定する。
*/
void SetMallocFunc(MallocFunc func);

/**
	@brief
	\~English get a deallocator
	\~Japanese メモリ破棄関数を取得する。
*/
FreeFunc GetFreeFunc();

/**
	\~English specify a deallocator
	\~Japanese メモリ破棄関数を設定する。
*/
void SetFreeFunc(FreeFunc func);

template <class T>
struct CustomAllocator
{
	using value_type = T;

	CustomAllocator()
	{
	}

	template <class U>
	CustomAllocator(const CustomAllocator<U>&)
	{
	}

	T* allocate(std::size_t n)
	{
		return reinterpret_cast<T*>(GetMallocFunc()(sizeof(T) * static_cast<uint32_t>(n)));
	}
	void deallocate(T* p, std::size_t n)
	{
		GetFreeFunc()(p, sizeof(T) * static_cast<uint32_t>(n));
	}
};

template <class T>
struct CustomAlignedAllocator
{
	using value_type = T;

	CustomAlignedAllocator()
	{
	}

	template <class U>
	CustomAlignedAllocator(const CustomAlignedAllocator<U>&)
	{
	}

	T* allocate(std::size_t n)
	{
		return reinterpret_cast<T*>(GetAlignedMallocFunc()(sizeof(T) * static_cast<uint32_t>(n), 16));
	}
	void deallocate(T* p, std::size_t n)
	{
		GetAlignedFreeFunc()(p, sizeof(T) * static_cast<uint32_t>(n));
	}

	bool operator==(const CustomAlignedAllocator<T>&)
	{
		return true;
	}

	bool operator!=(const CustomAlignedAllocator<T>&)
	{
		return false;
	}
};

template <class T, class U>
bool operator==(const CustomAllocator<T>&, const CustomAllocator<U>&)
{
	return true;
}

template <class T, class U>
bool operator!=(const CustomAllocator<T>&, const CustomAllocator<U>&)
{
	return false;
}

using CustomString = std::basic_string<char16_t, std::char_traits<char16_t>, CustomAllocator<char16_t>>;
template <class T>
using CustomVector = std::vector<T, CustomAllocator<T>>;
template <class T>
using CustomAlignedVector = std::vector<T, CustomAlignedAllocator<T>>;
template <class T>
using CustomList = std::list<T, CustomAllocator<T>>;
template <class T>
using CustomSet = std::set<T, std::less<T>, CustomAllocator<T>>;
template <class T, class U>
using CustomMap = std::map<T, U, std::less<T>, CustomAllocator<std::pair<const T, U>>>;
template <class T, class U>
using CustomAlignedMap = std::map<T, U, std::less<T>, CustomAlignedAllocator<std::pair<const T, U>>>;
template <class T, class U, class Hasher = std::hash<T>, class KeyEq = std::equal_to<T>>
using CustomUnorderedMap = std::unordered_map<T, U, Hasher, KeyEq, CustomAllocator<std::pair<const T, U>>>;
template <class T, class U, class Hasher = std::hash<T>, class KeyEq = std::equal_to<T>>
using CustomAlignedUnorderedMap = std::unordered_map<T, U, Hasher, KeyEq, CustomAlignedAllocator<std::pair<const T, U>>>;

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
class StringView
{
	using Traits = std::char_traits<char16_t>;

public:
	StringView()
		: ptr_(nullptr)
		, size_(0)
	{
	}

	StringView(const char16_t* ptr)
		: ptr_(ptr)
		, size_(Traits::length(ptr))
	{
	}

	StringView(const char16_t* ptr, size_t size)
		: ptr_(ptr)
		, size_(size)
	{
	}

	template <size_t N>
	StringView(const char16_t ptr[N])
		: ptr_(ptr)
		, size_(N)
	{
	}

	StringView(const CustomString& str)
		: ptr_(str.data())
		, size_(str.size())
	{
	}

	const char16_t* data() const
	{
		return ptr_;
	}

	size_t size() const
	{
		return size_;
	}

	bool operator==(const StringView& rhs) const
	{
		return size() == rhs.size() && Traits::compare(data(), rhs.data(), size()) == 0;
	}

	bool operator!=(const StringView& rhs) const
	{
		return size() != rhs.size() || Traits::compare(data(), rhs.data(), size()) != 0;
	}

	struct Hash
	{
		size_t operator()(const StringView& key) const
		{
			constexpr size_t basis = (sizeof(size_t) == 8) ? 14695981039346656037ULL : 2166136261U;
			constexpr size_t prime = (sizeof(size_t) == 8) ? 1099511628211ULL : 16777619U;

			const uint8_t* data = reinterpret_cast<const uint8_t*>(key.data());
			size_t count = key.size() * sizeof(char16_t);
			size_t val = basis;
			for (size_t i = 0; i < count; i++)
			{
				val ^= static_cast<size_t>(data[i]);
				val *= prime;
			}
			return val;
		}
	};

private:
	const char16_t* ptr_;
	size_t size_;
};

} // namespace Effekseer

#endif // __EFFEKSEER_BASE_PRE_H__