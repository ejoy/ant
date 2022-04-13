#pragma once

#include <core/ElementDocument.h>
#include <core/StyleSheet.h>
#include <unordered_map>
#include <unordered_set>
#include <memory>

namespace Rml {

class Text;
class StyleSheet;
class DataModel;
class DataModelConstructor;
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
	void Update(double delta);
	void UpdateLayout();
	DataModelConstructor CreateDataModel(const std::string& name);
	bool RemoveDataModel(const std::string& name);
	void UpdateDataModel(bool clear_dirty_variables);
	DataModel* GetDataModelPtr(const std::string& name) const;
	Element* GetBody();
	const Element* GetBody() const;
	Element* CreateElement(const std::string& tag);
	Text* CreateTextNode(const std::string& str);
	void NotifyCustomElement(Element* e);
	void DefineCustomElement(const std::string& name);
	double GetCurrentTime();
	void Instance(const HtmlElement& html);

private:
	std::string source_url;
	StyleSheet style_sheet;
	std::unordered_set<std::string> custom_element;
	std::unordered_map<std::string, std::unique_ptr<DataModel>> data_models;
	ElementDocument body;
	Size dimensions;
	double elapsed_time = 0.;
	bool dirty_dimensions = false;
};

}
