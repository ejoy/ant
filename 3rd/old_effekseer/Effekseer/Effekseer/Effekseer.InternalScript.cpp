#include "Effekseer.InternalScript.h"
#include "Utils/Effekseer.BinaryReader.h"
#include <assert.h>

namespace Effekseer
{

bool InternalScript::IsValidOperator(int value) const
{
	if (0 <= value && value <= 5)
		return true;
	if (11 <= value && value <= 12)
		return true;
	if (21 <= value && value <= 22)
		return true;
	if (31 <= value && value <= 32)
		return true;
	if (50 == value)
		return true;

	return false;
}

bool InternalScript::IsValidRegister(int index) const
{
	if (index < 0)
		return false;

	if (static_cast<uint32_t>(index) < registers.size())
		return true;

	if (0x1000 + 0 <= index && index <= 0x1000 + 3)
		return true;

	if (0x1000 + 0x100 + 0 <= index && index <= 0x1000 + 0x100 + 0)
		return true;

	if (0x1000 + 0x200 + 0 <= index && index <= 0x1000 + 0x200 + 4)
		return true;

	return false;
}

float InternalScript::GetRegisterValue(int index,
									   const std::array<float, 4>& externals,
									   const std::array<float, 1>& globals,
									   const std::array<float, 5>& locals) const
{
	auto ind = static_cast<uint32_t>(index);
	if (ind < registers.size())
	{
		return registers[ind];
	}
	else if (0x1000 + 0 <= ind && ind <= 0x1000 + 3)
	{
		return externals[ind - 0x1000];
	}
	else if (0x1000 + 0x100 + 0 <= ind && ind <= 0x1000 + 0x100 + 0)
	{
		return globals[ind - 0x1000 - 0x100];
	}
	else if (0x1000 + 0x200 + 0 <= ind && ind <= 0x1000 + 0x200 + 4)
	{
		return locals[ind - 0x1000 - 0x200];
	}

	assert(false);
	return 0.0f;
}

InternalScript::InternalScript()
{
}

InternalScript ::~InternalScript()
{
}
bool InternalScript::Load(uint8_t* data, int size)
{
	if (data == nullptr || size <= 0)
		return false;
	BinaryReader<true> reader(data, static_cast<size_t>(size));

	int32_t registerCount = 0;

	reader.Read(version_);
	reader.Read(runningPhase);
	reader.Read(registerCount);
	reader.Read(operatorCount_);

	for (size_t i = 0; i < 4; i++)
		reader.Read(outputRegisters_[i]);

	if (registerCount < 0)
		return false;

	registers.resize(registerCount);

	for (size_t i = 0; i < 4; i++)
	{
		if (!IsValidRegister(outputRegisters_[i]))
		{
			return false;
		}
	}

	reader.Read(operators, static_cast<int32_t>(size - reader.GetOffset()));

	if (reader.GetStatus() == BinaryReaderStatus::Failed)
		return false;

	// check operators
	auto operatorReader = BinaryReader<true>(operators.data(), operators.size());

	for (int i = 0; i < operatorCount_; i++)
	{
		// type
		OperatorType type;
		operatorReader.Read(type);

		if (reader.GetStatus() == BinaryReaderStatus::Failed)
			return false;

		if (!IsValidOperator((int)type))
			return false;

		int32_t inputCount = 0;
		operatorReader.Read(inputCount);

		int32_t outputCount = 0;
		operatorReader.Read(outputCount);

		int32_t attributeCount = 0;
		operatorReader.Read(attributeCount);

		// input
		for (int j = 0; j < inputCount; j++)
		{
			int index = 0;
			operatorReader.Read(index);
			if (!IsValidRegister(index))
			{
				return false;
			}
		}

		// output
		for (int j = 0; j < outputCount; j++)
		{
			int index = 0;
			operatorReader.Read(index);
			if ((index < 0 || index >= static_cast<int32_t>(registers.size())))
			{
				return false;
			}
		}

		// attribute
		for (int j = 0; j < attributeCount; j++)
		{
			int index = 0;
			operatorReader.Read(index);
		}
	}

	if (operatorReader.GetStatus() != BinaryReaderStatus::Complete)
		return false;

	isValid_ = true;

	return true;
}

std::array<float, 4> InternalScript::Execute(const std::array<float, 4>& externals,
											 const std::array<float, 1>& globals,
											 const std::array<float, 5>& locals,
											 RandFuncCallback* randFuncCallback,
											 RandWithSeedFuncCallback* randSeedFuncCallback,
											 void* userData)
{
	std::array<float, 4> ret;
	ret.fill(0.0f);

	if (!isValid_)
	{
		return ret;
	}

	size_t offset = 0;
	for (int i = 0; i < operatorCount_; i++)
	{
		// type
		OperatorType type;
		memcpy(&type, operators.data() + offset, sizeof(OperatorType));
		offset += sizeof(int);

		int32_t inputCount = 0;
		memcpy(&inputCount, operators.data() + offset, sizeof(int));
		offset += sizeof(int);

		int32_t outputCount = 0;
		memcpy(&outputCount, operators.data() + offset, sizeof(int));
		offset += sizeof(int);

		int32_t attributeCount = 0;
		memcpy(&attributeCount, operators.data() + offset, sizeof(int));
		offset += sizeof(int);

		auto inputOffset = offset;
		auto outputOffset = inputOffset + inputCount * sizeof(int);
		auto attributeOffset = outputOffset + outputCount * sizeof(int);
		offset = attributeOffset + attributeCount * sizeof(int);

		std::array<float, 8> tempInputs;
		if (inputCount > tempInputs.size())
			return ret;

		for (int j = 0; j < inputCount; j++)
		{
			int index = 0;
			memcpy(&index, operators.data() + inputOffset, sizeof(int));
			inputOffset += sizeof(int);

			tempInputs[j] = GetRegisterValue(index, externals, globals, locals);
		}

		for (int j = 0; j < outputCount; j++)
		{
			int index = 0;
			memcpy(&index, operators.data() + outputOffset, sizeof(int));
			outputOffset += sizeof(int);

			if (type == OperatorType::Add)
				registers[index] = tempInputs[0] + tempInputs[1];
			else if (type == OperatorType::Sub)
				registers[index] = tempInputs[0] - tempInputs[1];
			else if (type == OperatorType::Mul)
				registers[index] = tempInputs[0] * tempInputs[1];
			else if (type == OperatorType::Div)
				registers[index] = tempInputs[0] / tempInputs[1];
			else if (type == OperatorType::Mod)
			{
				registers[index] = fmodf(tempInputs[0], tempInputs[1]);
			}
			else if (type == OperatorType::Sine)
			{
				registers[index] = sinf(tempInputs[j]);
			}
			else if (type == OperatorType::Cos)
			{
				registers[index] = cosf(tempInputs[j]);
			}
			else if (type == OperatorType::UnaryAdd)
			{
				registers[index] = tempInputs[0];
			}
			else if (type == OperatorType::UnarySub)
			{
				registers[index] = -tempInputs[0];
			}
			else if (type == OperatorType::Rand)
			{
				registers[index] = randFuncCallback(userData);
			}
			else if (type == OperatorType::Rand_WithSeed)
			{
				registers[index] = randSeedFuncCallback(userData, tempInputs[j]);
			}
			else if (type == OperatorType::Step)
			{
				auto edge = tempInputs[0];
				auto x = tempInputs[1];
				registers[index] = x >= edge ? 1.0f : 0.0f;
			}
			else if (type == OperatorType::Constant)
			{
				float att = 0;
				memcpy(&att, operators.data() + attributeOffset, sizeof(int));
				registers[index] = att;
			}
		}
	}

	for (size_t i = 0; i < 4; i++)
	{
		ret[i] = GetRegisterValue(outputRegisters_[i], externals, globals, locals);
	}

	return ret;
}

} // namespace Effekseer
