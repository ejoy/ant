#pragma once

#include <core/Types.h>
#include <core/Geometry.h>
#include <core/ComputedValues.h>
#include <core/TextEffect.h>
#include <glm/glm.hpp>
#include <optional>

namespace Rml {

class Node;
class Element;
class EventListener;
class Document;

using FontFaceHandle = uint64_t;
using TextureHandle = uint16_t;

struct Line {
	std::string text;
	Point position;
	int width;
};
typedef std::vector<Line> LineList;

struct TextureData {
	TextureHandle handle = UINT16_MAX;
	Size          dimensions = {0, 0};
};

class RenderInterface {
public:
	virtual void Begin() = 0;
	virtual void End() = 0;
	virtual void RenderGeometry(Vertex* vertices, size_t num_vertices, Index* indices, size_t num_indices, MaterialHandle mat) = 0;
	virtual std::optional<TextureData> CreateTexture(const std::string& path) = 0;
	virtual void ReleaseTexture(TextureHandle texture) = 0;
	virtual void SetTransform(const glm::mat4x4& transform) = 0;
	virtual void SetClipRect() = 0;
	virtual void SetClipRect(const glm::u16vec4& r) = 0;
	virtual void SetClipRect(glm::vec4 r[2]) = 0;
	virtual MaterialHandle CreateTextureMaterial(TextureHandle texture, SamplerFlag flag) = 0;
	virtual MaterialHandle CreateFontMaterial(const TextEffects& effects) = 0;
	virtual void DestroyMaterial(MaterialHandle mat) = 0;
};

class FontEngineInterface {
public:
	virtual FontFaceHandle GetFontFaceHandle(const std::string& family, Style::FontStyle style, Style::FontWeight weight, uint32_t size) = 0;
	virtual int GetLineHeight(FontFaceHandle handle) = 0;
	virtual int GetBaseline(FontFaceHandle handle) = 0;
	virtual void GetUnderline(FontFaceHandle handle, float& position, float &thickness) = 0;
	virtual int GetStringWidth(FontFaceHandle handle, const std::string& string) = 0;
	virtual void GenerateString(FontFaceHandle handle, LineList& lines, const Color& color, Geometry& geometry) = 0;
};

class Plugin {
public:
	virtual EventListener* OnCreateEventListener(Element* element, const std::string& type, const std::string& code, bool use_capture) = 0;
	virtual void OnLoadInlineScript(Document* document, const std::string& content, const std::string& source_path, int source_line) = 0;
	virtual void OnLoadExternalScript(Document* document, const std::string& source_path) = 0;
	virtual void OnCreateElement(Document* document, Element* element, const std::string& tag) = 0;
	virtual void OnDestroyNode(Document* document, Node* node) = 0;
	virtual std::string OnRealPath(const std::string& path) = 0;
};

}
