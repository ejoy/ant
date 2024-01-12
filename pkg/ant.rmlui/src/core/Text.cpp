#include <core/Text.h>
#include <core/Document.h>
#include <core/Interface.h>
#include <binding/Context.h>
#include <binding/utf8.h>
#include <util/Log.h>
#include <glm/gtc/matrix_transform.hpp>

namespace Rml {

Text::Text(Document* owner, const std::string& text_)
	: LayoutNode(Layout::UseText {}, this)
	, text(text_)
{
	GetLayout().MarkDirty();
}

Text::~Text()
{}

void Text::SetText(const std::string& _text) {
	if (text != _text) {
		text = _text;
		GetLayout().MarkDirty();
	}
}

const std::string& Text::GetText() const {
	return text;
}

Property Text::GetComputedProperty(PropertyId id) {
	return GetParentNode()->GetComputedProperty(id);
}

void Text::Render() {
	FontFaceHandle font_face_handle = GetFontFaceHandle();
	if (font_face_handle == 0)
		return;

	UpdateTextEffects();
	UpdateGeometry(font_face_handle);
	UpdateDecoration(font_face_handle);

	if (GetParentNode()->SetRenderStatus()) {
		if (decoration_under) {
			decoration.Render();
		}
		geometry.Render();
		if (!decoration_under) {
			decoration.Render();
		}
	}
}

//static uint32_t kEllipsisCodepoint = 0x22EF;
static constexpr uint32_t kEllipsisCodepoint = 0x2026;
static constexpr auto kEllipsisString = utf8::toutf8<kEllipsisCodepoint>();

bool Text::GenerateLine(std::string& line, float& line_width, size_t line_begin, float maxWidth, std::string& ttext, bool lastLine) {
	if (lastLine) {
		if (GenerateLine(line, line_width, line_begin, maxWidth, ttext, false)) {
			return true;
		}
		line.clear();
		line_width = 0;
		float kEllipsisWidth = GetRender()->GetFontWidth(font_handle, kEllipsisCodepoint);
		if (kEllipsisWidth > maxWidth) {
			return false;
		}
		auto view = utf8::view(ttext, line_begin);
		for (auto it = view.begin(); it != view.end(); ++it) {
			auto codepoint = *it;
			float font_width = GetRender()->GetFontWidth(font_handle, codepoint);
			if (line_width + font_width + kEllipsisWidth > maxWidth) {
				line += kEllipsisString;
				line_width += kEllipsisWidth;
				return false;
			}
			line += it.value();
			line_width += font_width;
		}
		return true;
	}
	else {
		line.clear();
		line_width = 0;
		auto view = utf8::view(ttext, line_begin);
		for (auto it = view.begin(); it != view.end(); ++it) {
			auto codepoint = *it;
			float font_width = GetRender()->GetFontWidth(font_handle, codepoint);
			if (line_width + font_width > maxWidth) {
				return false;
			}
			line += it.value();
			line_width += font_width;
		}
		return true;
	}
}

void Text::CalculateLayout() {
	for (auto& line : lines) {
		line.position = line.position + GetBounds().origin;
	}
}

void Text::ChangedProperties(const PropertyIdSet& changed_properties) {
	bool layout_changed = false;

	if (changed_properties.contains(PropertyId::FontFamily) ||
		changed_properties.contains(PropertyId::FontWeight) ||
		changed_properties.contains(PropertyId::FontStyle) ||
		changed_properties.contains(PropertyId::FontSize))
	{
		GetLayout().MarkDirty();
		dirty.insert(Dirty::Decoration);
		dirty.insert(Dirty::Effects);
		dirty.insert(Dirty::Font);
		layout_changed = true;
	}

	if (changed_properties.contains(PropertyId::TextShadowH) ||
		changed_properties.contains(PropertyId::TextShadowV) ||
		changed_properties.contains(PropertyId::TextShadowColor) ||
		changed_properties.contains(PropertyId::_WebkitTextStrokeWidth) ||
		changed_properties.contains(PropertyId::_WebkitTextStrokeColor))
	{
		dirty.insert(Dirty::Effects);
	}

	if (changed_properties.contains(PropertyId::LineHeight)) {
		GetLayout().MarkDirty();
		dirty.insert(Dirty::Decoration);
		layout_changed = true;
	}

	if (layout_changed) {
		return;
	}

	if (changed_properties.contains(PropertyId::TextDecorationLine)) {
		dirty.insert(Dirty::Decoration);
	}
	if (changed_properties.contains(PropertyId::Opacity)) {
		dirty.insert(Dirty::Effects);
	}
	if (changed_properties.contains(PropertyId::Color) ||
		changed_properties.contains(PropertyId::Opacity)
	) {
		dirty.insert(Dirty::Geometry);
		if (decoration) {
			dirty.insert(Dirty::Decoration);
			Color color = GetTextDecorationColor();
			color.ApplyOpacity(GetParentNode()->GetOpacity());
			for (auto& vtx : decoration.GetVertices()) {
				vtx.col = color;
			}
		}
	}
	if (changed_properties.contains(PropertyId::Filter)) {
		dirty.insert(Dirty::Geometry);
	}
}

void Text::UpdateTextEffects() {
	if (!dirty.contains(Dirty::Effects) || GetFontFaceHandle() == 0)
		return;
	
	dirty.erase(Dirty::Effects);

	auto shadow = GetTextShadow();
	auto stroke = GetTextStroke();
	TextEffect text_effect;
	if (shadow) {
		shadow->color.ApplyOpacity(GetParentNode()->GetOpacity());
		text_effect.shadow = shadow;
	}
	if (stroke) {
		stroke->color.ApplyOpacity(GetParentNode()->GetOpacity());
		text_effect.stroke = stroke;
	}
	auto material = GetRender()->CreateFontMaterial(text_effect);
	geometry.SetMaterial(material);
}

void Text::UpdateGeometry(const FontFaceHandle font_face_handle) {
	if (!dirty.contains(Dirty::Geometry)) {
		return;
	}
	dirty.erase(Dirty::Geometry);
	Color color = GetTextColor();
	color.ApplyOpacity(GetParentNode()->GetOpacity());
	GetRender()->GenerateString(font_face_handle, lines, color, geometry);
	if (GetParentNode()->IsGray()) {
		geometry.SetGray();
	}
}

void Text::UpdateDecoration(const FontFaceHandle font_face_handle) {
	if (!dirty.contains(Dirty::Decoration)) {
		return;
	}
	dirty.erase(Dirty::Decoration);
	decoration.Release();
	Style::TextDecorationLine text_decoration_line = GetTextDecorationLine();
	if (text_decoration_line == Style::TextDecorationLine::None) {
		return;
	}
	Color color = GetTextDecorationColor();
	color.ApplyOpacity(GetParentNode()->GetOpacity());
	float underline_thickness = 0;
	float underline_position = 0;
	if (!GetRender()->GetUnderline(font_face_handle, underline_position, underline_thickness)) {
		return;
	}
	for (const Line& line : lines) {
		Point position = line.position;
		float width = (float)line.width;

		switch (text_decoration_line) {
		case Style::TextDecorationLine::Underline: {
			position.y += -underline_position;
			decoration_under = true;
			break;
		}
		case Style::TextDecorationLine::Overline: {
			int ascent, descent, lineGap;
			GetRender()->GetFontHeight(font_face_handle, ascent, descent, lineGap);
			position.y -= ascent;
			decoration_under = true;
			break;
		}
		case Style::TextDecorationLine::LineThrough: {
			int ascent, descent, lineGap;
			GetRender()->GetFontHeight(font_face_handle, ascent, descent, lineGap);
			position.y -= (ascent + descent) * 0.5f;
			decoration_under = false;
			break;
		}
		default: return;
		}

		decoration.AddRectFilled(
			{ position, { (float)width, underline_thickness } },
			color
		);
	}
}

Size Text::Measure(float minWidth, float maxWidth, float minHeight, float maxHeight) {
	lines.clear();
	dirty.insert(Dirty::Geometry);
	dirty.insert(Dirty::Decoration);

	if (GetFontFaceHandle() == 0) {
		return Size(0, 0);
	}
	size_t line_begin = 0;
	float line_height = GetLineHeight();
	float width = minWidth;
	float height = 0.f;
	float baseline = GetBaseline();

	Style::TextAlign text_align = GetProperty<Style::TextAlign>(PropertyId::TextAlign);
	Style::WordBreak word_break = GetProperty<Style::WordBreak>(PropertyId::WordBreak);

	std::string line;
	if (word_break == Style::WordBreak::Normal) {
		if (line_height < maxHeight) {
			float line_width;
			GenerateLine(line, line_width, line_begin, maxWidth, text, true);
			lines.push_back(Line { line, Point(line_width, baseline), 0 });
			width = std::max(width, line_width);
			line_begin += line.size();
			height += line_height;
		}
	}
	else {
		bool finish = false;
		while (height <= maxHeight) {
			float line_width;
			finish = GenerateLine(line, line_width, line_begin, maxWidth, text, height + line_height > maxHeight);
			lines.push_back(Line { line, Point(line_width, height + baseline), 0 });
			width = std::max(width, line_width);
			height += line_height;
			line_begin += line.size();
			if (finish) {
				break;
			}
		}
	}
	for (auto& line : lines) {
		float start_width = 0.0f;
		float line_width = line.position.x;
		float start_height = line.position.y;
		if (line_width < width) {
			switch (text_align) {
			case Style::TextAlign::Right: start_width = width - line_width; break;
			case Style::TextAlign::Center: start_width = (width - line_width) / 2.0f; break;
			default: break;
			}
		}
		line.position = Point(start_width, start_height);
	}
	height = std::max(minHeight, height);
	return Size(width, height);
}

float Text::GetLineHeight() {
	int ascent, descent, lineGap;
	GetRender()->GetFontHeight(GetFontFaceHandle(), ascent, descent, lineGap);
	auto property = GetComputedProperty(PropertyId::LineHeight);
	if (property.Has<PropertyKeyword>()) {
		return float(ascent - descent + lineGap);
	}
	float percent = property.Get<PropertyFloat>().Compute(GetParentNode());
	return (ascent - descent) * percent;
}

float Text::GetBaseline() {
	int ascent, descent, lineGap;
	GetRender()->GetFontHeight(GetFontFaceHandle(), ascent, descent, lineGap);
	auto property = GetComputedProperty(PropertyId::LineHeight);
	if (property.Has<PropertyKeyword>()) {
		return ascent + lineGap / 2.f;
	}
	float percent = property.Get<PropertyFloat>().Compute(GetParentNode());
	return ascent + (ascent - descent) * (percent-1.f) / 2.f;
}

std::optional<TextShadow> Text::GetTextShadow() {
	TextShadow shadow {
		GetProperty<float>(PropertyId::TextShadowH),
		GetProperty<float>(PropertyId::TextShadowV),
		GetProperty<Color>(PropertyId::TextShadowColor),
	};
	if (shadow.offset_h || shadow.offset_v) {
		return shadow;
	}
	return std::nullopt;
}

std::optional<TextStroke> Text::GetTextStroke() {
	TextStroke stroke{
		GetProperty<float>(PropertyId::_WebkitTextStrokeWidth),
		GetProperty<Color>(PropertyId::_WebkitTextStrokeColor),
	};
	if (stroke.width) {
		return stroke;
	}
	return std::nullopt;
}

Style::TextDecorationLine Text::GetTextDecorationLine() {
	return GetProperty<Style::TextDecorationLine>(PropertyId::TextDecorationLine);
}

Color Text::GetTextDecorationColor() {
	auto property = GetComputedProperty(PropertyId::TextDecorationColor);
	if (property.Has<PropertyKeyword>()) {
		// CurrentColor
		auto stroke = GetTextStroke();
		if (stroke) {
			return stroke->color;
		}
		else {
			return GetTextColor();
		}
	}
	return property.Get<Color>();
}

Color Text::GetTextColor() {
	return GetProperty<Color>(PropertyId::Color);
}

FontFaceHandle Text::GetFontFaceHandle() {
	if (!dirty.contains(Dirty::Font)) {
		return font_handle;
	}
	dirty.erase(Dirty::Font);
	std::string family = GetProperty<std::string>(PropertyId::FontFamily);
	Style::FontStyle style   = GetProperty<Style::FontStyle>(PropertyId::FontStyle);
	Style::FontWeight weight = GetProperty<Style::FontWeight>(PropertyId::FontWeight);
	int size = (int)GetParentNode()->GetFontSize();
	font_handle = GetRender()->GetFontFaceHandle(family, style, weight, size);
	if (font_handle == 0) {
		Log::Message(Log::Level::Error, "Load font %s failed.", family.c_str());
	}
	return font_handle;
}

Node* Text::Clone(bool deep) const {
	return GetParentNode()->GetOwnerDocument()->CreateTextNode(text);
}

float Text::GetZIndex() const {
	return 0;
}

Element* Text::ElementFromPoint(Point point) {
	return nullptr;
}

std::string Text::GetInnerHTML() const {
	return GetText();
}

std::string Text::GetOuterHTML() const {
	return GetText();
}

void Text::SetInnerHTML(const std::string& html) {
	SetText(html);
}

void Text::SetOuterHTML(const std::string& html) {
	SetText(html);
}

const Rect& Text::GetContentRect() const {
	return GetBounds();
}

/* void Text::SetRichText(bool rt){
	isRichText=rt;
} */

RichText::RichText(Document* owner, const std::string& text_)
	: Text(owner, text_)
{ }

RichText::~RichText()
{ }

Size RichText::Measure(float minWidth, float maxWidth, float minHeight, float maxHeight) {
	lines.clear();
	dirty.insert(Dirty::Geometry);
	dirty.insert(Dirty::Decoration);
	if (GetFontFaceHandle() == 0) {
		return Size(0, 0);
	}
	size_t line_begin = 0;
	bool finish = false;
	float line_height = GetLineHeight();
	float width = minWidth;
	float height = 0.0f;
	float baseline = GetBaseline();
	
	Style::TextAlign text_align = GetProperty<Style::TextAlign>(PropertyId::TextAlign);
	Style::WordBreak word_break = GetProperty<Style::WordBreak>(PropertyId::WordBreak);

	groups.clear();
	groupmap.clear();
	codepoints.clear();
	ctext.clear();
	images.clear();
	imagemap.clear();
	imagegeometries.clear();
	layouts.clear();
	//richtext
	Color default_color = GetTextColor();
	group default_group;
	default_group.color = default_color;
	GetScript()->OnParseText(text, groups, groupmap, images, imagemap, ctext, default_group);
	imagegeometries.reserve(images.size());
  	for (size_t i = 0 ; i < images.size(); ++i){
		std::unique_ptr<Rml::Geometry> ug(new Rml::Geometry());
		imagegeometries.emplace_back(std::move(ug));
	}  
	std::string line;
	std::vector<Rml::layout> line_layouts;
	codepoints.clear();
	cur_image_idx = 0;
	while (!finish && height < maxHeight) {
		float line_width;
		finish = GenerateLine(line, line_width, line_begin, maxWidth, ctext, false);
		//richtext
		line_layouts.clear();
		line_width=GetRender()->PrepareText(GetFontFaceHandle(),line,codepoints,groupmap,groups,images,line_layouts,(int)line_begin,(int)line.size());

		lines.push_back(Line { line, Point(line_width, height + baseline), 0 });
		layouts.push_back(line_layouts);
		width = std::max(width, line_width);
		height += line_height;
		line_begin += line.size();
		if (word_break == Style::WordBreak::Normal) {
			break;
		}
	}
	for (auto& line : lines) {
		float start_width = 0.0f;
		float line_width = line.position.x;
		float start_height = line.position.y;
		if (line_width < width) {
			switch (text_align) {
			case Style::TextAlign::Right: start_width = width - line_width; break;
			case Style::TextAlign::Center: start_width = (width - line_width) / 2.0f; break;
			default: break;
			}
		}
		line.position = Point(start_width, start_height);
	}
	height = std::max(minHeight, height);
	return Size(width, height);
}

void RichText::UpdateGeometry(const FontFaceHandle font_face_handle) {
	if (!dirty.contains(Dirty::Geometry)) {
		return;
	}
	dirty.erase(Dirty::Geometry);
	cur_image_idx = 0;
	float line_height = GetLineHeight();
	GetRender()->GenerateRichString(font_face_handle, lines, layouts, codepoints, geometry, imagegeometries, images, cur_image_idx, line_height);
	if (GetParentNode()->IsGray()) {
		geometry.SetGray();
	}
}

void RichText::UpdateImageMaterials() {
	for(size_t i = 0; i < images.size(); ++i){
		Rml::TextureId& id = images[i].id;
		auto material = GetRender()->CreateTextureMaterial(id, Rml::SamplerFlag::Repeat);
		imagegeometries[i]->SetMaterial(material);
	}
}

void RichText::Render() {
	FontFaceHandle font_face_handle = GetFontFaceHandle();
	if (font_face_handle == 0)
		return;
	UpdateTextEffects();
	UpdateImageMaterials();
	UpdateDecoration(font_face_handle);
	UpdateGeometry(font_face_handle);
	if (GetParentNode()->SetRenderStatus()) {
		if (decoration_under) {
			decoration.Render();
		}
		geometry.Render();
		for(size_t i = 0; i < images.size(); ++i){
			imagegeometries[i]->Render();
		}
			if (!decoration_under) {
			decoration.Render();
		}
	}
}

Node* RichText::Clone(bool deep) const {
	return GetParentNode()->GetOwnerDocument()->CreateRichTextNode(text);
}

}

