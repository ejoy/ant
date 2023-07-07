#pragma once

#include <core/Element.h>
#include <core/StyleSheet.h>
#include <unordered_map>
#include <unordered_set>
#include <memory>
#include <deque>

namespace Rml {

class Text;
class RichText;
class StyleSheet;
class DataModel;
class Factory;
struct HtmlElement;

class Document {
public:
	Document(const Size& dimensions);
	virtual ~Document();
	bool Load(const std::string& path);
	const std::string& GetSourceURL() const;
	const StyleSheet& GetStyleSheet() const;
	void LoadInlineScript(const std::string& content, int source_line);
	void LoadExternalScript(const std::string& source_path);
	void LoadInlineStyle(const std::string& content, int source_line);
	void LoadExternalStyle(const std::string& source_path);
	void SetDimensions(const Size& dimensions);
	const Size& GetDimensions();
	Element* ElementFromPoint(Point pt);
	void Flush();
	void Update(float delta);
	void UpdateLayout();
	DataModel* CreateDataModel();
	void DirtyDataModel();
	void RemoveDataModel();
	void UpdateDataModel();
	DataModel* GetDataModel() const;
	Element* GetBody();
	const Element* GetBody() const;
	Element* CreateElement(const std::string& tag);
	Text* CreateTextNode(const std::string& str);
	RichText* CreateRichTextNode(const std::string& str);
	void NotifyCustomElement(Element* e);
	void DefineCustomElement(const std::string& name);
	void Instance(const HtmlElement& html);
	void RecycleNode(std::unique_ptr<Node>&& node);

private:
	std::string source_url;
	StyleSheet style_sheet;
	std::unordered_set<std::string> custom_element;
	std::unique_ptr<DataModel> data_model;
	std::deque<std::unique_ptr<Node>> removednodes;
	Element body;
	Size dimensions;
	bool dirty_dimensions = false;
};

}
