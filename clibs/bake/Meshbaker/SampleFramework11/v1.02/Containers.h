//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "PCH.h"
#include "Assert_.h"

namespace SampleFramework11
{

template<typename T> class FixedArray
{

protected:

    uint64 size = 0;
    T* data = nullptr;

public:

    void Shutdown()
    {
        if(data)
        {
            delete[] data;
            data = nullptr;
        }
        size = 0;
    }

    ~FixedArray()
    {
        Shutdown();
    }

    void Init(uint64 numElements)
    {
        Shutdown();

        size = numElements;
        if(size > 0)
            data = new T[size];
    }

    void Init(uint64 numElements, T fillValue)
    {
        Init(numElements);
        Fill(fillValue);
    }

    uint64 Size() const
    {
        return size;
    }

    const T& operator[](uint64 idx) const
    {
        Assert_(idx < size);
        Assert_(data != nullptr);
        return data[idx];
    }

    T& operator[](uint64 idx)
    {
        Assert_(idx < size);
        Assert_(data != nullptr);
        return data[idx];
    }

    const T* Data() const
    {
        return data;
    }

    T* Data()
    {
        return data;
    }

    void Fill(T value)
    {
        for(uint64 i = 0; i < size; ++i)
            data[i] = value;
    }
};

template<typename T> class FixedList
{

protected:

    FixedArray<T> array;
    uint64 count = 0;

public:

    FixedList()
    {
    }

    FixedList(uint64 maxCount, uint64 initialCount = 0)
    {
        Init(maxCount, initialCount);
    }

    FixedList(uint64 maxCount, uint64 initialCount, T fillValue)
    {
        Init(maxCount, initialCount, fillValue);
    }

    void Init(uint64 maxCount, uint64 initialCount = 0)
    {
        Assert_(initialCount < maxCount);
        Assert_(maxCount > 0);
        array.Init(maxCount);
        count = initialCount;
    }

    void Init(uint64 maxCount, uint64 initialCount, T fillValue)
    {
        Init(maxCount, initialCount);
        array.Fill(fillValue);
    }

    void Shutdown()
    {
        array.Shutdown();
        count = 0;
    }

    uint64 Count() const
    {
        return count;
    }

    uint64 MaxCount() const
    {
        return array.Size();
    }

    const T& operator[](uint64 idx) const
    {
        Assert_(idx < count);
        return array[idx];
    }

    T& operator[](uint64 idx)
    {
        Assert_(idx < count);
        return array[idx];
    }

    const T* Data() const
    {
        return array.Data();
    }

    T* Data()
    {
        return array.Data();
    }

    void Fill(T value)
    {
        for(uint64 i = 0; i < count; ++i)
            array[i] = value;
    }

    uint64 Add(T item)
    {
        Assert_(count < array.Size());
        array[count] = item;
        return count++;
    }

    void AddMultiple(T item, uint64 itemCount)
    {
        if(itemCount == 0)
            return;

        Assert_(count + (itemCount - 1) < array.Size());
        for(uint64 i = 0; i < itemCount; ++i)
            array[i + count] = item;
        count += itemCount;
    }

    void Append(const T* items, uint64 itemCount)
    {
        if(itemCount == 0)
            return;

        Assert_(count + (itemCount - 1) < array.Size());
        for(uint64 i = 0; i < itemCount; ++i)
            array[i + count] = items[i];
        count += itemCount;
    }

    void Insert(T item, uint64 idx)
    {
        Assert_(count < array.Size());
        Assert_(idx <= count);
        if(idx == count)
        {
            Add(item);
            return;
        }

        for(int64 i = count; i > int64(idx); --i)
            array[i] = array[i - 1];

        array[idx] = item;
        ++count;
    }

    void Remove(uint64 idx)
    {
        Assert_(idx < count);
        for(uint64 i = idx; i < count - 1; ++i)
            array[i] = array[i + 1];
        --count;
    }

    void Remove(uint64 idx, T fillValue)
    {
        Remove(idx);
        array[count] = fillValue;
    }

    void RemoveMultiple(uint64 idx, uint64 numItems)
    {
        Assert_(idx < count);
        Assert_(idx + numItems <= count);
        for(uint64 i = idx + numItems; i < count; ++i)
            array[i - numItems] = array[i];
        count -= numItems;
    }

    void RemoveAll()
    {
        count = 0;
    }

    void RemoveAll(T fillValue)
    {
        uint64 oldCount = count;
        RemoveAll();
        for(uint64 i = 0; i < oldCount; ++i)
            array[i] = fillValue;
    }
};

}