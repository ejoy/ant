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

#include "Element.h"
#include "Input.h"
#include <set>

namespace Rml {

class Context;
class Stream;
class DocumentHeader;
class ElementText;
class StyleSheet;
class DataModel;
class DataModelConstructor;
class DataTypeRegister;

/**
	Represents a document in the dom tree.

	@author Lloyd Weehuizen
 */

class RMLUICORE_API ElementDocument : public Element
{
public:
	ElementDocument(const String& tag);
	virtual ~ElementDocument();

	/// Process given document header
	void ProcessHeader(const DocumentHeader* header);

	/// Returns the document's context.
	Context* GetContext();

	/// Sets the document's title.
	void SetTitle(const String& title);
	/// Returns the title of this document.
	const String& GetTitle() const;

	/// Returns the source address of this document.
	const String& GetSourceURL() const;

	/// Sets the style sheet this document, and all of its children, uses.
	void SetStyleSheet(SharedPtr<StyleSheet> style_sheet);
	/// Returns the document's style sheet.
	const SharedPtr<StyleSheet>& GetStyleSheet() const override;

	/// Show the document.
	void Show();
	/// Hide the document.
	void Hide();
	/// Close the document.
	void Close();

	/// Creates the named element.
	/// @param[in] name The tag name of the element.
	ElementPtr CreateElement(const String& name);
	/// Create a text element with the given text content.
	/// @param[in] text The text content of the text element.
	ElementPtr CreateTextNode(const String& text);

	/// Load a inline script into the document. Note that the base implementation does nothing, scripting language addons hook
	/// this method.
	/// @param[in] content The script content.
	/// @param[in] source_path Path of the script the source comes from, useful for debug information.
	/// @param[in] source_line Line of the script the source comes from, useful for debug information.
	virtual void LoadInlineScript(const String& content, const String& source_path, int source_line);

	/// Load a external script into the document. Note that the base implementation does nothing, scripting language addons hook
	/// this method.
	/// @param[in] source_path The script file path.
	virtual void LoadExternalScript(const String& source_path);

	/// Updates the document, including its layout. Users must call this manually before requesting information such as 
	/// size or position of an element if any element in the document was recently changed, unless Context::Update has
	/// already been called after the change. This has a perfomance penalty, only call when necessary.
	void UpdateDocument();

	bool ChangeFocus(Element* new_focus);
	Element* GetFocus() const;

	bool ProcessKeyDown(Input::KeyIdentifier key, int key_modifier_state);
	bool ProcessKeyUp(Input::KeyIdentifier key, int key_modifier_state);
	bool ProcessTextInput(const String& string);
	void ProcessMouseMove(int x, int y, int key_modifier_state);
	void ProcessMouseButtonDown(int button_index, int key_modifier_state);
	void ProcessMouseButtonUp(int button_index, int key_modifier_state);
	void ProcessMouseWheel(float wheel_delta, int key_modifier_state);
	void OnElementDetach(Element* element);

public:
	DataModelConstructor CreateDataModel(const String& name);
	DataModelConstructor GetDataModel(const String& name);
	bool RemoveDataModel(const String& name);
	void UpdateDataModel(bool clear_dirty_variables);
	DataModel* GetDataModelPtr(const String& name) const;

private:
	using DataModels = UnorderedMap<String, UniquePtr<DataModel>>;
	DataModels data_models;
	UniquePtr<DataTypeRegister> data_type_register;

protected:
	/// Repositions the document if necessary.
	void OnPropertyChange(const PropertyIdSet& changed_properties) override;

	/// Called during update if the element size has been changed.
	void OnResize() override;

private:
	/// Find the next element to focus, starting at the current element
	Element* FindNextTabElement(Element* current_element, bool forward);
	/// Searches forwards or backwards for a focusable element in the given substree
	Element* SearchFocusSubtree(Element* element, bool forward);

	/// Sets the dirty flag on the layout so the document will format its children before the next render.
	void DirtyLayout() override;

	/// Updates all sizes defined by the 'lp' unit.
	void DirtyDpProperties();

	/// Updates the layout if necessary.
	void UpdateLayout();

	// Title of the document
	String title;

	// The original path this document came from
	String source_url;

	// The document's style sheet.
	SharedPtr<StyleSheet> style_sheet;

	Context* context;

	void UpdateHoverChain(const Dictionary& parameters, const Dictionary& drag_parameters, const Vector2i& old_mouse_position);
	void CreateDragClone(Element* element);
	void ReleaseDragClone();

	Vector2i mouse_position = Vector2i(0,0);

	Element* hover = nullptr;
	Element* active = nullptr;

	Element* drag = nullptr;
	bool drag_started = false;
	bool drag_verbose = false;
	Element* drag_clone = nullptr;
	Element* drag_hover = nullptr;
	std::set<Element*> drag_hover_chain;

	Element* last_click_element = nullptr;
	double last_click_time = 0;
	Vector2i last_click_mouse_position = Vector2i(0, 0);

	std::set<Element*> hover_chain;
	std::vector<Element*> active_chain;
	ElementPtr cursor_proxy;

	friend class Rml::Context;
	friend class Rml::Factory;

};

} // namespace Rml
#endif
