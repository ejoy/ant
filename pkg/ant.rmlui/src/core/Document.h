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

class Document {
public:
	Document(const Size& dimensions, const std::string& path);
	virtual ~Document();
	const std::string& GetSourceURL() const;
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
	void InstanceHead(const HtmlElement& html, std::function<void(const std::string&, int)> func);
	void InstanceBody(const HtmlElement& html);

private:
	StyleSheet style_sheet;
	std::deque<std::unique_ptr<Node>> removednodes;
	Element body;
	Size dimensions;
	std::string source_url;
	bool dirty_dimensions = false;
};

}
