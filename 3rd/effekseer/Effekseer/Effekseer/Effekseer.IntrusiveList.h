
#ifndef __EFFEKSEER_INTRUSIVE_LIST_H__
#define __EFFEKSEER_INTRUSIVE_LIST_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include <assert.h>

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
/**
	@brief	Intrusive List
	@code
	class Instance : public IntrusiveList<Instance> {...};
	@endcode
*/
template <typename T>
class IntrusiveList final
{
public:
	typedef T Type;

	class Iterator
	{
		Type* m_Node = nullptr;

	public:
		Iterator() = default;
		Iterator(const Iterator& it) = default;
		Iterator(Type* node)
			: m_Node(node)
		{
		}
		Type* operator*() const
		{
			assert(m_Node != nullptr);
			return m_Node;
		}
		Type* operator->() const
		{
			assert(m_Node != nullptr);
			return m_Node;
		}
		Iterator& operator++()
		{
			assert(m_Node != nullptr);
			m_Node = m_Node->m_NextNode;
			return *this;
		}
		Iterator operator++(int)
		{
			assert(m_Node != nullptr);
			Iterator it(m_Node);
			m_Node = m_Node->m_NextNode;
			return it;
		}
		bool operator==(const Iterator& rhs) const
		{
			return m_Node == rhs.m_Node;
		}
		bool operator!=(const Iterator& rhs) const
		{
			return m_Node != rhs.m_Node;
		}
	};

	class ReverseIterator
	{
		Type* m_Node = nullptr;

	public:
		ReverseIterator() = default;
		ReverseIterator(const ReverseIterator& it) = default;
		ReverseIterator(Type* node)
			: m_Node(node)
		{
		}
		Type* operator*() const
		{
			assert(m_Node != nullptr);
			return m_Node;
		}
		Type* operator->() const
		{
			assert(m_Node != nullptr);
			return m_Node;
		}
		ReverseIterator& operator++()
		{
			assert(m_Node != nullptr);
			m_Node = m_Node->m_PrevNode;
			return *this;
		}
		ReverseIterator operator++(int)
		{
			assert(m_Node != nullptr);
			ReverseIterator it(m_Node);
			m_Node = m_Node->m_PrevNode;
			return it;
		}
		bool operator==(const ReverseIterator& rhs) const
		{
			return m_Node == rhs.m_Node;
		}
		bool operator!=(const ReverseIterator& rhs) const
		{
			return m_Node != rhs.m_Node;
		}
	};

	class Node
	{
		friend class IntrusiveList<Type>;
		friend class IntrusiveList<Type>::Iterator;

	private:
		Type* m_PrevNode = nullptr;
		Type* m_NextNode = nullptr;
	};

private:
	Type* m_HeadNode = nullptr;
	Type* m_TailNode = nullptr;
	size_t m_Count = 0;

public:
	IntrusiveList() = default;
	IntrusiveList(const IntrusiveList<T>& rhs) = delete;
	IntrusiveList<T>& operator=(const IntrusiveList<T>& rhs) = delete;
	IntrusiveList(IntrusiveList<T>&& rhs);
	IntrusiveList<T>& operator=(IntrusiveList<T>&& rhs);
	~IntrusiveList();

	void push_back(Type* newObject);
	void pop_back();
	void push_front(Type* newObject);
	void pop_front();

	Iterator insert(Iterator it, Type* newObject);
	Iterator erase(Iterator it);
	void clear();

	Type* front() const;
	Type* back() const;

	bool empty() const
	{
		return m_Count == 0;
	}
	size_t size() const
	{
		return m_Count;
	}

	Iterator begin() const
	{
		return Iterator(m_HeadNode);
	}
	Iterator end() const
	{
		return Iterator(nullptr);
	}
	ReverseIterator rbegin() const
	{
		return ReverseIterator(m_TailNode);
	}
	ReverseIterator rend() const
	{
		return ReverseIterator(nullptr);
	}
};

template <typename T>
IntrusiveList<T>::IntrusiveList(IntrusiveList<T>&& rhs)
{
	m_HeadNode = rhs.m_HeadNode;
	m_TailNode = rhs.m_TailNode;
	m_Count = rhs.m_Count;
	rhs.m_HeadNode = nullptr;
	rhs.m_TailNode = nullptr;
	rhs.m_Count = 0;
}

template <typename T>
IntrusiveList<T>& IntrusiveList<T>::operator=(IntrusiveList<T>&& rhs)
{
	m_HeadNode = rhs.m_HeadNode;
	m_TailNode = rhs.m_TailNode;
	m_Count = rhs.m_Count;
	rhs.m_HeadNode = nullptr;
	rhs.m_TailNode = nullptr;
	rhs.m_Count = 0;
}

template <typename T>
IntrusiveList<T>::~IntrusiveList()
{
	clear();
}

template <typename T>
inline void IntrusiveList<T>::push_back(typename IntrusiveList<T>::Type* newObject)
{
	assert(newObject != nullptr);
	assert(newObject->m_PrevNode == nullptr);
	assert(newObject->m_NextNode == nullptr);

	if (m_TailNode)
	{
		newObject->m_PrevNode = m_TailNode;
		m_TailNode->m_NextNode = newObject;
		m_TailNode = newObject;
	}
	else
	{
		m_HeadNode = newObject;
		m_TailNode = newObject;
	}
	m_Count++;
}

template <typename T>
inline void IntrusiveList<T>::pop_back()
{
	assert(m_TailNode != nullptr);
	if (m_TailNode)
	{
		auto prev = m_TailNode->m_PrevNode;
		m_TailNode->m_PrevNode = nullptr;
		m_TailNode->m_NextNode = nullptr;
		if (prev)
		{
			prev->m_NextNode = nullptr;
		}
		m_TailNode = prev;
		m_Count--;
	}
}

template <typename T>
inline void IntrusiveList<T>::push_front(typename IntrusiveList<T>::Type* newObject)
{
	assert(newObject != nullptr);
	assert(newObject->m_PrevNode == nullptr);
	assert(newObject->m_NextNode == nullptr);

	if (m_HeadNode)
	{
		newObject->m_NextNode = m_HeadNode;
		m_HeadNode->m_PrevNode = newObject;
		m_HeadNode = newObject;
	}
	else
	{
		m_HeadNode = newObject;
		m_TailNode = newObject;
	}
	m_Count++;
}

template <typename T>
inline void IntrusiveList<T>::pop_front()
{
	assert(m_HeadNode != nullptr);
	if (m_HeadNode)
	{
		auto next = m_HeadNode->m_NextNode;
		m_HeadNode->m_PrevNode = nullptr;
		m_HeadNode->m_NextNode = nullptr;
		if (next)
		{
			next->m_PrevNode = nullptr;
		}
		m_HeadNode = next;
		m_Count--;
	}
}

template <typename T>
inline typename IntrusiveList<T>::Iterator IntrusiveList<T>::insert(typename IntrusiveList<T>::Iterator it, Type* newObject)
{
	assert(newObject != nullptr);
	assert(newObject->m_PrevNode == nullptr);
	assert(newObject->m_NextNode == nullptr);
	auto prev = it->m_PrevNode;
	newObject->m_PrevNode = prev;
	newObject->m_NextNode = *it;
	if (prev)
	{
		prev->m_NextNode = newObject;
	}
	else
	{
		m_HeadNode = newObject;
	}
	m_Count++;
	return IntrusiveList<T>::Iterator(newObject);
}

template <typename T>
inline typename IntrusiveList<T>::Iterator IntrusiveList<T>::erase(typename IntrusiveList<T>::Iterator it)
{
	auto prev = it->m_PrevNode;
	auto next = it->m_NextNode;
	it->m_PrevNode = nullptr;
	it->m_NextNode = nullptr;
	if (prev)
		prev->m_NextNode = next;
	else
		m_HeadNode = next;
	if (next)
	{
		next->m_PrevNode = prev;
	}
	else
	{
		m_TailNode = prev;
	}
	m_Count--;
	return IntrusiveList<T>::Iterator(next);
}

template <typename T>
inline void IntrusiveList<T>::clear()
{
	for (Type* it = m_HeadNode; it != nullptr;)
	{
		Type* next = it->m_NextNode;
		it->m_PrevNode = nullptr;
		it->m_NextNode = nullptr;
		it = next;
	}
	m_HeadNode = nullptr;
	m_TailNode = nullptr;
	m_Count = 0;
}

template <typename T>
T* IntrusiveList<T>::front() const
{
	assert(m_HeadNode != nullptr);
	return m_HeadNode;
}

template <typename T>
T* IntrusiveList<T>::back() const
{
	assert(m_TailNode != nullptr);
	return m_TailNode;
}
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_INTRUSIVE_LIST_H__
