#pragma once

#include "Types.h"
#include "ID.h"

namespace Rml {

class Document;

class Context {
public:
	Context(const Size& dimensions);
	virtual ~Context();
	void SetDimensions(const Size& dimensions);
	void Update();
	Document* LoadDocument(const std::string& document_path);
	void UnloadDocument(Document* document);
	bool ProcessTouch(TouchState state);
	bool ProcessMouse(MouseButton button, MouseState state, int x, int y);
	bool ProcessMouseWheel(float wheel_delta);

private:
	Size dimensions;
	std::vector<Document*> unloaded_documents;
	std::vector<Document*> documents;
	void ReleaseUnloadedDocuments();
};

}
