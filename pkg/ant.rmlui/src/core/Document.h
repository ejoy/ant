#pragma once

#include <core/Element.h>
#include <css/StyleSheet.h>
#include <memory>
#include <deque>

namespace Rml {

class Text;
class RichText;
class StyleSheet;
class Factory;
struct HtmlElement;

enum class HtmlHead {
	Script,
	Style,
};

class Document {
public:
	Document(const Size& dimensions);
	virtual ~Document();
	const StyleSheet& GetStyleSheet() const;
	void SetDimensions(const Size& dimensions);
	const Size& GetDimensions();
	Element* ElementFromPoint(Point pt);
	void Flush();
	void Update(float delta);
	void UpdateLayout();
	Element* GetBody();
	const Element* GetBody() const;
	Element* CreateElement(const std::string& tag);
	Text* CreateTextNode(const std::string& str);
	RichText* CreateRichTextNode(const std::string& str);
	void RecycleNode(std::unique_ptr<Node>&& node);
	void InstanceHead(const HtmlElement& html, std::function<void(HtmlHead, const std::string&, int)> func);
	void InstanceBody(const HtmlElement& html);

	void LoadStyleSheet(std::string_view source_path, std::string_view content);
	void LoadStyleSheet(std::string_view source_path, std::string_view content, int line);

private:
	StyleSheet style_sheet;
	std::deque<std::unique_ptr<Node>> removednodes;
	Element body;
	Size dimensions;
	bool dirty_dimensions = false;
};

}
