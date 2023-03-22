#pragma once

#include <core/Types.h>
#include <core/Element.h>
#include <core/Interface.h>
#include <memory>
#include <string>

namespace Rml::Texture {
	void Shutdown();
	const TextureData& Fetch(Element* e, const std::string& path);
	const TextureData& Fetch(Element* e, const std::string& path, Size size);
	void Set(const std::string& path, TextureData&& data);
}
