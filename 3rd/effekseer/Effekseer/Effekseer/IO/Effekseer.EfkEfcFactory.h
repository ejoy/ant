#ifndef __EFFEKSEER_EFK_EFC_LOADER_H__
#define __EFFEKSEER_EFK_EFC_LOADER_H__

#include "../Effekseer.Effect.h"
#include <string>
#include <vector>

namespace Effekseer
{

/**
	@brief a factory for effect efc format
*/
class EfkEfcFactory : public EffectFactory
{
private:
public:
	bool OnLoading(Effect* effect, const void* data, int32_t size, float magnification, const char16_t* materialPath) override;

	bool OnCheckIsBinarySupported(const void* data, int32_t size) override;
};

/**
	@brief	a loader to load properties from efc format
*/
class EfkEfcProperty
{
private:
	std::vector<std::u16string> colorImages_;
	std::vector<std::u16string> normalImages_;
	std::vector<std::u16string> distortionImages_;
	std::vector<std::u16string> sounds_;
	std::vector<std::u16string> models_;
	std::vector<std::u16string> materials_;

public:
	bool Load(const void* data, int32_t size);

	const std::vector<std::u16string>& GetColorImages() const;
	const std::vector<std::u16string>& GetNormalImages() const;
	const std::vector<std::u16string>& GetDistortionImages() const;
	const std::vector<std::u16string>& GetSounds() const;
	const std::vector<std::u16string>& GetModels() const;
	const std::vector<std::u16string>& GetMaterials() const;
};

} // namespace Effekseer

#endif