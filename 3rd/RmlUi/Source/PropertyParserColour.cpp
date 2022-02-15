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

#include "PropertyParserColour.h"
#include "../Include/RmlUi/StringUtilities.h"
#include <string.h>

namespace Rml {

PropertyParserColour::PropertyParserColour()
{
	html_colours["transparent"] = ColorFromSRGB(255,255,255,0);

	html_colours["aliceblue"] =  ColorFromSRGB(240,248,255,255);
	html_colours["antiquewhite"] =  ColorFromSRGB(250,235,215,255);
	html_colours["aqua"] =  ColorFromSRGB(0,255,255,255);
	html_colours["aquamarine"] =  ColorFromSRGB(127,255,212,255);
	html_colours["azure"] =  ColorFromSRGB(240,255,255,255);
	html_colours["beige"] =  ColorFromSRGB(245,245,220,255);
	html_colours["bisque"] =  ColorFromSRGB(255,228,196,255);
	html_colours["black"] =  ColorFromSRGB(0,0,0,255);
	html_colours["blanchedalmond"] =  ColorFromSRGB(255,235,205,255);
	html_colours["blue"] =  ColorFromSRGB(0,0,255,255);
	html_colours["blueviolet"] =  ColorFromSRGB(138,43,226,255);
	html_colours["brown"] =  ColorFromSRGB(165,42,42,255);
	html_colours["burlywood"] =  ColorFromSRGB(222,184,135,255);
	html_colours["cadetblue"] =  ColorFromSRGB(95,158,160,255);
	html_colours["chartreuse"] =  ColorFromSRGB(127,255,0,255);
	html_colours["chocolate"] =  ColorFromSRGB(210,105,30,255);
	html_colours["coral"] =  ColorFromSRGB(255,127,80,255);
	html_colours["cornflowerblue"] =  ColorFromSRGB(100,149,237,255);
	html_colours["cornsilk"] =  ColorFromSRGB(255,248,220,255);
	html_colours["crimson"] =  ColorFromSRGB(220,20,60,255);
	html_colours["cyan"] =  ColorFromSRGB(0,255,255,255);
	html_colours["darkblue"] =  ColorFromSRGB(0,0,139,255);
	html_colours["darkcyan"] =  ColorFromSRGB(0,139,139,255);
	html_colours["darkgoldenrod"] =  ColorFromSRGB(184,134,11,255);
	html_colours["darkgray"] =  ColorFromSRGB(169,169,169,255);
	html_colours["darkgreen"] =  ColorFromSRGB(0,100,0,255);
	html_colours["darkgrey"] =  ColorFromSRGB(169,169,169,255);
	html_colours["darkkhaki"] =  ColorFromSRGB(189,183,107,255);
	html_colours["darkmagenta"] =  ColorFromSRGB(139,0,139,255);
	html_colours["darkolivegreen"] =  ColorFromSRGB(85,107,47,255);
	html_colours["darkorange"] =  ColorFromSRGB(255,140,0,255);
	html_colours["darkorchid"] =  ColorFromSRGB(153,50,204,255);
	html_colours["darkred"] =  ColorFromSRGB(139,0,0,255);
	html_colours["darksalmon"] =  ColorFromSRGB(233,150,122,255);
	html_colours["darkseagreen"] =  ColorFromSRGB(143,188,143,255);
	html_colours["darkslateblue"] =  ColorFromSRGB(72,61,139,255);
	html_colours["darkslategray"] =  ColorFromSRGB(47,79,79,255);
	html_colours["darkslategrey"] =  ColorFromSRGB(47,79,79,255);
	html_colours["darkturquoise"] =  ColorFromSRGB(0,206,209,255);
	html_colours["darkviolet"] =  ColorFromSRGB(148,0,211,255);
	html_colours["deeppink"] =  ColorFromSRGB(255,20,147,255);
	html_colours["deepskyblue"] =  ColorFromSRGB(0,191,255,255);
	html_colours["dimgray"] =  ColorFromSRGB(105,105,105,255);
	html_colours["dimgrey"] =  ColorFromSRGB(105,105,105,255);
	html_colours["dodgerblue"] =  ColorFromSRGB(30,144,255,255);
	html_colours["firebrick"] =  ColorFromSRGB(178,34,34,255);
	html_colours["floralwhite"] =  ColorFromSRGB(255,250,240,255);
	html_colours["forestgreen"] =  ColorFromSRGB(34,139,34,255);
	html_colours["fuchsia"] =  ColorFromSRGB(255,0,255,255);
	html_colours["gainsboro"] =  ColorFromSRGB(220,220,220,255);
	html_colours["ghostwhite"] =  ColorFromSRGB(248,248,255,255);
	html_colours["gold"] =  ColorFromSRGB(255,215,0,255);
	html_colours["goldenrod"] =  ColorFromSRGB(218,165,32,255);
	html_colours["gray"] =  ColorFromSRGB(128,128,128,255);
	html_colours["green"] =  ColorFromSRGB(0,128,0,255);
	html_colours["greenyellow"] =  ColorFromSRGB(173,255,47,255);
	html_colours["grey"] =  ColorFromSRGB(128,128,128,255);
	html_colours["honeydew"] =  ColorFromSRGB(240,255,240,255);
	html_colours["hotpink"] =  ColorFromSRGB(255,105,180,255);
	html_colours["indianred"] =  ColorFromSRGB(205,92,92,255);
	html_colours["indigo"] =  ColorFromSRGB(75,0,130,255);
	html_colours["ivory"] =  ColorFromSRGB(255,255,240,255);
	html_colours["khaki"] =  ColorFromSRGB(240,230,140,255);
	html_colours["lavender"] =  ColorFromSRGB(230,230,250,255);
	html_colours["lavenderblush"] =  ColorFromSRGB(255,240,245,255);
	html_colours["lawngreen"] =  ColorFromSRGB(124,252,0,255);
	html_colours["lemonchiffon"] =  ColorFromSRGB(255,250,205,255);
	html_colours["lightblue"] =  ColorFromSRGB(173,216,230,255);
	html_colours["lightcoral"] =  ColorFromSRGB(240,128,128,255);
	html_colours["lightcyan"] =  ColorFromSRGB(224,255,255,255);
	html_colours["lightgoldenrodyellow"] =  ColorFromSRGB(250,250,210,255);
	html_colours["lightgray"] =  ColorFromSRGB(211,211,211,255);
	html_colours["lightgreen"] =  ColorFromSRGB(144,238,144,255);
	html_colours["lightgrey"] =  ColorFromSRGB(211,211,211,255);
	html_colours["lightpink"] =  ColorFromSRGB(255,182,193,255);
	html_colours["lightsalmon"] =  ColorFromSRGB(255,160,122,255);
	html_colours["lightseagreen"] =  ColorFromSRGB(32,178,170,255);
	html_colours["lightskyblue"] =  ColorFromSRGB(135,206,250,255);
	html_colours["lightslategray"] =  ColorFromSRGB(119,136,153,255);
	html_colours["lightslategrey"] =  ColorFromSRGB(119,136,153,255);
	html_colours["lightsteelblue"] =  ColorFromSRGB(176,196,222,255);
	html_colours["lightyellow"] =  ColorFromSRGB(255,255,224,255);
	html_colours["lime"] =  ColorFromSRGB(0,255,0,255);
	html_colours["limegreen"] =  ColorFromSRGB(50,205,50,255);
	html_colours["linen"] =  ColorFromSRGB(250,240,230,255);
	html_colours["magenta"] =  ColorFromSRGB(255,0,255,255);
	html_colours["maroon"] =  ColorFromSRGB(128,0,0,255);
	html_colours["mediumaquamarine"] =  ColorFromSRGB(102,205,170,255);
	html_colours["mediumblue"] =  ColorFromSRGB(0,0,205,255);
	html_colours["mediumorchid"] =  ColorFromSRGB(186,85,211,255);
	html_colours["mediumpurple"] =  ColorFromSRGB(147,112,219,255);
	html_colours["mediumseagreen"] =  ColorFromSRGB(60,179,113,255);
	html_colours["mediumslateblue"] =  ColorFromSRGB(123,104,238,255);
	html_colours["mediumspringgreen"] =  ColorFromSRGB(0,250,154,255);
	html_colours["mediumturquoise"] =  ColorFromSRGB(72,209,204,255);
	html_colours["mediumvioletred"] =  ColorFromSRGB(199,21,133,255);
	html_colours["midnightblue"] =  ColorFromSRGB(25,25,112,255);
	html_colours["mintcream"] =  ColorFromSRGB(245,255,250,255);
	html_colours["mistyrose"] =  ColorFromSRGB(255,228,225,255);
	html_colours["moccasin"] =  ColorFromSRGB(255,228,181,255);
	html_colours["navajowhite"] =  ColorFromSRGB(255,222,173,255);
	html_colours["navy"] =  ColorFromSRGB(0,0,128,255);
	html_colours["oldlace"] =  ColorFromSRGB(253,245,230,255);
	html_colours["olive"] =  ColorFromSRGB(128,128,0,255);
	html_colours["olivedrab"] =  ColorFromSRGB(107,142,35,255);
	html_colours["orange"] =  ColorFromSRGB(255,165,0,255);
	html_colours["orangered"] =  ColorFromSRGB(255,69,0,255);
	html_colours["orchid"] =  ColorFromSRGB(218,112,214,255);
	html_colours["palegoldenrod"] =  ColorFromSRGB(238,232,170,255);
	html_colours["palegreen"] =  ColorFromSRGB(152,251,152,255);
	html_colours["paleturquoise"] =  ColorFromSRGB(175,238,238,255);
	html_colours["palevioletred"] =  ColorFromSRGB(219,112,147,255);
	html_colours["papayawhip"] =  ColorFromSRGB(255,239,213,255);
	html_colours["peachpuff"] =  ColorFromSRGB(255,218,185,255);
	html_colours["peru"] =  ColorFromSRGB(205,133,63,255);
	html_colours["pink"] =  ColorFromSRGB(255,192,203,255);
	html_colours["plum"] =  ColorFromSRGB(221,160,221,255);
	html_colours["powderblue"] =  ColorFromSRGB(176,224,230,255);
	html_colours["purple"] =  ColorFromSRGB(128,0,128,255);
	html_colours["red"] =  ColorFromSRGB(255,0,0,255);
	html_colours["rosybrown"] =  ColorFromSRGB(188,143,143,255);
	html_colours["royalblue"] =  ColorFromSRGB(65,105,225,255);
	html_colours["saddlebrown"] =  ColorFromSRGB(139,69,19,255);
	html_colours["salmon"] =  ColorFromSRGB(250,128,114,255);
	html_colours["sandybrown"] =  ColorFromSRGB(244,164,96,255);
	html_colours["seagreen"] =  ColorFromSRGB(46,139,87,255);
	html_colours["seashell"] =  ColorFromSRGB(255,245,238,255);
	html_colours["sienna"] =  ColorFromSRGB(160,82,45,255);
	html_colours["silver"] =  ColorFromSRGB(192,192,192,255);
	html_colours["skyblue"] =  ColorFromSRGB(135,206,235,255);
	html_colours["slateblue"] =  ColorFromSRGB(106,90,205,255);
	html_colours["slategray"] =  ColorFromSRGB(112,128,144,255);
	html_colours["slategrey"] =  ColorFromSRGB(112,128,144,255);
	html_colours["snow"] =  ColorFromSRGB(255,250,250,255);
	html_colours["springgreen"] =  ColorFromSRGB(0,255,127,255);
	html_colours["steelblue"] =  ColorFromSRGB(70,130,180,255);
	html_colours["tan"] =  ColorFromSRGB(210,180,140,255);
	html_colours["teal"] =  ColorFromSRGB(0,128,128,255);
	html_colours["thistle"] =  ColorFromSRGB(216,191,216,255);
	html_colours["tomato"] =  ColorFromSRGB(255,99,71,255);
	html_colours["turquoise"] =  ColorFromSRGB(64,224,208,255);
	html_colours["violet"] =  ColorFromSRGB(238,130,238,255);
	html_colours["wheat"] =  ColorFromSRGB(245,222,179,255);
	html_colours["white"] =  ColorFromSRGB(255,255,255,255);
	html_colours["whitesmoke"] =  ColorFromSRGB(245,245,245,255);
	html_colours["yellow"] =  ColorFromSRGB(255,255,0,255);
	html_colours["yellowgreen"] =  ColorFromSRGB(154,205,50,255);
}

PropertyParserColour::~PropertyParserColour()
{
}

static int HexToDecimal(char hex_digit) {
	if (hex_digit >= '0' && hex_digit <= '9')
		return hex_digit - '0';
	else if (hex_digit >= 'a' && hex_digit <= 'f')
		return 10 + (hex_digit - 'a');
	else if (hex_digit >= 'A' && hex_digit <= 'F')
		return 10 + (hex_digit - 'A');
	return -1;
}

// Called to parse a RCSS colour declaration.
bool PropertyParserColour::ParseValue(Property& property, const std::string& value, const ParameterMap& RMLUI_UNUSED_PARAMETER(parameters)) const
{
	RMLUI_UNUSED(parameters);

	if (value.empty())
		return false;

	Color colour(0,0,0,255);

	// Check for a hex colour.
	if (value[0] == '#')
	{
		char hex_values[4][2] = { {'f', 'f'},
								  {'f', 'f'},
								  {'f', 'f'},
								  {'f', 'f'} };

		switch (value.size())
		{
			// Single hex digit per channel, RGB and alpha.
			case 5:		hex_values[3][0] = hex_values[3][1] = value[4];
						//-fallthrough
			// Single hex digit per channel, RGB only.
			case 4:		hex_values[0][0] = hex_values[0][1] = value[1];
						hex_values[1][0] = hex_values[1][1] = value[2];
						hex_values[2][0] = hex_values[2][1] = value[3];
						break;

			// Two hex digits per channel, RGB and alpha.
			case 9:		hex_values[3][0] = value[7];
						hex_values[3][1] = value[8];
						//-fallthrough
			// Two hex digits per channel, RGB only.
			case 7:		memcpy(hex_values, &value.c_str()[1], sizeof(char) * 6);
						break;

			default:
				return false;
		}

		uint8_t sRGB[4];
		for (int i = 0; i < 4; i++) {
			int tens = HexToDecimal(hex_values[i][0]);
			int ones = HexToDecimal(hex_values[i][1]);
			if (tens == -1 || ones == -1)
				return false;
			sRGB[i] = (tens * 16 + ones);
		}
		colour = ColorFromSRGB(sRGB[0], sRGB[1], sRGB[2], sRGB[3]);
	}
	else if (value.substr(0, 3) == "rgb")
	{
		std::vector<std::string> values;
		values.reserve(4);

		size_t find = value.find('(');
		if (find == std::string::npos)
			return false;

		size_t begin_values = find + 1;

		StringUtilities::ExpandString(values, value.substr(begin_values, value.rfind(')') - begin_values), ',');

		// Check if we're parsing an 'rgba' or 'rgb' colour declaration.
		if (value.size() > 3 && value[3] == 'a')
		{
			if (values.size() != 4)
				return false;
		}
		else
		{
			if (values.size() != 3)
				return false;

			values.push_back("255");
		}

		uint8_t sRGB[4];
		for (int i = 0; i < 4; ++i) {
			int component;

			// We're parsing a percentage value.
			if (values[i].size() > 0 && values[i][values[i].size() - 1] == '%')
				component = (int)((float) (atof(values[i].substr(0, values[i].size() - 1).c_str()) / 100.0f) * 255.0f);
			// We're parsing a 0 -> 255 integer value.
			else
				component = atoi(values[i].c_str());

			sRGB[i] = (uint8_t)std::clamp(component, 0, 255);
		}
		colour = ColorFromSRGB(sRGB[0], sRGB[1], sRGB[2], sRGB[3]);
	}
	else
	{
		// Check for the specification of an HTML colour.
		ColourMap::const_iterator iterator = html_colours.find(StringUtilities::ToLower(value));
		if (iterator == html_colours.end())
			return false;
		else
			colour = (*iterator).second;
	}

	property.value = colour;
	property.unit = Property::COLOUR;

	return true;
}

} // namespace Rml
