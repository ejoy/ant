#include <core/Texture.h>
#include <core/Interface.h>
#include <core/Core.h>
#include <core/Log.h>
#include <unordered_map>

namespace Rml::Texture {

using TextureMap = std::unordered_map<std::string, TextureData>;
static TextureMap textures;

void Shutdown() {
	if (GetRenderInterface()) {
		for (auto const& [_, data] : textures) {
			GetRenderInterface()->ReleaseTexture(data.handle);
		}
	}
	textures.clear();
}

const TextureData& Fetch(const std::string& path) {
	auto iterator = textures.find(path);
	if (iterator != textures.end()) {
		return iterator->second;
	}
	auto data = GetRenderInterface()->CreateTexture(path);
	if (!data) {
		Log::Message(Log::Level::Warning, "Failed to load texture from %s.", path.c_str());
		return textures.emplace(path, TextureData{}).first->second;
	}
	return textures.emplace(path, std::move(*data)).first->second;
}

}
