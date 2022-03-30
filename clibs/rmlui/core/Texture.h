#pragma once

#include <core/Types.h>
#include <memory>

namespace Rml {

using TextureHandle = uintptr_t;

struct Texture {
public:
	Texture(const std::string& path);
	~Texture();
	TextureHandle GetHandle() const;
	const Size& GetDimensions() const;
	static void Shutdown();
	static std::shared_ptr<Texture> Fetch(const std::string& path);
private:
	std::string source;
	TextureHandle handle;
	Size dimensions;
};

}
