#pragma once

#include <databinding/DataVariant.h>
#include <databinding/DataTypes.h>

namespace Rml {

class DataVariable;

class VariableDefinition {
public:
	virtual ~VariableDefinition() = default;
	virtual bool Get(void* ptr, DataVariant& variant);
	virtual bool Set(void* ptr, const DataVariant& variant);
	virtual int Size(void* ptr);
	virtual DataVariable Child(void* ptr, const DataAddressEntry& address);

protected:
	VariableDefinition() {}
};

class DataVariable {
public:
	DataVariable() {}
	DataVariable(VariableDefinition* definition, void* ptr) : definition(definition), ptr(ptr) {}
	explicit operator bool() const { return definition; }
	bool Get(DataVariant& variant);
	bool Set(const DataVariant& variant);
	int Size();
	DataVariable Child(const DataAddressEntry& address);

private:
	VariableDefinition* definition = nullptr;
	void* ptr = nullptr;
};

DataVariable MakeLiteralIntVariable(int value);

}
