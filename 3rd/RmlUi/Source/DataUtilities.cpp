#include "../Include/RmlUi/DataUtilities.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Log.h"
#include "DataController.h"
#include "DataModel.h"
#include "DataView.h"
#include "DataControllerDefault.h"
#include "DataViewDefault.h"

namespace Rml {

using DataViewInstancerMap = std::unordered_map< std::string, DataViewInstancer* >;
using DataControllerInstancerMap = std::unordered_map< std::string, DataControllerInstancer* >;
using StructuralDataViewInstancerMap = std::unordered_map< std::string, DataViewInstancer* >;

static DataViewInstancerMap data_view_instancers;
static DataControllerInstancerMap data_controller_instancers;
static StructuralDataViewInstancerMap structural_data_view_instancers;
static std::vector<std::string> structural_data_view_attribute_names;

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
	DataViewInstancerDefault<DataViewFor> structural_data_view_for;
	DataControllerInstancerDefault<DataControllerEvent> data_controller_event;
};

static std::unique_ptr<DefaultInstancers> default_instancers;

static void RegisterDataViewInstancer(DataViewInstancer* instancer, const std::string& name, bool is_structural_view) {
	bool inserted = false;
	if (is_structural_view) {
		inserted = structural_data_view_instancers.emplace(name, instancer).second;
		if (inserted)
			structural_data_view_attribute_names.push_back(std::string("data-") + name);
	}
	else {
		inserted = data_view_instancers.emplace(name, instancer).second;
	}
	
	if (!inserted)
		Log::Message(Log::Level::Warning, "Could not register data view instancer '%s'. The given name is already registered.", name.c_str());
}

static void RegisterDataControllerInstancer(DataControllerInstancer* instancer, const std::string& name) {
	bool inserted = data_controller_instancers.emplace(name, instancer).second;
	if (!inserted)
		Log::Message(Log::Level::Warning, "Could not register data controller instancer '%s'. The given name is already registered.", name.c_str());
}

static DataViewPtr InstanceDataView(const std::string& type_name, Element* element, bool is_structural_view) {
	assert(element);
	if (is_structural_view) {
		auto it = structural_data_view_instancers.find(type_name);
		if (it != structural_data_view_instancers.end())
			return it->second->InstanceView(element);
	}
	else {
		auto it = data_view_instancers.find(type_name);
		if (it != data_view_instancers.end())
			return it->second->InstanceView(element);
	}
	return nullptr;
}

static DataControllerPtr InstanceDataController(Element* element, const std::string& type_name) {
	auto it = data_controller_instancers.find(type_name);
	if (it != data_controller_instancers.end())
		return it->second->InstanceController(element);
	return DataControllerPtr();
}

static bool IsStructuralDataView(const std::string& type_name) {
	return structural_data_view_instancers.find(type_name) != structural_data_view_instancers.end();
}

static bool ApplyDataViewsControllersInternal(Element* element, const bool construct_structural_view, const std::string& structural_view_inner_html) {
	assert(element);
	bool result = false;

	// If we have an active data model, check the attributes for any data bindings
	if (DataModel* data_model = element->GetDataModel()) {
		struct ViewControllerInitializer {
			std::string type;
			std::string modifier_or_inner_html;
			std::string expression;
			DataViewPtr view;
			DataControllerPtr controller;
			explicit operator bool() const { return view || controller; }
		};

		// Since data views and controllers may modify the element's attributes during initialization, we 
		// need to iterate over all the attributes _before_ initializing any views or controllers. We store
		// the information needed to initialize them in the following container.
		std::vector<ViewControllerInitializer> initializer_list;

		for (auto& attribute : element->GetAttributes()) {
			// Data views and controllers are declared by the following element attribute:
			//     data-[type]-[modifier]="[expression]"

			constexpr size_t data_str_length = sizeof("data-") - 1;

			const std::string& name = attribute.first;

			if (name.size() > data_str_length && name[0] == 'd' && name[1] == 'a' && name[2] == 't' && name[3] == 'a' && name[4] == '-') {
				const size_t type_end = name.find('-', data_str_length);
				const size_t type_size = (type_end == std::string::npos ? std::string::npos : type_end - data_str_length);
				std::string type_name = name.substr(data_str_length, type_size);

				ViewControllerInitializer initializer;

				// Structural data views are applied in a separate step from the normal views and controllers.
				if (construct_structural_view) {
					if (DataViewPtr view = InstanceDataView(type_name, element, true))
					{
						initializer.modifier_or_inner_html = structural_view_inner_html;
						initializer.view = std::move(view);
					}
				}
				else {
					if (IsStructuralDataView(type_name)) {
						// Structural data views should cancel all other non-structural data views and controllers. Exit now.
						// Eg. in elements with a 'data-for' attribute, the data views should be constructed on the generated
						// children elements and not on the current element generating the 'for' view.
						return false;
					}

					const size_t modifier_offset = data_str_length + type_name.size() + 1;
					if (modifier_offset < name.size())
						initializer.modifier_or_inner_html = name.substr(modifier_offset);

					if (DataViewPtr view = InstanceDataView(type_name, element, false))
						initializer.view = std::move(view);

					if (DataControllerPtr controller = InstanceDataController(element, type_name))
						initializer.controller = std::move(controller);
				}

				if (initializer) {
					initializer.type = std::move(type_name);
					initializer.expression = attribute.second;

					initializer_list.push_back(std::move(initializer));
				}
			}
		}

		// Now, we can safely initialize the data views and controllers, even modifying the element's attributes when desired.
		for (ViewControllerInitializer& initializer : initializer_list) {
			DataViewPtr& view = initializer.view;
			DataControllerPtr& controller = initializer.controller;

			if (view) {
				if (view->Initialize(*data_model, element, initializer.expression, initializer.modifier_or_inner_html)) {
					data_model->AddView(std::move(view));
					result = true;
				}
				else
					Log::Message(Log::Level::Warning, "Could not add data-%s view to element: %s", initializer.type.c_str(), element->GetAddress().c_str());
			}

			if (controller) {
				if (controller->Initialize(*data_model, element, initializer.expression, initializer.modifier_or_inner_html)) {
					data_model->AddController(std::move(controller));
					result = true;
				}
				else
					Log::Message(Log::Level::Warning, "Could not add data-%s controller to element: %s", initializer.type.c_str(), element->GetAddress().c_str());
			}
		}
	}

	return result;
}


bool DataUtilities::Initialise() {
	default_instancers = std::make_unique<DefaultInstancers>();
	RegisterDataViewInstancer(&default_instancers->data_view_attribute,      "attr",    false);
	RegisterDataViewInstancer(&default_instancers->data_view_attribute_if,   "attrif",  false);
	RegisterDataViewInstancer(&default_instancers->data_view_class,          "class",   false);
	RegisterDataViewInstancer(&default_instancers->data_view_if,             "if",      false);
	RegisterDataViewInstancer(&default_instancers->data_view_visible,        "visible", false);
	RegisterDataViewInstancer(&default_instancers->data_view_html,           "html",    false);
	RegisterDataViewInstancer(&default_instancers->data_view_style,          "style",   false);
	RegisterDataViewInstancer(&default_instancers->data_view_text,           "text",    false);
	RegisterDataViewInstancer(&default_instancers->data_view_value,          "value",   false);
	RegisterDataViewInstancer(&default_instancers->structural_data_view_for, "for",     true );
	RegisterDataControllerInstancer(&default_instancers->data_controller_event, "event");
	return true;
}

void DataUtilities::Shutdown() {
	data_controller_instancers.clear();
	data_view_instancers.clear();
	structural_data_view_instancers.clear();
	structural_data_view_attribute_names.clear();
	default_instancers.reset();
}

const std::vector<std::string>& DataUtilities::GetStructuralDataViewAttributeNames() {
	return structural_data_view_attribute_names;
}

bool DataUtilities::ApplyDataViewsControllers(Element* element) {
	return ApplyDataViewsControllersInternal(element, false, std::string());
}

bool DataUtilities::ApplyStructuralDataViews(Element* element, const std::string& inner_html) {
	return ApplyDataViewsControllersInternal(element, true, inner_html);
}

}
