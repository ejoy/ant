#include "../Include/RmlUi/DataUtilities.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Log.h"
#include "DataController.h"
#include "DataModel.h"
#include "DataView.h"
#include "DataControllerDefault.h"
#include "DataViewDefault.h"
#include "HtmlParser.h"

namespace Rml {

using DataViewInstancerMap = std::unordered_map< std::string, DataViewInstancer* >;
using DataControllerInstancerMap = std::unordered_map< std::string, DataControllerInstancer* >;
using StructuralDataViewInstancerMap = std::unordered_map< std::string, DataViewInstancer* >;

static DataViewInstancerMap data_view_instancers;
static DataControllerInstancerMap data_controller_instancers;

struct DefaultInstancers {
	DataViewInstancerDefault<DataViewAttribute> data_view_attribute;
	DataViewInstancerDefault<DataViewAttributeIf> data_view_attribute_if;
	DataViewInstancerDefault<DataViewClass> data_view_class;
	DataViewInstancerDefault<DataViewIf> data_view_if;
	DataViewInstancerDefault<DataViewVisible> data_view_visible;
	DataViewInstancerDefault<DataViewHtml> data_view_html;
	DataViewInstancerDefault<DataViewStyle> data_view_style;
	DataViewInstancerDefault<DataViewText> data_view_text;
	DataViewInstancerDefault<DataViewValue> data_view_value;
	DataControllerInstancerDefault<DataControllerEvent> data_controller_event;
};

static std::unique_ptr<DefaultInstancers> default_instancers;

static void RegisterDataViewInstancer(DataViewInstancer* instancer, const std::string& name) {
	bool inserted = data_view_instancers.emplace(name, instancer).second;
	if (!inserted)
		Log::Message(Log::Level::Warning, "Could not register data view instancer '%s'. The given name is already registered.", name.c_str());
}

static void RegisterDataControllerInstancer(DataControllerInstancer* instancer, const std::string& name) {
	bool inserted = data_controller_instancers.emplace(name, instancer).second;
	if (!inserted)
		Log::Message(Log::Level::Warning, "Could not register data controller instancer '%s'. The given name is already registered.", name.c_str());
}

static DataViewPtr InstanceDataView(const std::string& type_name, Element* element) {
	assert(element);
	auto it = data_view_instancers.find(type_name);
	if (it != data_view_instancers.end())
		return it->second->InstanceView(element);
	return nullptr;
}

static DataControllerPtr InstanceDataController(Element* element, const std::string& type_name) {
	auto it = data_controller_instancers.find(type_name);
	if (it != data_controller_instancers.end())
		return it->second->InstanceController(element);
	return DataControllerPtr();
}

bool DataUtilities::Initialise() {
	default_instancers = std::make_unique<DefaultInstancers>();
	RegisterDataViewInstancer(&default_instancers->data_view_attribute,      "attr");
	RegisterDataViewInstancer(&default_instancers->data_view_attribute_if,   "attrif");
	RegisterDataViewInstancer(&default_instancers->data_view_class,          "class");
	RegisterDataViewInstancer(&default_instancers->data_view_if,             "if");
	RegisterDataViewInstancer(&default_instancers->data_view_visible,        "visible");
	RegisterDataViewInstancer(&default_instancers->data_view_html,           "html");
	RegisterDataViewInstancer(&default_instancers->data_view_style,          "style");
	RegisterDataViewInstancer(&default_instancers->data_view_text,           "text");
	RegisterDataViewInstancer(&default_instancers->data_view_value,          "value");
	RegisterDataControllerInstancer(&default_instancers->data_controller_event, "event");
	return true;
}

void DataUtilities::Shutdown() {
	data_controller_instancers.clear();
	data_view_instancers.clear();
	default_instancers.reset();
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

void DataUtilities::ApplyDataViewFor(Element* element, const HtmlElement& inner_html) {
	DataModel* data_model = element->GetDataModel();
	if (!data_model) {
		return;
	}
	for (auto const& [name, value] : element->GetAttributes()) {
		if (name == "data-for") {
			if (auto view = std::make_unique<DataViewFor>(element)) {
				if (view->Initialize(*data_model, element, value, inner_html)) {
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
