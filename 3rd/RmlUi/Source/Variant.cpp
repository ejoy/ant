/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include "../Include/RmlUi/Variant.h"
#include <string.h>

namespace Rml {

Variant::Variant() : type(NONE)
{
	// Make sure our object size assumptions fit inside the static buffer
	static_assert(sizeof(Colourb) <= LOCAL_DATA_SIZE, "Local data too small for Colourb");
	static_assert(sizeof(Colourf) <= LOCAL_DATA_SIZE, "Local data too small for Colourf");
	static_assert(sizeof(String) <= LOCAL_DATA_SIZE, "Local data too small for String");
	static_assert(sizeof(TransformPtr) <= LOCAL_DATA_SIZE, "Local data too small for TransformPtr");
	static_assert(sizeof(TransitionList) <= LOCAL_DATA_SIZE, "Local data too small for TransitionList");
	static_assert(sizeof(AnimationList) <= LOCAL_DATA_SIZE, "Local data too small for AnimationList");
}

Variant::Variant(const Variant& copy) : type(NONE)
{
	Set(copy);
}

Variant::Variant(Variant&& other) noexcept : type(NONE)
{
	Set(std::move(other));
}

Variant::~Variant() 
{
	Clear();
}

void Variant::Clear()
{
	// Free any allocated types.
	switch (type) 
	{      
		case STRING:
		{
			// Clean up the string.
			String* string = (String*)data;
			string->~String();
		}
		break;
		case TRANSFORMPTR:
		{
			// Clean up the transform.
			TransformPtr* transform = (TransformPtr*)data;
			transform->~TransformPtr();
		}
		break;
		case TRANSITIONLIST:
		{
			// Clean up the transition list.
			TransitionList* transition_list = (TransitionList*)data;
			transition_list->~TransitionList();
		}
		break;
		case ANIMATIONLIST:
		{
			// Clean up the transition list.
			AnimationList* animation_list = (AnimationList*)data;
			animation_list->~AnimationList();
		}
		break;
		default:
		break;
	}
	type = NONE;
}



//////////////////////////////////////////////////
// Set methods
//////////////////////////////////////////////////

#define SET_VARIANT(type) *((type*)data) = value;

void Variant::Set(const Variant& copy)
{
	switch (copy.type)
	{
	case STRING:
		Set(*(String*)copy.data);
		break;

	case TRANSFORMPTR:
		Set(*(TransformPtr*)copy.data);
		break;

	case TRANSITIONLIST:
		Set(*(TransitionList*)copy.data);
		break;

	case ANIMATIONLIST:
		Set(*(AnimationList*)copy.data);
		break;

	default:
		memcpy(data, copy.data, LOCAL_DATA_SIZE);
		type = copy.type;
		break;
	}
	RMLUI_ASSERT(type == copy.type);
}

void Variant::Set(Variant&& other)
{
	switch (other.type)
	{
	case STRING:
		Set(std::move(*(String*)other.data));
		break;

	case TRANSFORMPTR:
		Set(std::move(*(TransformPtr*)other.data));
		break;

	case TRANSITIONLIST:
		Set(std::move(*(TransitionList*)other.data));
		break;

	case ANIMATIONLIST:
		Set(std::move(*(AnimationList*)other.data));
		break;

	default:
		memcpy(data, other.data, LOCAL_DATA_SIZE);
		type = other.type;
		break;
	}
	RMLUI_ASSERT(type == other.type);
}

void Variant::Set(const bool value)
{
	type = BOOL;
	SET_VARIANT(bool);
}

void Variant::Set(const byte value)
{
	type = BYTE;
	SET_VARIANT(byte);
}

void Variant::Set(const char value)
{
	type = CHAR;
	SET_VARIANT(char);
}

void Variant::Set(const float value)
{
	type = FLOAT;
	SET_VARIANT(float);
}

void Variant::Set(const double value)
{
	type = DOUBLE;
	SET_VARIANT(double);
}

void Variant::Set(const int value)
{
	type = INT;
	SET_VARIANT(int);
}

void Variant::Set(const int64_t value)
{
	type = INT64;
	SET_VARIANT(int64_t);
}

void Variant::Set(const char* value) 
{
	Set(String(value));
}

void Variant::Set(void* voidptr) 
{
	type = VOIDPTR;
	memcpy(data, &voidptr, sizeof(void*));
}

void Variant::Set(const Colourf& value)
{
	type = COLOURF;
	SET_VARIANT(Colourf);
}

void Variant::Set(const Colourb& value)
{
	type = COLOURB;
	SET_VARIANT(Colourb);
}

void Variant::Set(const String& value)
{
	if (type == STRING)
	{
		(*(String*)data) = value;
	}
	else
	{
		type = STRING;
		new(data) String(value);
	}
}
void Variant::Set(String&& value)
{
	if (type == STRING)
	{
		(*(String*)data) = std::move(value);
	}
	else
	{
		type = STRING;
		new(data) String(std::move(value));
	}
}


void Variant::Set(const TransformPtr& value)
{
	if (type == TRANSFORMPTR)
	{
		SET_VARIANT(TransformPtr);
	}
	else
	{
		type = TRANSFORMPTR;
		new(data) TransformPtr(value);
	}
}
void Variant::Set(TransformPtr&& value)
{
	if (type == TRANSFORMPTR)
	{
		(*(TransformPtr*)data) = std::move(value);
	}
	else
	{
		type = TRANSFORMPTR;
		new(data) TransformPtr(std::move(value));
	}
}

void Variant::Set(const TransitionList& value)
{
	if (type == TRANSITIONLIST)
	{
		*(TransitionList*)data = value;
	}
	else
	{
		type = TRANSITIONLIST;
		new(data) TransitionList(value);
	}
}
void Variant::Set(TransitionList&& value)
{
	if (type == TRANSITIONLIST)
	{
		(*(TransitionList*)data) = std::move(value);
	}
	else
	{
		type = TRANSITIONLIST;
		new(data) TransitionList(std::move(value));
	}
}

void Variant::Set(const AnimationList& value)
{
	if (type == ANIMATIONLIST)
	{
		*(AnimationList*)data = value;
	}
	else
	{
		type = ANIMATIONLIST;
		new(data) AnimationList(value);
	}
}
void Variant::Set(AnimationList&& value)
{
	if (type == ANIMATIONLIST)
	{
		(*(AnimationList*)data) = std::move(value);
	}
	else
	{
		type = ANIMATIONLIST;
		new(data) AnimationList(std::move(value));
	}
}

Variant& Variant::operator=(const Variant& copy)
{
	if (copy.type != type)
		Clear();
	Set(copy);
	return *this;
}

Variant& Variant::operator=(Variant&& other) noexcept
{
	if (other.type != type)
		Clear();
	Set(std::move(other));
	return *this;
}

#define DEFAULT_VARIANT_COMPARE(TYPE) static_cast<TYPE>(*(TYPE*)data) == static_cast<TYPE>(*(TYPE*)other.data)

bool Variant::operator==(const Variant & other) const
{
	if (type != other.type)
		return false;

	switch (type)
	{
	case BOOL:
		return DEFAULT_VARIANT_COMPARE(bool);
	case BYTE:
		return DEFAULT_VARIANT_COMPARE(byte);
	case CHAR:
		return DEFAULT_VARIANT_COMPARE(char);
	case FLOAT:
		return DEFAULT_VARIANT_COMPARE(float);
	case DOUBLE:
		return DEFAULT_VARIANT_COMPARE(double);
	case INT:
		return DEFAULT_VARIANT_COMPARE(int);
	case INT64:
		return DEFAULT_VARIANT_COMPARE(int64_t);
	case STRING:
		return DEFAULT_VARIANT_COMPARE(String);
	case COLOURF:
		return DEFAULT_VARIANT_COMPARE(Colourf);
	case COLOURB:
		return DEFAULT_VARIANT_COMPARE(Colourb);
	case VOIDPTR:
		return DEFAULT_VARIANT_COMPARE(void*);
	case TRANSFORMPTR:
		return DEFAULT_VARIANT_COMPARE(TransformPtr);
	case TRANSITIONLIST:
		return DEFAULT_VARIANT_COMPARE(TransitionList);
	case ANIMATIONLIST:
		return DEFAULT_VARIANT_COMPARE(AnimationList);
	case NONE:
		return true;
		break;
	}
	RMLUI_ERRORMSG("Variant comparison not implemented for this type.");
	return false;
}

} // namespace Rml
