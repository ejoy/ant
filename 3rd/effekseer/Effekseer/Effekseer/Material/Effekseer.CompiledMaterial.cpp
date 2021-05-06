#include "Effekseer.CompiledMaterial.h"

namespace Effekseer
{

class CompiledMaterialBinaryInternal : public CompiledMaterialBinary, public ReferenceObject
{
private:
	std::array<std::vector<uint8_t>, static_cast<int32_t>(MaterialShaderType::Max)> vertexShaders_;

	std::array<std::vector<uint8_t>, static_cast<int32_t>(MaterialShaderType::Max)> pixelShaders_;

public:
	CompiledMaterialBinaryInternal()
	{
	}

	virtual ~CompiledMaterialBinaryInternal()
	{
	}

	void SetVertexShaderData(MaterialShaderType type, const std::vector<uint8_t>& data)
	{
		vertexShaders_.at(static_cast<size_t>(type)) = data;
	}

	void SetPixelShaderData(MaterialShaderType type, const std::vector<uint8_t>& data)
	{
		pixelShaders_.at(static_cast<size_t>(type)) = data;
	}

	const uint8_t* GetVertexShaderData(MaterialShaderType type) const override
	{
		return vertexShaders_.at(static_cast<size_t>(type)).data();
	}

	int32_t GetVertexShaderSize(MaterialShaderType type) const override
	{
		return static_cast<int32_t>(vertexShaders_.at(static_cast<size_t>(type)).size());
	}

	const uint8_t* GetPixelShaderData(MaterialShaderType type) const override
	{
		return pixelShaders_.at(static_cast<size_t>(type)).data();
	}

	int32_t GetPixelShaderSize(MaterialShaderType type) const override
	{
		return static_cast<int32_t>(pixelShaders_.at(static_cast<int>(type)).size());
	}

	int AddRef() override
	{
		return ReferenceObject::AddRef();
	}

	int Release() override
	{
		return ReferenceObject::Release();
	}

	int GetRef() override
	{
		return ReferenceObject::GetRef();
	}
};

const std::vector<uint8_t>& CompiledMaterial::GetOriginalData() const
{
	return originalData_;
}

bool CompiledMaterial::Load(const uint8_t* data, int32_t size)
{

	int offset = 0;

	// header
	char prefix[5];

	memcpy(prefix, data + offset, 4);
	offset += sizeof(int);

	prefix[4] = 0;

	if (std::string("eMCB") != std::string(prefix))
		return false;

	int version = 0;
	memcpy(&version, data + offset, 4);
	offset += sizeof(int);

	// bacause of camera position node, structure of uniform is changed, etc
	if (version < OldestSupportVersion)
	{
		return false;
	}

	// Too new
	if (version > LatestSupportVersion)
	{
		return false;
	}

	uint64_t guid = 0;
	memcpy(&guid, data + offset, 8);
	offset += sizeof(uint64_t);

	// info
	int32_t platformCount = 0;
	memcpy(&platformCount, data + offset, 4);
	offset += sizeof(uint32_t);

	offset += sizeof(uint32_t) * platformCount;

	// data
	uint32_t originalDataSize = 0;
	memcpy(&originalDataSize, data + offset, 4);
	offset += sizeof(uint32_t);

	originalData_.resize(originalDataSize);
	memcpy(originalData_.data(), data + offset, originalDataSize);

	offset += originalDataSize;

	while (0 <= offset && offset < size)
	{
		int chunk;
		memcpy(&chunk, data + offset, 4);
		offset += sizeof(int);

		int chunk_size = 0;
		memcpy(&chunk_size, data + offset, 4);
		offset += sizeof(int);

		auto binary = new CompiledMaterialBinaryInternal();

		auto loadFunc = [](const uint8_t* data, std::vector<uint8_t>& buffer, int32_t& offset) {
			int size = 0;
			memcpy(&size, data + offset, 4);
			offset += sizeof(int);

			buffer.resize(size);
			memcpy(buffer.data(), data + offset, size);
			offset += size;
		};

		std::vector<uint8_t> standardVS;
		std::vector<uint8_t> standardPS;
		std::vector<uint8_t> modelVS;
		std::vector<uint8_t> modelPS;
		std::vector<uint8_t> standardRefractionVS;
		std::vector<uint8_t> standardRefractionPS;
		std::vector<uint8_t> modelRefractionVS;
		std::vector<uint8_t> modelRefractionPS;

		loadFunc(data, standardVS, offset);
		loadFunc(data, standardPS, offset);
		loadFunc(data, modelVS, offset);
		loadFunc(data, modelPS, offset);
		loadFunc(data, standardRefractionVS, offset);
		loadFunc(data, standardRefractionPS, offset);
		loadFunc(data, modelRefractionVS, offset);
		loadFunc(data, modelRefractionPS, offset);

		binary->SetVertexShaderData(MaterialShaderType::Standard, standardVS);
		binary->SetPixelShaderData(MaterialShaderType::Standard, standardPS);
		binary->SetVertexShaderData(MaterialShaderType::Model, modelVS);
		binary->SetPixelShaderData(MaterialShaderType::Model, modelPS);
		binary->SetVertexShaderData(MaterialShaderType::Refraction, standardRefractionVS);
		binary->SetPixelShaderData(MaterialShaderType::Refraction, standardRefractionPS);
		binary->SetVertexShaderData(MaterialShaderType::RefractionModel, modelRefractionVS);
		binary->SetPixelShaderData(MaterialShaderType::RefractionModel, modelRefractionPS);

		platforms[static_cast<CompiledMaterialPlatformType>(chunk)] = CreateUniqueReference(static_cast<CompiledMaterialBinary*>(binary));
	}

	return true;
}

void CompiledMaterial::Save(std::vector<uint8_t>& dst, uint64_t guid, std::vector<uint8_t>& originalData)
{
	dst.reserve(1024 * 64);
	size_t offset = 0;

	struct Header
	{
		char header[4];
		int version = Version;
		uint64_t guid = 0;
	};

	Header h;
	h.header[0] = 'e';
	h.header[1] = 'M';
	h.header[2] = 'C';
	h.header[3] = 'B';
	h.guid = guid;

	dst.resize(sizeof(Header));
	memcpy(dst.data() + offset, &h, sizeof(Header));
	offset = dst.size();

	// info
	uint32_t platformCount = static_cast<uint32_t>(platforms.size());
	dst.resize(dst.size() + sizeof(uint32_t));
	memcpy(dst.data() + offset, &platformCount, sizeof(uint32_t));
	offset = dst.size();

	for (auto& kv : platforms)
	{
		auto platform = kv.first;
		dst.resize(dst.size() + sizeof(uint32_t));
		memcpy(dst.data() + offset, &platform, sizeof(uint32_t));
		offset = dst.size();
	}

	// data
	uint32_t originalDataSize = static_cast<uint32_t>(originalData.size());
	dst.resize(dst.size() + sizeof(uint32_t));
	memcpy(dst.data() + offset, &originalDataSize, sizeof(uint32_t));
	offset = dst.size();

	dst.resize(dst.size() + originalData.size());
	memcpy(dst.data() + offset, originalData.data(), originalData.size());
	offset = dst.size();

	// shaders
	for (auto& kv : platforms)
	{
		int32_t bodySize = 0;

		bodySize += sizeof(int) + kv.second->GetVertexShaderSize(MaterialShaderType::Standard);
		bodySize += sizeof(int) + kv.second->GetPixelShaderSize(MaterialShaderType::Standard);
		bodySize += sizeof(int) + kv.second->GetVertexShaderSize(MaterialShaderType::Model);
		bodySize += sizeof(int) + kv.second->GetPixelShaderSize(MaterialShaderType::Model);
		bodySize += sizeof(int) + kv.second->GetVertexShaderSize(MaterialShaderType::Refraction);
		bodySize += sizeof(int) + kv.second->GetPixelShaderSize(MaterialShaderType::Refraction);
		bodySize += sizeof(int) + kv.second->GetVertexShaderSize(MaterialShaderType::RefractionModel);
		bodySize += sizeof(int) + kv.second->GetPixelShaderSize(MaterialShaderType::RefractionModel);

		dst.resize(dst.size() + sizeof(int));
		memcpy(dst.data() + offset, &(kv.first), sizeof(int));
		offset = dst.size();

		dst.resize(dst.size() + sizeof(int));
		memcpy(dst.data() + offset, &(bodySize), sizeof(int));
		offset = dst.size();

		std::array<const uint8_t*, 8> bodies = {
			kv.second->GetVertexShaderData(MaterialShaderType::Standard),
			kv.second->GetPixelShaderData(MaterialShaderType::Standard),
			kv.second->GetVertexShaderData(MaterialShaderType::Model),
			kv.second->GetPixelShaderData(MaterialShaderType::Model),
			kv.second->GetVertexShaderData(MaterialShaderType::Refraction),
			kv.second->GetPixelShaderData(MaterialShaderType::Refraction),
			kv.second->GetVertexShaderData(MaterialShaderType::RefractionModel),
			kv.second->GetPixelShaderData(MaterialShaderType::RefractionModel),
		};

		std::array<int32_t, 8> bodySizes = {
			kv.second->GetVertexShaderSize(MaterialShaderType::Standard),
			kv.second->GetPixelShaderSize(MaterialShaderType::Standard),
			kv.second->GetVertexShaderSize(MaterialShaderType::Model),
			kv.second->GetPixelShaderSize(MaterialShaderType::Model),
			kv.second->GetVertexShaderSize(MaterialShaderType::Refraction),
			kv.second->GetPixelShaderSize(MaterialShaderType::Refraction),
			kv.second->GetVertexShaderSize(MaterialShaderType::RefractionModel),
			kv.second->GetPixelShaderSize(MaterialShaderType::RefractionModel),
		};

		for (size_t i = 0; i < 8; i++)
		{
			int32_t bodySize2 = bodySizes[i];

			dst.resize(dst.size() + sizeof(int));
			memcpy(dst.data() + offset, &(bodySize2), sizeof(int));
			offset = dst.size();

			dst.resize(dst.size() + bodySize2);
			memcpy(dst.data() + offset, bodies[i], bodySize2);
			offset = dst.size();
		}
	}
}

bool CompiledMaterial::GetHasValue(CompiledMaterialPlatformType type) const
{
	auto it = platforms.find(type);
	if (it == platforms.end())
		return false;

	// TODO improve it
	return it->second->GetVertexShaderSize(MaterialShaderType::Standard) > 0;
}

CompiledMaterialBinary* CompiledMaterial::GetBinary(CompiledMaterialPlatformType type) const
{

	auto it = platforms.find(type);
	if (it == platforms.end())
		return nullptr;

	return it->second.get();
}

void CompiledMaterial::UpdateData(const std::vector<uint8_t>& standardVS,
								  const std::vector<uint8_t>& standardPS,
								  const std::vector<uint8_t>& modelVS,
								  const std::vector<uint8_t>& modelPS,
								  const std::vector<uint8_t>& standardRefractionVS,
								  const std::vector<uint8_t>& standardRefractionPS,
								  const std::vector<uint8_t>& modelRefractionVS,
								  const std::vector<uint8_t>& modelRefractionPS,
								  CompiledMaterialPlatformType type)
{
	auto binary = new CompiledMaterialBinaryInternal();

	binary->SetVertexShaderData(MaterialShaderType::Standard, standardVS);
	binary->SetPixelShaderData(MaterialShaderType::Standard, standardPS);
	binary->SetVertexShaderData(MaterialShaderType::Model, modelVS);
	binary->SetPixelShaderData(MaterialShaderType::Model, modelPS);
	binary->SetVertexShaderData(MaterialShaderType::Refraction, standardRefractionVS);
	binary->SetPixelShaderData(MaterialShaderType::Refraction, standardRefractionPS);
	binary->SetVertexShaderData(MaterialShaderType::RefractionModel, modelRefractionVS);
	binary->SetPixelShaderData(MaterialShaderType::RefractionModel, modelRefractionPS);

	platforms[type] = CreateUniqueReference(static_cast<CompiledMaterialBinary*>(binary));
}

} // namespace Effekseer
