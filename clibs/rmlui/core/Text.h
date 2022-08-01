#pragma once

#include <core/Node.h>
#include <core/ObserverPtr.h>
#include <core/Geometry.h>
#include <core/Interface.h>
#include <core/PropertyIdSet.h>
#include <optional>

namespace Rml {

class Text final : public Node, public EnableObserverPtr<Text> {
public:
	Text(Document* owner, const std::string& text);
	virtual ~Text();
	void SetText(const std::string& text);
	const std::string& GetText() const;
	Size Measure(float minWidth, float maxWidth, float minHeight, float maxHeight);
	float GetBaseline();
	void ChangedProperties(const PropertyIdSet& properties);

protected:
	std::optional<Property> GetComputedProperty(PropertyId id);
	template <typename T>
	T GetProperty(PropertyId id, typename std::enable_if<!std::is_enum<T>::value>::type* = 0);

	template <typename ENUM>
	ENUM GetProperty(PropertyId id, typename std::enable_if<std::is_enum<ENUM>::value>::type* = 0) {
		return (ENUM)GetProperty<int>(id);
	}

	float GetOpacity();

	void SetParentNode(Element* parent) override;
	void SetDataModel(DataModel* data_model) override;
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

private:
	void UpdateTextEffects();
	void UpdateGeometry(const FontFaceHandle font_face_handle);
	void UpdateDecoration(const FontFaceHandle font_face_handle);
	bool GenerateLine(std::string& line, int& line_length, float& line_width, int line_begin, float maximum_line_width, bool trim_whitespace_prefix);
	float GetLineHeight();
	std::optional<TextShadow> GetTextShadow();
	std::optional<TextStroke> GetTextStroke();
	Style::TextDecorationLine GetTextDecorationLine();
	Color GetTextDecorationColor();
	Color GetTextColor();
	FontFaceHandle GetFontFaceHandle();

	std::string text;
	LineList lines;
	Geometry geometry;
	Geometry decoration;
	FontFaceHandle font_handle = 0;
	bool decoration_under = true;
	bool dirty_geometry = true;
	bool dirty_decoration = true;
	bool dirty_effects = true;
	bool dirty_font = true;
};

}
