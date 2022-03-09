#pragma once

#include "ElementDocument.h"

namespace Rml {

class ElementText;
class StyleSheet;
class DataModel;
class DataModelConstructor;
class Factory;

class Document {
public:
	Document(const Size& dimensions);
	virtual ~Document();
	bool Load(const std::string& path);
	const std::string& GetSourceURL() const;
	void SetStyleSheet(std::shared_ptr<StyleSheet> style_sheet);
	const std::shared_ptr<StyleSheet>& GetStyleSheet() const;
	virtual void LoadInlineScript(const std::string& content, const std::string& source_path, int source_line);
	virtual void LoadExternalScript(const std::string& source_path);
	void SetDimensions(const Size& dimensions);
	const Size& GetDimensions();
	Element* ElementFromPoint(Point pt);
	void Update();

	DataModelConstructor CreateDataModel(const std::string& name);
	DataModelConstructor GetDataModel(const std::string& name);
	bool RemoveDataModel(const std::string& name);
	void UpdateDataModel(bool clear_dirty_variables);
	DataModel* GetDataModelPtr(const std::string& name) const;

	Element* GetBody();
	const Element* GetBody() const;

private:
	using DataModels = std::unordered_map<std::string, std::unique_ptr<DataModel>>;

	ElementDocument body;
	DataModels data_models;
	std::string source_url;
	std::shared_ptr<StyleSheet> style_sheet;
	Size dimensions;
	bool dirty_dimensions = false;
};

}
