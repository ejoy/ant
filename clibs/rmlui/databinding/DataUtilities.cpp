#include <databinding/DataUtilities.h>
#include <core/Element.h>
#include <core/Text.h>
#include <core/Log.h>
#include <databinding/DataModel.h>
#include <databinding/DataView.h>

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
			auto view = std::make_unique<DataViewFor>(element);
			if (view->Initialize(*data_model, value)) {
				data_model->AddView(std::move(view));
			}
			else {
				Log::Message(Log::Level::Warning, "Could not add data-for view to element: %s", element->GetAddress().c_str());
			}
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
