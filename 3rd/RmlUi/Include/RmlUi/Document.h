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

#ifndef RMLUI_CORE_ELEMENTDOCUMENT_H
#define RMLUI_CORE_ELEMENTDOCUMENT_H

#include "ElementDocument.h"
#include "Input.h"
#include <set>

namespace Rml {

class Context;
class ElementText;
class StyleSheet;
class DataModel;
class DataModelConstructor;

class Document {
public:
	Document(const Size& dimensions);
	virtual ~Document();

	bool Load(const std::string& path);

	/// Returns the document's context.
	Context* GetContext();

	/// Returns the source address of this document.
	const std::string& GetSourceURL() const;

	/// Sets the style sheet this document, and all of its children, uses.
	void SetStyleSheet(std::shared_ptr<StyleSheet> style_sheet);
	/// Returns the document's style sheet.
	const std::shared_ptr<StyleSheet>& GetStyleSheet() const;

	/// Show the document.
	void Show();
	/// Hide the document.
	void Hide();
	/// Close the document.
	void Close();
	bool IsShow() const { return show_; }
	bool ClickTest(const Point& point) const;
	/// Creates the named element.
	/// @param[in] name The tag name of the element.
	ElementPtr CreateElement(const std::string& name);
	/// Create a text element with the given text content.
	/// @param[in] text The text content of the text element.
	TextPtr CreateTextNode(const std::string& text);

	virtual void LoadInlineScript(const std::string& content, const std::string& source_path, int source_line);
	virtual void LoadExternalScript(const std::string& source_path);

	bool ProcessKeyDown(Input::KeyIdentifier key, int key_modifier_state);
	bool ProcessKeyUp(Input::KeyIdentifier key, int key_modifier_state);
	bool ProcessChar(int character);
	bool ProcessMouseMove(MouseButton button, int x, int y, int key_modifier_state);
	bool ProcessMouseButtonDown(MouseButton button, int x, int y, int key_modifier_state);
	bool ProcessMouseButtonUp(MouseButton button, int x, int y, int key_modifier_state);
	void ProcessMouseWheel(float wheel_delta, int key_modifier_state);
	void OnElementDetach(Element* element);
	void SetDimensions(const Size& dimensions);
	const Size& GetDimensions();

	void Update();
	void Render();
	std::unique_ptr<ElementDocument> body;

public:
	DataModelConstructor CreateDataModel(const std::string& name);
	DataModelConstructor GetDataModel(const std::string& name);
	bool RemoveDataModel(const std::string& name);
	void UpdateDataModel(bool clear_dirty_variables);
	DataModel* GetDataModelPtr(const std::string& name) const;

private:
	using DataModels = std::unordered_map<std::string, std::unique_ptr<DataModel>>;
	DataModels data_models;

private:
	// The original path this document came from
	std::string source_url;

	// The document's style sheet.
	std::shared_ptr<StyleSheet> style_sheet;

	Context* context;

	void UpdateHoverChain(const EventDictionary& parameters, const EventDictionary& drag_parameters);

	Point mouse_position = Point(0,0);

	Element* hover = nullptr;
	Element* active = nullptr;
	Element* focus = nullptr;

	std::set<Element*> hover_chain;
	std::vector<Element*> active_chain;
	Size dimensions;
	bool dirty_dimensions = false;
	bool show_ = true;
	friend class Rml::Context;
	friend class Rml::Factory;

};

} // namespace Rml
#endif
