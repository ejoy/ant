#pragma once

#include <databinding/DataTypes.h>
#include <databinding/DataVariable.h>
#include <string>
#include <unordered_map>
#include <unordered_set>

namespace Rml {

class Element;
class Node;

class DataView;
using DataViewPtr = std::unique_ptr<DataView>;
class DataEvent;
using DataEventPtr = std::unique_ptr<DataEvent>;

class DataModel {
public:
	DataModel();
	~DataModel();

	DataModel(const DataModel&) = delete;
	DataModel& operator=(const DataModel&) = delete;

	void AddView(DataViewPtr view);
	void AddEvent(DataEventPtr event);

	bool BindVariable(const std::string& name, DataVariable variable);
	bool BindEventCallback(const std::string& name, DataEventFunc event_func);

	bool InsertAlias(Node* element, const std::string& alias_name, DataAddress replace_with_address);
	bool EraseAliases(Node* element);

	DataAddress ResolveAddress(const std::string& address_str, Node* element) const;
	const DataEventFunc* GetEventCallback(const std::string& name);

	DataVariable GetVariable(const DataAddress& address) const;
	bool GetVariableInto(const DataAddress& address, Variant& out_value) const;

	void DirtyVariable(const std::string& variable_name);
	bool IsVariableDirty(const std::string& variable_name) const;

	// Elements declaring 'data-model' need to be attached.
	void AttachModelRootElement(Element* element);
	std::vector<Element*> GetAttachedModelRootElements() const;

	void OnElementRemove(Element* element);

	void Update(bool clear_dirty_variables);

private:
	using DataViewList = std::vector<DataViewPtr>;
	using NameViewMap = std::unordered_multimap<std::string, DataView*>;
	DataViewList views;
	DataViewList views_to_add;
	NameViewMap name_view_map;

    std::unordered_multimap<Element*, DataEventPtr> events;
	std::unordered_map<std::string, DataVariable> variables;
	DirtyVariables dirty_variables;
	std::unordered_map<std::string, DataEventFunc> event_callbacks;
	using ScopedAliases = std::unordered_map<Node*, std::unordered_map<std::string, DataAddress>>;
	ScopedAliases aliases;
	std::unordered_set<Element*> attached_elements;
};

}
