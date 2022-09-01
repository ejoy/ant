#pragma once

#include <core/Types.h>
#include <core/Element.h>
#include <core/Interface.h>
#include <memory>
#include <string>

namespace Rml::Texture {
	void Shutdown();
	const TextureData& Fetch(Element* e, const std::string& path);
	void Set(const std::string& path, TextureData&& data);
}
