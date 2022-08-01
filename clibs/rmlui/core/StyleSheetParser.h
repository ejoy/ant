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

#ifndef RMLUI_CORE_STYLESHEETPARSER_H
#define RMLUI_CORE_STYLESHEETPARSER_H

#include <core/StyleSheet.h>
#include <core/PropertyDictionary.h>

namespace Rml {

class Stream;
class StyleSheetNode;

class StyleSheetParser {
public:
	StyleSheetParser();
	~StyleSheetParser();

	int Parse(StyleSheetNode* node, Stream* stream, const StyleSheet& style_sheet, KeyframesMap& keyframes, int begin_line_number);
	bool ParseProperties(PropertyVector& vec, const std::string& properties);

private:
	Stream* stream;
	size_t line_number;

	bool ReadProperties(PropertyVector& vec);
	static StyleSheetNode* ImportProperties(StyleSheetNode* node, std::string rule_name, const PropertyVector& properties, int rule_specificity);
	bool ParseKeyframeBlock(KeyframesMap & keyframes_map, const std::string & identifier, const std::string & rules, const PropertyVector& properties);
	char FindToken(std::string& buffer, const char* tokens, bool remove_token);
	bool ReadCharacter(char& buffer);
};

}
#endif
