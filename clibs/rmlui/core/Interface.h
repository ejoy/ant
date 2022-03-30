#pragma once

#include <core/Types.h>
#include <core/Texture.h>
#include <core/Geometry.h>
#include <core/ComputedValues.h>
#include <core/TextEffect.h>
#include <core/StringUtilities.h>
#include <glm/glm.hpp>

namespace Rml {

class Element;
class EventListener;
class Document;

using FileHandle = uintptr_t;
using FontFaceHandle = uintptr_t;
using TextEffectsHandle = uintptr_t;

struct Line {
	std::string text;
	Point position;
	int width;
};
typedef std::vector<Line> LineList;

class RenderInterface {
public:
	virtual void RenderGeometry(Vertex* vertices, size_t num_vertices, Index* indices, size_t num_indices, TextureHandle texture, SamplerFlag flags) = 0;
	virtual bool LoadTexture(TextureHandle& handle, Size& dimensions, const std::string& path) = 0;
	virtual void ReleaseTexture(TextureHandle texture) = 0;
	virtual void SetTransform(const glm::mat4x4& transform) = 0;
	virtual void SetClipRect() = 0;
	virtual void SetClipRect(const glm::u16vec4& r) = 0;
	virtual void SetClipRect(glm::vec4 r[2]) = 0;
};

class FontEngineInterface {
public:
	virtual FontFaceHandle GetFontFaceHandle(const std::string& family, Style::FontStyle style, Style::FontWeight weight, int size) = 0;
	virtual TextEffectsHandle PrepareTextEffects(FontFaceHandle handle, const TextEffects &effects) = 0;
	virtual int GetSize(FontFaceHandle handle) = 0;
	virtual int GetXHeight(FontFaceHandle handle) = 0;
	virtual int GetLineHeight(FontFaceHandle handle) = 0;
	virtual int GetBaseline(FontFaceHandle handle) = 0;
	virtual void GetUnderline(FontFaceHandle handle, float& position, float &thickness) = 0;
	virtual int GetStringWidth(FontFaceHandle handle, const std::string& string, Character prior_character = Character::Null) = 0;
	virtual void GenerateString(FontFaceHandle face_handle, TextEffectsHandle text_effects_handle, LineList& lines, const Color& colour, Geometry& geometry) = 0;
};

class FileInterface {
public:
	virtual FileHandle Open(const std::string& path) = 0;
	virtual void Close(FileHandle file) = 0;
	virtual size_t Read(void* buffer, size_t size, FileHandle file) = 0;
	virtual size_t Length(FileHandle file) = 0;
	virtual std::string GetPath(const std::string& path) = 0;
};

class Plugin {
public:
	virtual EventListener* OnCreateEventListener(Element* element, const std::string& type, const std::string& code, bool use_capture) = 0;
	virtual void OnLoadInlineScript(Document* document, const std::string& content, const std::string& source_path, int source_line) = 0;
	virtual void OnLoadExternalScript(Document* document, const std::string& source_path) = 0;
	virtual void OnCreateElement(Document* document, Element* element, const std::string& tag) = 0;
};

}
