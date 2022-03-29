#pragma once

#include "Element.h"
#include "Geometry.h"
#include "FontEngineInterface.h"
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

protected:
	const Property* GetComputedProperty(PropertyId id);
	float GetOpacity();

	void SetParentNode(Element* parent) override;
	void SetDataModel(DataModel* data_model) override;
	Node* Clone(bool deep = true) const override;
	void CalculateLayout() override;
	void Render() override;
	void OnChange(const PropertyIdSet& properties) override;
	float GetZIndex() const override;
	Element* ElementFromPoint(Point point) override;
	std::string GetInnerHTML() const override;
	std::string GetOuterHTML() const override;
	void SetInnerHTML(const std::string& html) override;
	void SetOuterHTML(const std::string& html) override;

private:
	void UpdateTextEffects();
	void UpdateGeometry(const FontFaceHandle font_face_handle);
	void UpdateDecoration(const FontFaceHandle font_face_handle);

	bool GenerateLine(std::string& line, int& line_length, float& line_width, int line_begin, float maximum_line_width, bool trim_whitespace_prefix);
	void ClearLines();
	void AddLine(const std::string& line, Point position);

	float GetLineHeight();
	Style::TextAlign GetAlign();
	std::optional<TextShadow> GetTextShadow();
	std::optional<TextStroke> GetTextStroke();
	Style::TextDecorationLine GetTextDecorationLine();
	Color GetTextDecorationColor();
	Style::TextTransform GetTextTransform();
	Style::WhiteSpace GetWhiteSpace();
	Style::WordBreak GetWordBreak();
	Color GetTextColor();
	FontFaceHandle GetFontFaceHandle();

	bool dirty_geometry = true;
	bool dirty_decoration = true;
	bool dirty_effects = false;
	bool dirty_font = false;

	std::string text;
	LineList lines;
	Geometry geometry;
	Geometry decoration;
	bool decoration_under = true;
	TextEffectsHandle text_effects_handle = 0;
	FontFaceHandle font_handle = 0;
};

}
