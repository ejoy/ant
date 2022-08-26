#pragma once

#include <core/Types.h>
#include <core/Interface.h>
#include <memory>
#include <string>

namespace Rml::Texture {
	void Shutdown();
	const TextureData& Fetch(const std::string& path);
}
