
#ifndef __EFFEKSEER_BINARY_READER_H__
#define __EFFEKSEER_BINARY_READER_H__

#include "../Effekseer.Base.h"

namespace Effekseer
{

enum class BinaryReaderStatus
{
	Reading,
	Complete,
	Failed,
};

/**
	@brief	utility for reading binary data
*/
template <bool IsValidationEnabled>
class BinaryReader
{
private:
	uint8_t* data_ = nullptr;
	size_t size_ = 0;
	size_t offset = 0;
	BinaryReaderStatus status_ = BinaryReaderStatus::Reading;

public:
	BinaryReader(uint8_t* data, size_t size)
	{
		data_ = data;
		size_ = size;
	}

	template <typename T>
	bool Read(T& value)
	{
		if (IsValidationEnabled)
		{

			if (offset + sizeof(T) > size_ || status_ == BinaryReaderStatus::Failed)
			{
				status_ = BinaryReaderStatus::Failed;
				return false;
			}
		}

		memcpy(&value, data_ + offset, sizeof(T));
		offset += sizeof(T);
		return true;
	}

	/**
@brief	read with validation
*/
	template <typename T>
	bool Read(T& value, const T& min_, const T& max_)
	{
		if (IsValidationEnabled)
		{
			if (offset + sizeof(T) > size_ || status_ == BinaryReaderStatus::Failed)
			{
				status_ = BinaryReaderStatus::Failed;
				return false;
			}
		}

		memcpy(&value, data_ + offset, sizeof(T));
		offset += sizeof(T);

		if (IsValidationEnabled)
		{
			if (value < min_ || value > max_)
			{
				status_ = BinaryReaderStatus::Failed;
				return false;
			}
		}

		return true;
	}

	/**
		@brief	read with validation
	*/
	template <typename T, typename U>
	bool Read(T& value, const U& min_, const U& max_)
	{
		if (IsValidationEnabled)
		{
			if (offset + sizeof(T) > size_ || status_ == BinaryReaderStatus::Failed)
			{
				status_ = BinaryReaderStatus::Failed;
				return false;
			}
		}

		memcpy(&value, data_ + offset, sizeof(T));
		offset += sizeof(T);

		if (IsValidationEnabled)
		{
			if (static_cast<U>(value) < min_ || static_cast<U>(value) > max_)
			{
				status_ = BinaryReaderStatus::Failed;
				return false;
			}
		}

		return true;
	}

	template <typename T>
	bool Read(T* value, int32_t count)
	{
		if (IsValidationEnabled)
		{
			if (count < 0 || offset + sizeof(T) * count > size_ || status_ == BinaryReaderStatus::Failed)
			{
				status_ = BinaryReaderStatus::Failed;
				return false;
			}
		}

		memcpy(value, data_ + offset, sizeof(T) * count);
		offset += sizeof(T) * count;
		return true;
	}

	template <typename T, typename _Alloc>
	bool Read(std::vector<T, _Alloc>& value, int32_t count)
	{
		if (IsValidationEnabled)
		{
			if (count < 0 || offset + sizeof(T) * count > size_ || status_ == BinaryReaderStatus::Failed)
			{
				status_ = BinaryReaderStatus::Failed;
				return false;
			}
		}

		value.resize(count);

		if (value.size() > 0)
		{
			memcpy(value.data(), data_ + offset, sizeof(T) * count);
		}

		offset += sizeof(T) * count;
		return true;
	}

	BinaryReaderStatus GetStatus() const
	{
		if (status_ == BinaryReaderStatus::Failed)
			return status_;

		return offset == size_ ? BinaryReaderStatus::Complete : BinaryReaderStatus::Reading;
	}

	void AddOffset(size_t length)
	{
		offset += length;
	}

	size_t GetOffset() const
	{
		return offset;
	}
};

} // namespace Effekseer

#endif // __EFFEKSEER_READER_H__
