#include "../Include/RmlUi/DataUtilities.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/Log.h"
#include "DataEvent.h"
#include "DataModel.h"
#include "DataView.h"
#include "DataEvent.h"
#include "DataViewDefault.h"

namespace Rml {

void DataUtilities::ApplyDataViewsControllers(Element* element) {
	DataModel* data_model = element->GetDataModel();
	if (!data_model) {
		return;
	}
	for (auto const& [name, value] : element->GetAttributes()) {
		constexpr size_t data_str_length = sizeof("data-") - 1;
		if (name.size() > data_str_length && name[0] == 'd' && name[1] == 'a' && name[2] == 't' && name[3] == 'a' && name[4] == '-') {
			const size_t type_end = name.find('-', data_str_length);
			const size_t type_size = (type_end == std::string::npos ? std::string::npos : type_end - data_str_length);
			std::string type_name = name.substr(data_str_length, type_size);
			const size_t modifier_offset = data_str_length + type_name.size() + 1;
			std::string modifier;
			if (modifier_offset < name.size()) {
				modifier = name.substr(modifier_offset);
			}
			if (type_name == "if") {
				auto view = std::make_unique<DataViewIf>(element);
				if (view->Initialize(*data_model, value)) {
					data_model->AddView(std::move(view));
				}
				else {
					Log::Message(Log::Level::Warning, "Could not add data-%s to element: %s", type_name.c_str(), element->GetAddress().c_str());
				}
			}
			else if (type_name == "style") {
				auto view = std::make_unique<DataViewStyle>(element, modifier);
				if (view->Initialize(*data_model, value)) {
					data_model->AddView(std::move(view));
				}
				else {
					Log::Message(Log::Level::Warning, "Could not add data-%s to element: %s", type_name.c_str(), element->GetAddress().c_str());
				}
			}
			else if (type_name == "event") {
				auto event = std::make_unique<DataEvent>(element);
				if (event->Initialize(*data_model, element, value, modifier)) {
					data_model->AddEvent(std::move(event));
				}
				else {
					Log::Message(Log::Level::Warning, "Could not add data-%s to element: %s", type_name.c_str(), element->GetAddress().c_str());
				}
			}
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

void DataUtilities::ApplyDataViewText(ElementText* element) {
	DataModel* data_model = element->GetDataModel();
	if (!data_model) {
		return;
	}
	if (auto view = std::make_unique<DataViewText>(element)) {
		if (view->Initialize(*data_model)) {
			data_model->AddView(std::move(view));
		}
		else {
			Log::Message(Log::Level::Warning, "Could not add data-text view to element: %s", element->GetAddress().c_str());
		}
	}
}

}
