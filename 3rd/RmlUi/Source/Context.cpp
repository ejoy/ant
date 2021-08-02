#include "../Include/RmlUi/Context.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/DataModelHandle.h"
#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/RenderInterface.h"
#include "../Include/RmlUi/StreamMemory.h"
#include "../Include/RmlUi/StreamMemory.h"
#include "DataModel.h"
#include "EventDispatcher.h"
#include "PluginRegistry.h"
#include "StreamFile.h"
#include <algorithm>
#include <iterator>

namespace Rml {

Context::Context(const Size& dimensions_)
: dimensions(dimensions_)
, density_independent_pixel_ratio(1.0f)
{ }

Context::~Context() {
	for (auto& document : documents) {
		document->body->DispatchEvent(EventId::Unload, EventDictionary());
		PluginRegistry::NotifyDocumentDestroy(document);
		unloaded_documents.push_back(document);
	}
	for (auto& document : unloaded_documents) {
		document->body->GetEventDispatcher()->DetachAllEvents();
		delete document;
	}
	documents.clear();
	unloaded_documents.clear();
}

void Context::SetDimensions(const Size& _dimensions) {
	if (dimensions != _dimensions) {
		dimensions = _dimensions;
		if (focus) {
			focus->SetDimensions(dimensions);
		}
	}
}

const Size& Context::GetDimensions() const {
	return dimensions;
}

void Context::SetDensityIndependentPixelRatio(float _density_independent_pixel_ratio) {
	if (density_independent_pixel_ratio != _density_independent_pixel_ratio) {
		density_independent_pixel_ratio = _density_independent_pixel_ratio;
		if (focus) {
			focus->DirtyDpProperties();
		}
	}
}

float Context::GetDensityIndependentPixelRatio() const {
	return density_independent_pixel_ratio;
}

void Context::Update(double delta) {
	m_elapsedtime += delta;
	if (focus) {
		focus->UpdateDataModel(true);
		focus->Update();
		focus->Render();
		ReleaseUnloadedDocuments();
	}
}

// Load a document into the context.
Document* Context::LoadDocument(const std::string& document_path) {	
	DocumentPtr document(new Document(dimensions));
	document->context = this;
	PluginRegistry::NotifyDocumentCreate(document.get());
	if (!document->Load(document_path)) {
		PluginRegistry::NotifyDocumentDestroy(document.get());
		return nullptr;
	}
	documents.push_back(document.get());
	document->body->DispatchEvent(EventId::Load, EventDictionary());
	document->UpdateDataModel(false);
	document->Update();
	return document.release();
}

void Context::UnloadDocument(Document* document) {
	RMLUI_ASSERT(document->GetContext() == this);
	for (size_t i = 0; i < unloaded_documents.size(); ++i) {
		if (unloaded_documents[i] == document)
			return;
	}
	document->body->DispatchEvent(EventId::Unload, EventDictionary());
	PluginRegistry::NotifyDocumentDestroy(document);
	unloaded_documents.push_back(document);
}

void Context::SetFocus(Document* document) {
	RMLUI_ASSERT(!document || document->GetContext() == this);
	if (focus) {
		Document* doc = focus;
		focus = document;
		doc->Hide();
	}
	else {
		focus = document;
	}
}

Document* Context::GetFocus() const {
	return focus;
}

bool Context::ProcessKeyDown(Input::KeyIdentifier key, int key_modifier_state) {
	if (!focus) {
		return false;
	}
	return focus->ProcessKeyDown(key, key_modifier_state);
}

bool Context::ProcessKeyUp(Input::KeyIdentifier key, int key_modifier_state) {
	if (!focus) {
		return false;
	}
	return focus->ProcessKeyUp(key, key_modifier_state);
}

bool Context::ProcessMouseMove(MouseButton button, int x, int y, int key_modifier_state) {
	if (!focus) {
		return false;
	}
	focus->ProcessMouseMove(button, x, y, key_modifier_state);
	return true;
}

bool Context::ProcessMouseButtonDown(MouseButton button, int key_modifier_state) {
	if (!focus) {
		return false;
	}
	focus->ProcessMouseButtonDown(button, key_modifier_state);
	return true;
}

bool Context::ProcessMouseButtonUp(MouseButton button, int key_modifier_state) {
	if (!focus) {
		return false;
	}
	focus->ProcessMouseButtonUp(button, key_modifier_state);
	return true;
}

bool Context::ProcessMouseWheel(float wheel_delta, int key_modifier_state) {
	if (!focus) {
		return false;
	}
	focus->ProcessMouseWheel(wheel_delta, key_modifier_state);
	return true;
}

void Context::ReleaseUnloadedDocuments() {
	if (unloaded_documents.empty()) {
		return;
	}

	std::vector<Document*> documents = std::move(unloaded_documents);
	unloaded_documents.clear();
	for (auto document : documents) {
		document->body->GetEventDispatcher()->DetachAllEvents();
		auto pos = std::find(std::begin(documents), std::end(documents), document);
		std::rotate(pos, pos + 1, std::end(documents));
		documents.pop_back();
		delete document;
	}
}

double Context::GetElapsedTime() {
	return m_elapsedtime / 1000;
}

}
