#include "../Include/RmlUi/DataUtilities.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Log.h"
#include "DataController.h"
#include "DataModel.h"
#include "DataView.h"
#include "DataControllerDefault.h"
#include "DataViewDefault.h"

namespace Rml {

static std::map<std::string, DataViewInstancer*> data_view_instancers = {
	{"attr",    new DataViewInstancerDefault<DataViewAttribute>() },
	{"attrif",  new DataViewInstancerDefault<DataViewAttributeIf>() },
	{"class",   new DataViewInstancerDefault<DataViewClass>() },
	{"if",      new DataViewInstancerDefault<DataViewIf>() },
	{"visible", new DataViewInstancerDefault<DataViewVisible>() },
	{"html",    new DataViewInstancerDefault<DataViewHtml>() },
	{"style",   new DataViewInstancerDefault<DataViewStyle>() },
	{"text",    new DataViewInstancerDefault<DataViewText>() },
	{"value",   new DataViewInstancerDefault<DataViewValue>() },
};

static std::map<std::string, DataControllerInstancer*> data_controller_instancers = {
	{"event", new DataControllerInstancerDefault<DataControllerEvent>() },
};

static DataViewPtr InstanceDataView(const std::string& type_name, Element* element) {
	auto it = data_view_instancers.find(type_name);
	if (it != data_view_instancers.end())
		return it->second->InstanceView(element);
	return nullptr;
}

static DataControllerPtr InstanceDataController(Element* element, const std::string& type_name) {
	auto it = data_controller_instancers.find(type_name);
	if (it != data_controller_instancers.end())
		return it->second->InstanceController(element);
	return nullptr;
}

bool DataUtilities::Initialise() {
	return true;
}

void DataUtilities::Shutdown() {
	for (auto& [_, instancer] : data_view_instancers) {
		delete instancer;
	}
	for (auto& [_, instancer] : data_controller_instancers) {
		delete instancer;
	}
	data_controller_instancers.clear();
	data_view_instancers.clear();
}

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
			if (DataViewPtr view = InstanceDataView(type_name, element)) {
				if (view->Initialize(*data_model, element, value, modifier)) {
					data_model->AddView(std::move(view));
				}
				else {
					Log::Message(Log::Level::Warning, "Could not add data-%s view to element: %s", type_name.c_str(), element->GetAddress().c_str());
				}
				continue;
			}
			if (DataControllerPtr controller = InstanceDataController(element, type_name)) {
				if (controller->Initialize(*data_model, element, value, modifier)) {
					data_model->AddController(std::move(controller));
				}
				else {
					Log::Message(Log::Level::Warning, "Could not add data-%s controller to element: %s", type_name.c_str(), element->GetAddress().c_str());
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
			if (auto view = std::make_unique<DataViewFor>(element)) {
				if (view->Initialize(*data_model, element, value, {})) {
					data_model->AddView(std::move(view));
					return;
				}
				else {
					Log::Message(Log::Level::Warning, "Could not add data-for view to element: %s", element->GetAddress().c_str());
				}
			}
		}
	}
}

}
