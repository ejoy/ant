
#ifndef __EFFEKSEER_COMPILED_MATERIAL_H__
#define __EFFEKSEER_COMPILED_MATERIAL_H__

#include "Effekseer.MaterialCompiler.h"
#include <array>
#include <assert.h>
#include <map>
#include <sstream>
#include <string.h>
#include <vector>

namespace Effekseer
{

enum class CompiledMaterialPlatformType : int32_t
{
	DirectX9 = 0,
	// DirectX10 = 1,
	DirectX11 = 2,
	DirectX12 = 3,
	OpenGL = 10,
	Metal = 20,
	Vulkan = 30,
	PS4 = 40,
	Switch = 50,
	XBoxOne = 60,
};

class CompiledMaterial
{
	static const int32_t Version = 1;

	std::map<CompiledMaterialPlatformType, std::unique_ptr<CompiledMaterialBinary, ReferenceDeleter<CompiledMaterialBinary>>> platforms;
	std::vector<uint8_t> originalData_;

public:
	uint64_t GUID = 0;

	const std::vector<uint8_t>& GetOriginalData() const;

	bool Load(const uint8_t* data, int32_t size);

	void Save(std::vector<uint8_t>& dst, uint64_t guid, std::vector<uint8_t>& originalData);

	bool GetHasValue(CompiledMaterialPlatformType type) const;

	CompiledMaterialBinary* GetBinary(CompiledMaterialPlatformType type) const;

	void UpdateData(const std::vector<uint8_t>& standardVS,
					const std::vector<uint8_t>& standardPS,
					const std::vector<uint8_t>& modelVS,
					const std::vector<uint8_t>& modelPS,
					const std::vector<uint8_t>& standardRefractionVS,
					const std::vector<uint8_t>& standardRefractionPS,
					const std::vector<uint8_t>& modelRefractionVS,
					const std::vector<uint8_t>& modelRefractionPS,
					CompiledMaterialPlatformType type);
};

} // namespace Effekseer

#endif