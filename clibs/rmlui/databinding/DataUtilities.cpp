#include <databinding/DataUtilities.h>
#include <core/Element.h>
#include <core/Text.h>
#include <core/Log.h>
#include <databinding/DataModel.h>

namespace Rml {

void DataUtilities::ApplyDataViewsControllers(Element* element) {
	DataModel* data_model = element->GetDataModel();
	if (!data_model) {
		return;
	}
	for (auto const& [name, value] : element->GetAttributes()) {
		constexpr size_t data_str_length = sizeof("data-") - 1;
		if (name.size() > data_str_length && name[0] == 'd' && name[1] == 'a' && name[2] == 't' && name[3] == 'a' && name[4] == '-') {
			element->DataModelLoad(name, value);
		}
	}
}

void DataUtilities::ApplyDataViewFor(Element* element) {
	DataModel* data_model = element->GetDataModel();
	if (!data_model) {
		return;
	}
	for (auto const& [name, value] : element->GetAttributes()) {
		if (name == "data-for") {
			element->DataModelLoad(name, value);
			return;
		}
	}
}

void DataUtilities::ApplyDataViewText(Text* element) {
	DataModel* data_model = element->GetDataModel();
	if (!data_model) {
		return;
	}
	element->DataModelLoad();
}

}
