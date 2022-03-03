#include "../Include/RmlUi/Context.h"
#include "../Include/RmlUi/Document.h"

namespace Rml {

Context::Context(const Size& dimensions_)
: dimensions(dimensions_)
{ }

Context::~Context() {
	for (auto& document : documents) {
		document->Close();
		unloaded_documents.push_back(document);
	}
	for (auto& document : unloaded_documents) {
		delete document;
	}
	documents.clear();
	unloaded_documents.clear();
}

void Context::SetDimensions(const Size& _dimensions) {
	if (dimensions != _dimensions) {
		dimensions = _dimensions;
		for (auto doc : documents) {
			doc->SetDimensions(dimensions);
		}
	}
}

void Context::Update() {
	for (auto doc : documents) {
		doc->Update();
	}
	ReleaseUnloadedDocuments();
}

Document* Context::LoadDocument(const std::string& document_path) {	
	DocumentPtr document(new Document(dimensions));
	if (!document->Load(document_path)) {
		return nullptr;
	}
	documents.insert(documents.begin(), document.get());
	return document.release();
}

void Context::UnloadDocument(Document* document) {
	for (size_t i = 0; i < unloaded_documents.size(); ++i) {
		if (unloaded_documents[i] == document)
			return;
	}
	document->Close();
	unloaded_documents.push_back(document);
}

bool Context::ProcessTouch(TouchState state) {
	for (auto doc : documents) {
		if (doc->ProcessTouch(state)) {{
			return true;
		}}
	}
	return false;
}

bool Context::ProcessMouse(MouseButton button, MouseState state, int x, int y) {
	for (auto doc : documents) {
		if (doc->ProcessMouse(button, state, x, y)) {{
			return true;
		}}
	}
	return false;
}

bool Context::ProcessMouseWheel(float wheel_delta) {
	for (auto doc : documents) {
		if (doc->ProcessMouseWheel(wheel_delta)) {{
			return true;
		}}
	}
	return false;
}

void Context::ReleaseUnloadedDocuments() {
	if (unloaded_documents.empty()) {
		return;
	}

	std::vector<Document*> docs = std::move(unloaded_documents);
	unloaded_documents.clear();
	for (auto document : docs) {
		auto pos = std::find(std::begin(documents), std::end(documents), document);
		std::rotate(pos, pos + 1, std::end(documents));
		documents.pop_back();
		delete document;
	}
}

}
