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

#ifndef RMLUI_CORE_DATAVARIABLE_H
#define RMLUI_CORE_DATAVARIABLE_H

#include "Types.h"
#include "Traits.h"
#include "Variant.h"
#include "DataTypes.h"

namespace Rml {



/*
*   A 'DataVariable' wraps a user handle (pointer) and a VariableDefinition.
*
*   Together they can be used to get and set variables between the user side and data model side.
*/

class DataVariable {
public:
	DataVariable() {}
	DataVariable(VariableDefinition* definition, void* ptr) : definition(definition), ptr(ptr) {}

	explicit operator bool() const { return definition; }

	bool Get(Variant& variant);
	bool Set(const Variant& variant);
	int Size();
	DataVariable Child(const DataAddressEntry& address);

private:
	VariableDefinition* definition = nullptr;
	void* ptr = nullptr;
};


/*
*   A 'VariableDefinition' specifies how a user handle (pointer) is translated to and from a value in the data model.
* 
*   Generally, Scalar types can set and get values, while Array and Struct types can retrieve children based on data addresses.
*/

class VariableDefinition {
public:
	virtual ~VariableDefinition() = default;

	virtual bool Get(void* ptr, Variant& variant);
	virtual bool Set(void* ptr, const Variant& variant);

	virtual int Size(void* ptr);
	virtual DataVariable Child(void* ptr, const DataAddressEntry& address);

protected:
	VariableDefinition() {}
};

DataVariable MakeLiteralIntVariable(int value);


} // namespace Rml
#endif
