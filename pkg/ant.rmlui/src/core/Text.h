#pragma once

#include <core/Node.h>
#include <core/Geometry.h>
#include <core/Interface.h>
#include <css/PropertyIdSet.h>
#include <css/Property.h>
#include <optional>

namespace Rml {

class Text : public LayoutNode {
public:
	Text(Document* owner, const std::string& text);
	virtual ~Text();
	void SetText(const std::string& text);
	const std::string& GetText() const;
	virtual Size Measure(float minWidth, float maxWidth, float minHeight, float maxHeight);
	float GetBaseline();
	void ChangedProperties(const PropertyIdSet& properties);
protected:
	Property GetComputedProperty(PropertyId id);

	template <typename T>
	auto GetProperty(PropertyId id) {
		if constexpr(std::is_same_v<T, float>) {
			return GetComputedProperty(id).Get<PropertyFloat>().Compute(GetParentNode());
		}
		else if constexpr(std::is_enum_v<T>) {
			return GetComputedProperty(id).GetEnum<T>();
		}
		else {
			return GetComputedProperty(id).Get<T>();
		}
	}

	Node* Clone(bool deep = true) const override;
	void CalculateLayout() override;
	void Render() override;
	float GetZIndex() const override;
	Element* ElementFromPoint(Point point) override;
	std::string GetInnerHTML() const override;
	std::string GetOuterHTML() const override;
	void SetInnerHTML(const std::string& html) override;
	void SetOuterHTML(const std::string& html) override;
	const Rect& GetContentRect() const override;
	std::string text;
	LineList lines;
	void UpdateTextEffects();
	virtual void UpdateGeometry(const FontFaceHandle font_face_handle);
	void UpdateDecoration(const FontFaceHandle font_face_handle);
	bool GenerateLine(std::string& line, float& line_width, size_t line_begin, float maxiWidth, std::string& ttext, bool lastLine);
	float GetLineHeight();
	std::optional<TextShadow> GetTextShadow();
	std::optional<TextStroke> GetTextStroke();
	Style::TextDecorationLine GetTextDecorationLine();
	Color GetTextDecorationColor();
	Color GetTextColor();
	FontFaceHandle GetFontFaceHandle();

protected:
	Geometry geometry;
	Geometry decoration;
	FontFaceHandle font_handle = 0;
	enum class Dirty {
		Font,
		Effects,
		Decoration,
		Geometry,
	};
	EnumSet<Dirty> dirty;
	bool decoration_under = false;
};

class RichText final : public Text {
public:
	RichText(Document* owner, const std::string& text);
	virtual ~RichText();
	Size Measure(float minWidth, float maxWidth, float minHeight, float maxHeight) override;
protected:
	void Render() override;
	void UpdateGeometry(const FontFaceHandle font_face_handle)override;
	Node* Clone(bool deep = true) const override;
private:
	void UpdateImageMaterials();
	std::vector<Rml::group> groups;
	std::vector<Rml::image> images;
	std::vector<int> groupmap;
	std::vector<int> imagemap;
	std::vector<std::unique_ptr<Geometry>> imagegeometries;
	std::string ctext;
	int cur_image_idx = 0;
	std::vector<std::vector<Rml::layout>> layouts;
	std::vector<uint32_t> codepoints;
};

}
