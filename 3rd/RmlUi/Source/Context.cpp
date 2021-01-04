/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include "../Include/RmlUi/Context.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/DataModelHandle.h"
#include "../Include/RmlUi/ElementDocument.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/RenderInterface.h"
#include "../Include/RmlUi/StreamMemory.h"
#include "../Include/RmlUi/SystemInterface.h"
#include "../Include/RmlUi/StreamMemory.h"
#include "DataModel.h"
#include "EventDispatcher.h"
#include "PluginRegistry.h"
#include "StreamFile.h"
#include <algorithm>
#include <iterator>

namespace Rml {

Context::Context(const Vector2i& dimensions_)
: dimensions(dimensions_)
, density_independent_pixel_ratio(1.0f)
, clip_origin(-1, -1)
, clip_dimensions(-1, -1) {
	//cursor_proxy.reset(new ElementDocument("body"));
	//ElementDocument* cursor_proxy_document = dynamic_cast< ElementDocument* >(cursor_proxy.get());
	//if (cursor_proxy_document)
	//	cursor_proxy_document->context = this;
	//else
	//	cursor_proxy.reset();
}

Context::~Context() {
	for (auto& document : documents) {
		document->DispatchEvent(EventId::Unload, Dictionary());
		PluginRegistry::NotifyDocumentDestroy(document);
		unloaded_documents.push_back(document);
	}
	for (auto& document : unloaded_documents) {
		document->GetEventDispatcher()->DetachAllEvents();
		delete document;
	}
	documents.clear();
	unloaded_documents.clear();
}

void Context::SetDimensions(const Vector2i& _dimensions) {
	if (dimensions != _dimensions) {
		dimensions = _dimensions;
		if (focus) {
			focus->SetBounds(Vector4f(0, 0, dimensions[0], dimensions[1]));
			focus->DirtyLayout();
			focus->DispatchEvent(EventId::Resize, Dictionary());
		}
		clip_dimensions = dimensions;
	}
}

const Vector2i& Context::GetDimensions() const {
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

bool Context::Update() {
	RenderInterface* render_interface = GetRenderInterface();
	if (render_interface == nullptr) {
		return false;
	}

	if (focus) {
		render_interface->context = this;
		ElementUtilities::ApplyActiveClipRegion(this, render_interface);
		focus->Render();
		ElementUtilities::SetClippingRegion(nullptr, this);
		focus->UpdateDataModel(true);
		focus->Update(density_independent_pixel_ratio);
		focus->UpdateLayout();
		ReleaseUnloadedDocuments();
	}

	// Render the cursor proxy so any elements attached the cursor will be rendered below the cursor.
	//if (cursor_proxy)
	//{
	//	static_cast<ElementDocument&>(*cursor_proxy).UpdateDocument();
	//	cursor_proxy->SetOffset(Vector2f((float)Math::Clamp(mouse_position.x, 0, dimensions.x),
	//		(float)Math::Clamp(mouse_position.y, 0, dimensions.y)),
	//		nullptr);
	//	cursor_proxy->Render();
	//}

	render_interface->context = nullptr;
	return true;
}

// Load a document into the context.
ElementDocument* Context::LoadDocument(const String& document_path) {	
	auto stream = MakeUnique<StreamFile>();
	if (!stream->Open(document_path))
		return nullptr;

	ElementDocumentPtr document(new ElementDocument("body"));
	document->context = this;
	PluginRegistry::NotifyDocumentCreate(document.get());
	XMLParser parser(document.get());
	parser.Parse(stream.get());
	document->SetBounds(Vector4f(0, 0, dimensions[0], dimensions[1]));
	documents.push_back(document.get());
	document->DispatchEvent(EventId::Load, Dictionary());
	document->UpdateDataModel(false);
	document->UpdateDocument();
	return document.release();
}

void Context::UnloadDocument(ElementDocument* document) {
	RMLUI_ASSERT(document->GetContext() == this);
	for (size_t i = 0; i < unloaded_documents.size(); ++i) {
		if (unloaded_documents[i] == document)
			return;
	}
	document->DispatchEvent(EventId::Unload, Dictionary());
	PluginRegistry::NotifyDocumentDestroy(document);
	unloaded_documents.push_back(document);
}

void Context::SetFocus(ElementDocument* document) {
	RMLUI_ASSERT(document->GetContext() == this);
	focus = document;
}

ElementDocument* Context::GetFocus() const {
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

bool Context::ProcessMouseMove(int x, int y, int key_modifier_state) {
	if (!focus) {
		return false;
	}
	focus->ProcessMouseMove(x, y, key_modifier_state);
	return true;
}

bool Context::ProcessMouseButtonDown(int button_index, int key_modifier_state) {
	if (!focus) {
		return false;
	}
	focus->ProcessMouseButtonDown(button_index, key_modifier_state);
	return true;
}

bool Context::ProcessMouseButtonUp(int button_index, int key_modifier_state) {
	if (!focus) {
		return false;
	}
	focus->ProcessMouseButtonUp(button_index, key_modifier_state);
	return true;
}

bool Context::ProcessMouseWheel(float wheel_delta, int key_modifier_state) {
	if (!focus) {
		return false;
	}
	focus->ProcessMouseWheel(wheel_delta, key_modifier_state);
	return true;
}
	
bool Context::GetActiveClipRegion(Vector2i& origin, Vector2i& dimensions) const {
	if (clip_dimensions.x < 0 || clip_dimensions.y < 0)
		return false;
	origin = clip_origin;
	dimensions = clip_dimensions;
	return true;
}

void Context::SetActiveClipRegion(const Vector2i& origin, const Vector2i& dimensions) {
	clip_origin = origin;
	clip_dimensions = dimensions;
}

void Context::ReleaseUnloadedDocuments() {
	if (unloaded_documents.empty()) {
		return;
	}

	std::vector<ElementDocument*> documents = std::move(unloaded_documents);
	unloaded_documents.clear();
	for (auto document : documents) {
		document->GetEventDispatcher()->DetachAllEvents();
		auto pos = std::find(std::begin(documents), std::end(documents), document);
		std::rotate(pos, pos + 1, std::end(documents));
		documents.pop_back();
		delete document;
	}
}

} // namespace Rml
