#pragma once

#include <core/Types.h>
#include <core/Geometry.h>
#include <core/ComputedValues.h>
#include <core/TextEffect.h>
#include <glm/glm.hpp>
#include <binding/luavalue.h>

namespace Rml {

class Node;
class Text;
class Element;
class Document;

using FontFaceHandle = uint64_t;
using TextureId = uint16_t;

struct layout {
    Color color;
    //uint32_t fontid;
    uint16_t num;
    uint16_t start;
};

struct group {
	Color color;
	//todo
};

struct image {
	Rml::TextureId id;
	Rect rect;
	uint16_t width;
	uint16_t height;
};

struct Line {
	std::string text;
	Point position;
	int width;
};

typedef std::vector<Line> LineList;

struct TextureData {
	struct Lattice {
		float x1, y1, x2, y2;
		float u, v;
	};

	struct Atlas {
		float ux, uy, uw, uh;
		float fx, fy, fw, fh;
	};

	TextureId handle = UINT16_MAX;
	Size      dimensions = {0, 0};
	std::variant<std::monostate, Lattice, Atlas> extra;

	explicit operator bool () const {
		return handle != UINT16_MAX;
	}
};

class Render {
public:
	virtual void Begin() = 0;
	virtual void End() = 0;
	virtual void RenderGeometry(Vertex* vertices, size_t num_vertices, Index* indices, size_t num_indices, Material* mat) = 0;
	virtual void SetTransform(const glm::mat4x4& transform) = 0;
	virtual void SetClipRect() = 0;
	virtual void SetClipRect(const glm::u16vec4& r) = 0;
	virtual void SetClipRect(glm::vec4 r[2]) = 0;
	virtual Material* CreateTextureMaterial(TextureId texture, SamplerFlag flag) = 0;
	virtual Material* CreateRenderTextureMaterial(TextureId texture, SamplerFlag flag) = 0;
	virtual Material* CreateFontMaterial(const TextEffect& effect) = 0;
	virtual Material* CreateDefaultMaterial() = 0;
	virtual void DestroyMaterial(Material* mat) = 0;

	virtual FontFaceHandle GetFontFaceHandle(const std::string& family, Style::FontStyle style, Style::FontWeight weight, uint32_t size) = 0;
	virtual void GetFontHeight(Rml::FontFaceHandle handle, int& ascent, int& descent, int& lineGap) = 0;
	virtual bool GetUnderline(FontFaceHandle handle, float& position, float &thickness) = 0;
	virtual float GetFontWidth(Rml::FontFaceHandle handle, uint32_t codepoint) = 0;
	virtual void GenerateString(Rml::FontFaceHandle handle, Rml::LineList& lines, const Rml::Color& color, Rml::Geometry& geometry) =0;
	virtual void GenerateRichString(Rml::FontFaceHandle handle, Rml::LineList& lines, std::vector<std::vector<Rml::layout>> layouts, std::vector<uint32_t>& codepoints, Rml::Geometry& textgeometry, std::vector<std::unique_ptr<Geometry>> & imagegeometries, std::vector<Rml::image>& images, int& cur_image_idx, float line_height)=0;
	virtual float PrepareText(FontFaceHandle handle,const std::string& string,std::vector<uint32_t>& codepoints,std::vector<int>& groupmap,std::vector<group>& groups,std::vector<Rml::image>& images,std::vector<layout>& line_layouts,int start,int num)=0;
};

class Script {
public:
	virtual void OnCreateElement(Document* document, Element* element, const std::string& tag) = 0;
	virtual void OnCreateText(Document* document, Text* text) = 0;
	virtual void OnDispatchEvent(Document* document, Element* element, const std::string& type, const luavalue::table& eventData) = 0;
	virtual void OnDestroyNode(Document* document, Node* node) = 0;
	virtual void OnLoadTexture(Document* document, Element* element, const std::string& path) = 0;
	virtual void OnLoadTexture(Document* document, Element* element, const std::string& path, Size size) = 0;
	virtual void OnParseText(const std::string& str,std::vector<Rml::group>& groups,std::vector<int>& groupmap,std::vector<Rml::image>& images,std::vector<int>& imageMap,std::string& ctext,Rml::group& default_group)=0;
};

}
