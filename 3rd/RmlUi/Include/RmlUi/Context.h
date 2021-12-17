#pragma once

#include "Platform.h"
#include "Types.h"
#include "Traits.h"
#include "Input.h"
#include "ID.h"

namespace Rml {

class Document;

class Context {
public:
	Context(const Size& dimensions);
	virtual ~Context();

	void SetDimensions(const Size& dimensions);
	const Size& GetDimensions() const;

	void Update(double delta);

	Document* LoadDocument(const std::string& document_path);
	void UnloadDocument(Document* document);

	void SetFocus(Document* document);
	Document* GetFocus() const;

	bool ProcessKeyDown(Input::KeyIdentifier key, int key_modifier_state);
	bool ProcessKeyUp(Input::KeyIdentifier key, int key_modifier_state);
	bool ProcessChar(int character);
	bool ProcessMouseMove(MouseButton button, int x, int y, int key_modifier_state);
	bool ProcessMouseButtonDown(MouseButton button, int x, int y, int key_modifier_state);
	bool ProcessMouseButtonUp(MouseButton button, int x, int y, int key_modifier_state);
	bool ProcessMouseWheel(float wheel_delta, int key_modifier_state);

	double GetElapsedTime();

private:
	Size dimensions;
	std::vector<Document*> unloaded_documents;
	std::vector<Document*> documents;
	Document* focus = nullptr;
	double m_elapsedtime = 0.;

	void ReleaseUnloadedDocuments();

	friend class Rml::Element;
};

}
