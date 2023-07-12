#include <core/Texture.h>
#include <core/Interface.h>
#include <core/Core.h>
#include <core/Log.h>
#include <unordered_map>

namespace Rml::Texture {

using TextureMap = std::unordered_map<std::string, TextureData>;
static TextureMap textures;

void Shutdown() {
	textures.clear();
}

static TextureData InvalidTexture;

const TextureData& Fetch(Element* e, const std::string& path) {
	auto iterator = textures.find(path);
	if (iterator != textures.end()) {
		return iterator->second;
	}
	Rml::GetPlugin()->OnLoadTexture(e->GetOwnerDocument(), e, path);
	return InvalidTexture;
}

const TextureData& Fetch(Element* e, const std::string& path, Size size) {
	auto iterator = textures.find(path);
	if (iterator != textures.end()) {
		if (iterator->second.dimensions != size) {
			Rml::GetPlugin()->OnLoadTexture(e->GetOwnerDocument(), e, path, size);
		}
		return iterator->second;
	}
	Rml::GetPlugin()->OnLoadTexture(e->GetOwnerDocument(), e, path, size);
	return InvalidTexture;
}

void Set(const std::string& path, TextureData&& data) {
	textures.emplace(path, std::move(data));
}

}
