#pragma once

#include <core/Types.h>
#include <core/Interface.h>
#include <string>

namespace Rml {
	class Element;
	namespace Texture {
		enum TextureType : uint8_t{
			normal = 0,
			lattice,
			atlas,
			unknow
		};
		void Shutdown();
		TextureData* Fetch(Element* e, const std::string& path);
		TextureData* Fetch(Element* e, const std::string& path, Size size);
		void Set(const std::string& path, TextureData*&& data);
		TextureType GetType(TextureId id);
	}
}

