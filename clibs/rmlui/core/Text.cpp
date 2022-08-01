#include <core/Text.h>
#include <core/Core.h>
#include <core/Document.h>
#include <core/Interface.h>
#include <core/Log.h>
#include <core/Property.h>
#include <core/StringUtilities.h>
#include <databinding/DataModelHandle.h>
#include <databinding/DataUtilities.h>
#include <glm/gtc/matrix_transform.hpp>

namespace Rml {


static bool LastToken(const char* token_begin, const char* string_end, bool collapse_white_space, bool break_at_endline) {
	bool last_token = (token_begin == string_end);
	if (collapse_white_space && !last_token) {
		last_token = true;
		const char* character = token_begin;
		while (character != string_end) {
			if (!StringUtilities::IsWhitespace(*character) || (break_at_endline && *character == '\n')) {
				last_token = false;
				break;
			}
			character++;
		}
	}
	return last_token;
}

static bool BuildToken(std::string& token, const char*& token_begin, const char* string_end, bool first_token, bool collapse_white_space, bool break_at_endline) {
	assert(token_begin != string_end);

	token.reserve(string_end - token_begin + token.size());

	// Check what the first character of the token is; all we need to know is if it is white-space or not.
	bool parsing_white_space = StringUtilities::IsWhitespace(*token_begin);

	// Loop through the string from the token's beginning until we find an end to the token. This can occur in various
	// places, depending on the white-space processing;
	//  - at the end of a section of non-white-space characters,
	//  - at the end of a section of white-space characters, if we're not collapsing white-space,
	//  - at an endline token, if we're breaking on endlines.
	while (token_begin != string_end) {
		bool force_non_whitespace = false;
		char character = *token_begin;
		const char* escape_begin = token_begin;

		if (token_begin + 5 <= string_end
			&& token_begin[0] == '&'
			&& token_begin[1] == 'n'
			&& token_begin[2] == 'b'
			&& token_begin[3] == 's'
			&& token_begin[4] == 'p'
			&& token_begin[5] == ';'
		) {
			character = ' ';
			force_non_whitespace = true;
			token_begin += 5;
		}

		// Check for an endline token; if we're breaking on endlines and we find one, then return true to indicate a
		// forced break.
		if (break_at_endline && character == '\n') {
			token += '\n';
			token_begin++;
			return true;
		}

		// If we've transitioned from white-space characters to non-white-space characters, or vice-versa, then check
		// if should terminate the token; if we're not collapsing white-space, then yes (as sections of white-space are
		// non-breaking), otherwise only if we've transitioned from characters to white-space.
		bool white_space = !force_non_whitespace && StringUtilities::IsWhitespace(character);
		if (white_space != parsing_white_space) {
			if (!collapse_white_space) {
				// Restore pointer to the beginning of the escaped token, if we processed an escape code.
				token_begin = escape_begin;
				return false;
			}

			// We're collapsing white-space; we only tokenise words, not white-space, so we're only done tokenising
			// once we've begun parsing non-white-space and then found white-space.
			if (!parsing_white_space) {
				// However, if we are the last non-whitespace character in the string, and there are trailing
				// whitespace characters after this token, then we need to append a single space to the end of this
				// token.
				if (token_begin != string_end && LastToken(token_begin, string_end, collapse_white_space, break_at_endline))
					token += ' ';
				return false;
			}

			// We've transitioned from white-space to non-white-space, so we append a single white-space character.
			if (!first_token)
				token += ' ';
			parsing_white_space = false;
		}

		// If the current character is white-space, we'll append a space character to the token if we're not collapsing
		// sections of white-space.
		if (white_space) {
			if (!collapse_white_space)
				token += ' ';
		}
		else {
			token += character;
		}
		++token_begin;
	}
	return false;
}

Text::Text(Document* owner, const std::string& text_)
	: Node(Node::Type::Text)
	, text(text_)
{
	GetLayout().InitTextNode(this);
	DirtyLayout();
}

Text::~Text()
{ }

void Text::SetText(const std::string& _text) {
	if (text != _text) {
		text = _text;
		DirtyLayout();
	}
}

const std::string& Text::GetText() const {
	return text;
}

std::optional<Property> Text::GetComputedProperty(PropertyId id) {
	assert(parent);
	return parent->GetComputedProperty(id);
}

template <>
float Text::GetProperty<float>(PropertyId id, void* v) {
	return GetComputedProperty(id)->Get<PropertyFloat>().Compute(parent);
}

template <>
Color Text::GetProperty<Color>(PropertyId id, void* v) {
	return GetComputedProperty(id)->Get<Color>();
}

template <>
std::string Text::GetProperty<std::string>(PropertyId id, void* v) {
	return GetComputedProperty(id)->Get<std::string>();
}

template <>
int Text::GetProperty<int>(PropertyId id, void* v) {
	return GetComputedProperty(id)->Get<PropertyKeyword>();
}

float Text::GetOpacity() {
	if (!parent) {
		return 1.f;
	}
	return parent->GetOpacity();
}

void Text::Render() {
	FontFaceHandle font_face_handle = GetFontFaceHandle();
	if (font_face_handle == 0)
		return;

	UpdateTextEffects();
	UpdateGeometry(font_face_handle);
	UpdateDecoration(font_face_handle);

	parent->SetRednerStatus();

	if (decoration_under) {
		decoration.Render();
	}
	geometry.Render();
	if (!decoration_under) {
		decoration.Render();
	}
}

bool Text::GenerateLine(std::string& line, int& line_length, float& line_width, int line_begin, float maximum_line_width, bool trim_whitespace_prefix) {
	FontFaceHandle font_face_handle = GetFontFaceHandle();

	// Initialise the output variables.
	line.clear();
	line_length = 0;
	line_width = 0;

	// Bail if we don't have a valid font face.
	if (font_face_handle == 0)
		return true;

	// Determine how we are processing white-space while formatting the text.
	Style::WhiteSpace white_space_property = GetProperty<Style::WhiteSpace>(PropertyId::WhiteSpace);
	Style::WordBreak word_break = GetProperty<Style::WordBreak>(PropertyId::WordBreak);

	bool collapse_white_space = white_space_property == Style::WhiteSpace::Normal ||
								white_space_property == Style::WhiteSpace::Nowrap ||
								white_space_property == Style::WhiteSpace::Preline;
	bool break_at_line = (maximum_line_width >= 0) && 
		                   (white_space_property == Style::WhiteSpace::Normal ||
							white_space_property == Style::WhiteSpace::Prewrap ||
							white_space_property == Style::WhiteSpace::Preline);
	bool break_at_endline = white_space_property == Style::WhiteSpace::Pre ||
							white_space_property == Style::WhiteSpace::Prewrap ||
							white_space_property == Style::WhiteSpace::Preline;

	FontEngineInterface* font_engine_interface = GetFontEngineInterface();

	// Starting at the line_begin character, we generate sections of the text (we'll call them tokens) depending on the
	// white-space parsing parameters. Each section is then appended to the line if it can fit. If not, or if an
	// endline is found (and we're processing them), then the line is ended. kthxbai!
	const char* token_begin = text.c_str() + line_begin;
	const char* string_end = text.c_str() + text.size();
	while (token_begin != string_end)
	{
		std::string token;
		const char* next_token_begin = token_begin;

		// Generate the next token and determine its pixel-length.
		bool break_line = BuildToken(token, next_token_begin, string_end, line.empty() && trim_whitespace_prefix, collapse_white_space, break_at_endline);
		int token_width = font_engine_interface->GetStringWidth(font_face_handle, token);

		// If we're breaking to fit a line box, check if the token can fit on the line before we add it.
		if (break_at_line)
		{
			int max_token_width = int(maximum_line_width - line_width);

			if (token_width > max_token_width)
			{
				if (word_break == Style::WordBreak::BreakAll || (word_break == Style::WordBreak::BreakWord && line.empty()))
				{
					// Try to break up the word
					max_token_width = int(maximum_line_width - line_width);
					const int token_max_size = int(next_token_begin - token_begin);
					bool force_loop_break_after_next = false;

					// @performance: Can be made much faster. Use string width heuristics and logarithmic search.
					for (int i = token_max_size - 1; i > 0; --i)
					{
						token.clear();
						next_token_begin = token_begin;
						const char* partial_string_end = StringUtilities::SeekBackwardUTF8(token_begin + i, token_begin);
						break_line = BuildToken(token, next_token_begin, partial_string_end, line.empty() && trim_whitespace_prefix, collapse_white_space, break_at_endline);
						token_width = font_engine_interface->GetStringWidth(font_face_handle, token);

						if (force_loop_break_after_next || token_width <= max_token_width)
						{
							break;
						}
						else if (next_token_begin == token_begin)
						{
							// This means the first character of the token doesn't fit. Let it overflow into the next line if we can.
							if (!line.empty())
								return false;

							// Not even the first character of the line fits. Go back to consume the first character even though it will overflow.
							i += 2;
							force_loop_break_after_next = true;
						}
					}

					break_line = true;
				}
				else if (!line.empty())
				{
					// Let the token overflow into the next line.
					return false;
				}
			}
		}

		// The token can fit on the end of the line, so add it onto the end and increment our width and length counters.
		line += token;
		line_length += (int)(next_token_begin - token_begin);
		line_width += token_width;

		// Break out of the loop if an endline was forced.
		if (break_line)
			return false;

		// Set the beginning of the next token.
		token_begin = next_token_begin;
	}

	return true;
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
		DirtyLayout();
		dirty_decoration = true;
		dirty_effects = true;
		dirty_font = true;
		layout_changed = true;
	}

	if (changed_properties.contains(PropertyId::TextShadowH) ||
		changed_properties.contains(PropertyId::TextShadowV) ||
		changed_properties.contains(PropertyId::TextShadowColor) ||
		changed_properties.contains(PropertyId::TextStrokeWidth) ||
		changed_properties.contains(PropertyId::TextStrokeColor))
	{
		dirty_effects = true;
	}

	if (changed_properties.contains(PropertyId::LineHeight)) {
		DirtyLayout();
		dirty_decoration = true;
		layout_changed = true;
	}

	if (layout_changed) {
		return;
	}

	if (changed_properties.contains(PropertyId::TextDecorationLine)) {
		dirty_decoration = true;
	}
	if (changed_properties.contains(PropertyId::Opacity)) {
		dirty_effects = true;
	}
	if (changed_properties.contains(PropertyId::Color) || changed_properties.contains(PropertyId::Opacity)) {
		dirty_geometry = true;
		if (!dirty_decoration) {
			Color color = GetTextDecorationColor();
			color.ApplyOpacity(GetOpacity());
			for (auto& vtx : decoration.GetVertices()) {
				vtx.col = color;
			}
		}
	}
}

void Text::UpdateTextEffects() {
	if (!dirty_effects || GetFontFaceHandle() == 0)
		return;
	dirty_effects = false;

	auto shadow = GetTextShadow();
	auto stroke = GetTextStroke();
	TextEffects text_effects;
	if (shadow) {
		shadow->color.ApplyOpacity(GetOpacity());
		text_effects.emplace_back(*shadow);
	}
	if (stroke) {
		stroke->color.ApplyOpacity(GetOpacity());
		text_effects.emplace_back(*stroke);
	}
	auto material = GetRenderInterface()->CreateFontMaterial(text_effects);
	geometry.SetMaterial(material);
}

void Text::UpdateGeometry(const FontFaceHandle font_face_handle) {
	if (!dirty_geometry) {
		return;
	}
	dirty_geometry = false;
	dirty_decoration = true;
	Color color = GetTextColor();
	color.ApplyOpacity(GetOpacity());
	GetFontEngineInterface()->GenerateString(font_face_handle, lines, color, geometry);
}

void Text::UpdateDecoration(const FontFaceHandle font_face_handle) {
	if (!dirty_decoration) {
		return;
	}
	dirty_decoration = false;
	decoration.Release();
	Style::TextDecorationLine text_decoration_line = GetTextDecorationLine();
	if (text_decoration_line == Style::TextDecorationLine::None) {
		return;
	}
	Color color = GetTextDecorationColor();
	color.ApplyOpacity(GetOpacity());
	for (const Line& line : lines) {
		Point position = line.position;
		float width = (float)line.width;
		float underline_thickness = 0;
		float underline_position = 0;
		GetFontEngineInterface()->GetUnderline(font_face_handle, underline_position, underline_thickness);

		switch (text_decoration_line) {
		case Style::TextDecorationLine::Underline: {
			position.y += -underline_position;
			decoration_under = true;
			break;
		}
		case Style::TextDecorationLine::Overline: {
			int baseline = GetFontEngineInterface()->GetBaseline(font_face_handle);
			int line_height = GetFontEngineInterface()->GetLineHeight(font_face_handle);
			position.y += baseline - line_height;
			decoration_under = true;
			break;
		}
		case Style::TextDecorationLine::LineThrough: {
			int baseline = GetFontEngineInterface()->GetBaseline(font_face_handle);
			int line_height = GetFontEngineInterface()->GetLineHeight(font_face_handle);
			position.y += baseline - 0.5f * line_height;
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
	dirty_geometry = true;
	dirty_decoration = true;

	if (GetFontFaceHandle() == 0) {
		return Size(0, 0);
	}
	int line_begin = 0;
	bool finish = false;
	float line_height = GetLineHeight();
	float width = minWidth;
	float height = 0.0f;
	float first_line = true;
	float baseline = GetBaseline();

	Style::TextAlign text_align = GetProperty<Style::TextAlign>(PropertyId::TextAlign);
	std::string line;
	while (!finish && height < maxHeight) {
		float line_width;
		int line_length;
		finish = GenerateLine(line, line_length, line_width, line_begin, maxWidth, first_line);
		lines.push_back(Line { line, Point(line_width, height + baseline), 0 });
		width = std::max(width, line_width);
		height += line_height;
		first_line = false;
		line_begin += line_length;
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
	float line_height = (float)GetFontEngineInterface()->GetLineHeight(GetFontFaceHandle());
	float percent = GetProperty<float>(PropertyId::LineHeight);
	return line_height * percent;
}

float Text::GetBaseline() {
	float line_height = (float)GetFontEngineInterface()->GetLineHeight(GetFontFaceHandle());
	float percent = GetProperty<float>(PropertyId::LineHeight);
	return line_height * (1 + percent) / 2.0f - GetFontEngineInterface()->GetBaseline(GetFontFaceHandle());
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
		GetProperty<float>(PropertyId::TextStrokeWidth),
		GetProperty<Color>(PropertyId::TextStrokeColor),
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
	if (property->Has<PropertyKeyword>()) {
		// CurrentColor
		auto stroke = GetTextStroke();
		if (stroke) {
			return stroke->color;
		}
		else {
			return GetTextColor();
		}
	}
	return property->Get<Color>();
}

Color Text::GetTextColor() {
	return GetProperty<Color>(PropertyId::Color);
}

FontFaceHandle Text::GetFontFaceHandle() {
	if (!dirty_font) {
		return font_handle;
	}
	dirty_font = false;
	std::string family = StringUtilities::ToLower(GetProperty<std::string>(PropertyId::FontFamily));
	Style::FontStyle style   = GetProperty<Style::FontStyle>(PropertyId::FontStyle);
	Style::FontWeight weight = GetProperty<Style::FontWeight>(PropertyId::FontWeight);
	int size = (int)parent->GetFontSize();
	font_handle = GetFontEngineInterface()->GetFontFaceHandle(family, style, weight, size);
	if (font_handle == 0) {
		Log::Message(Log::Level::Error, "Load font %s failed.", family.c_str());
	}
	return font_handle;
}

void Text::SetParentNode(Element* _parent) {
	parent = _parent;
	if (parent) {
		SetDataModel(parent->GetDataModel());
	}
	else {
		SetDataModel(nullptr);
	}
}

void Text::SetDataModel(DataModel* new_data_model) {
	assert(!data_model || !new_data_model);
	if (data_model == new_data_model)
		return;
	data_model = new_data_model;
	if (!data_model) {
		return;
	}
	bool has_data_expression = false;
	bool inside_brackets = false;
	char previous = 0;
	for (const char c : text) {
		if (inside_brackets) {
			if (c == '}' && previous == '}') {
				has_data_expression = true;
				break;
			}
		}
		else if (c == '{' && previous == '{') {
			inside_brackets = true;
		}
		previous = c;
	}
	if (has_data_expression) {
		DataUtilities::ApplyDataViewText(this);
	}
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

}
