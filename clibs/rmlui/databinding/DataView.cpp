#include <databinding/DataView.h>
#include <databinding/DataModel.h>
#include <databinding/DataVariable.h>
#include <core/Document.h>
#include <core/Element.h>
#include <core/Text.h>
#include <core/Log.h>
#include <core/StringUtilities.h>

namespace Rml {

static int GetNodeDepth(Node* e) {
	int depth = 0;
	for (Element* parent = e->GetParentNode(); parent; parent = parent->GetParentNode()) {
		depth++;
	}
	return depth;
}

DataView::DataView(Node* node)
	: depth(GetNodeDepth(node))
{ }

int DataView::GetDepth() const {
	return depth;
}

DataViewFor::DataViewFor(Element* element)
	: DataView(element)
	, element(element->GetObserverPtr())
{}

bool DataViewFor::Initialize(DataModel& model, const std::string& in_expression) {
	std::vector<std::string> iterator_container_pair;
	StringUtilities::ExpandString(iterator_container_pair, in_expression, ':');

	if (iterator_container_pair.empty() || iterator_container_pair.size() > 2 || iterator_container_pair.front().empty() || iterator_container_pair.back().empty()) {
		Log::Message(Log::Level::Warning, "Invalid syntax in data-for '%s'", in_expression.c_str());
		return false;
	}

	if (iterator_container_pair.size() == 2) {
		std::vector<std::string> iterator_index_pair;
		StringUtilities::ExpandString(iterator_index_pair, iterator_container_pair.front(), ',');
		if (iterator_index_pair.empty()) {
			Log::Message(Log::Level::Warning, "Invalid syntax in data-for '%s'", in_expression.c_str());
			return false;
		}
		else if (iterator_index_pair.size() == 1) {
			iterator_name = iterator_index_pair.front();
		}
		else if (iterator_index_pair.size() == 2) {
			iterator_name = iterator_index_pair.front();
			iterator_index_name = iterator_index_pair.back();
		}
	}

	if (iterator_name.empty())
		iterator_name = "it";
	if (iterator_index_name.empty())
		iterator_index_name = "it_index";
	const std::string& container_name = iterator_container_pair.back();
	container_address = model.ResolveAddress(container_name, element.get());
	if (container_address.empty())
		return false;
	element->SetVisible(false);
	element->RemoveAttribute("data-for");
	return true;
}

static std::string ToString(DataAddress& address) {
	std::string s;
	for (auto& entry : address) {
		if (entry.index == -1) {
			if (!s.empty()) {
				s += ".";
			}
			s += entry.name;
		}
		else {
			assert(!s.empty());
			s += "[";
			s += std::to_string(entry.index+1);
			s += "]";
		}
	}
	return s;
}

bool DataViewFor::Update(DataModel& model) {
	DataVariable variable = model.GetVariable(container_address);
	if (!variable)
		return false;

	size_t size = (size_t)variable.Size();

	for (size_t i = num_elements; i < size; ++i) {
		DataAddress iterator_address;
		iterator_address.reserve(container_address.size() + 1);
		iterator_address = container_address;
		iterator_address.push_back(DataAddressEntry((int)i));
		DataAddress iterator_index_address = {
			{"literal"}, {"int"}, {(int)i}
		};
		Node* sibling = element->Clone();
		((Element*)sibling)->DataModelSetVariable(iterator_name, ToString(iterator_address));
		((Element*)sibling)->DataModelSetVariable(iterator_index_name, std::to_string(i+1));
		model.InsertAlias(sibling, iterator_name, std::move(iterator_address));
		model.InsertAlias(sibling, iterator_index_name, std::move(iterator_index_address));
		model.MarkDirty();
		element->GetParentNode()->InsertBefore(sibling, element.get());
	}
	for (size_t i = size; i < num_elements; ++i) {
		Node* sibling = element->GetPreviousSibling();
		model.EraseAliases(sibling);
		model.MarkDirty();
		element->GetParentNode()->RemoveChild(sibling);
	}
	num_elements = size;
	return true;
}

std::vector<std::string> DataViewFor::GetVariableNameList() const {
	assert(!container_address.empty());
	return std::vector<std::string>{ container_address.front().name };
}

bool DataViewFor::IsValid() const {
	return element && !element->IsRemoved();
}

}
