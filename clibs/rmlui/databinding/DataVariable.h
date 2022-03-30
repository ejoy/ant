#pragma once

#include <core/Variant.h>
#include <databinding/DataTypes.h>

namespace Rml {

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

}
