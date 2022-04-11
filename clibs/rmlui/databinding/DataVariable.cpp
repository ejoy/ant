#include <databinding/DataVariable.h>
#include <core/Log.h>

namespace Rml {

bool DataVariable::Get(Variant& variant) {
    return definition->Get(ptr, variant);
}

bool DataVariable::Set(const Variant& variant) {
    return definition->Set(ptr, variant);
}

int DataVariable::Size() {
    return definition->Size(ptr);
}

DataVariable DataVariable::Child(const DataAddressEntry& address) {
    return definition->Child(ptr, address);
}

bool VariableDefinition::Get(void* /*ptr*/, Variant& /*variant*/) {
    Log::Message(Log::Level::Warning, "Values can only be retrieved from scalar data types.");
    return false;
}
bool VariableDefinition::Set(void* /*ptr*/, const Variant& /*variant*/) {
    Log::Message(Log::Level::Warning, "Values can only be assigned to scalar data types.");
    return false;
}
int VariableDefinition::Size(void* /*ptr*/) {
    Log::Message(Log::Level::Warning, "Tried to get the size from a non-array data type.");
    return 0;
}
DataVariable VariableDefinition::Child(void* /*ptr*/, const DataAddressEntry& /*address*/) {
    Log::Message(Log::Level::Warning, "Tried to get the child of a scalar type.");
    return DataVariable();
}

class LiteralIntDefinition final : public VariableDefinition {
public:
    LiteralIntDefinition() : VariableDefinition() {}

    bool Get(void* ptr, Variant& variant) override
    {
        variant = static_cast<int>(reinterpret_cast<intptr_t>(ptr));
        return true;
    }
};

DataVariable MakeLiteralIntVariable(int value)
{
    static LiteralIntDefinition literal_int_definition;
    return DataVariable(&literal_int_definition, reinterpret_cast<void*>(static_cast<intptr_t>(value)));
}

}
