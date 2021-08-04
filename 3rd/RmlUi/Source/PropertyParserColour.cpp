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
#include "../Include/RmlUi/Math.h"
#include "../Include/RmlUi/StringUtilities.h"
#include <string.h>

namespace Rml {

PropertyParserColour::PropertyParserColour()
{
	html_colours["transparent"] = Color(255,255,255,0);

	html_colours["aliceblue"] =  Color(240,248,255,255);
	html_colours["antiquewhite"] =  Color(250,235,215,255);
	html_colours["aqua"] =  Color(0,255,255,255);
	html_colours["aquamarine"] =  Color(127,255,212,255);
	html_colours["azure"] =  Color(240,255,255,255);
	html_colours["beige"] =  Color(245,245,220,255);
	html_colours["bisque"] =  Color(255,228,196,255);
	html_colours["black"] =  Color(0,0,0,255);
	html_colours["blanchedalmond"] =  Color(255,235,205,255);
	html_colours["blue"] =  Color(0,0,255,255);
	html_colours["blueviolet"] =  Color(138,43,226,255);
	html_colours["brown"] =  Color(165,42,42,255);
	html_colours["burlywood"] =  Color(222,184,135,255);
	html_colours["cadetblue"] =  Color(95,158,160,255);
	html_colours["chartreuse"] =  Color(127,255,0,255);
	html_colours["chocolate"] =  Color(210,105,30,255);
	html_colours["coral"] =  Color(255,127,80,255);
	html_colours["cornflowerblue"] =  Color(100,149,237,255);
	html_colours["cornsilk"] =  Color(255,248,220,255);
	html_colours["crimson"] =  Color(220,20,60,255);
	html_colours["cyan"] =  Color(0,255,255,255);
	html_colours["darkblue"] =  Color(0,0,139,255);
	html_colours["darkcyan"] =  Color(0,139,139,255);
	html_colours["darkgoldenrod"] =  Color(184,134,11,255);
	html_colours["darkgray"] =  Color(169,169,169,255);
	html_colours["darkgreen"] =  Color(0,100,0,255);
	html_colours["darkgrey"] =  Color(169,169,169,255);
	html_colours["darkkhaki"] =  Color(189,183,107,255);
	html_colours["darkmagenta"] =  Color(139,0,139,255);
	html_colours["darkolivegreen"] =  Color(85,107,47,255);
	html_colours["darkorange"] =  Color(255,140,0,255);
	html_colours["darkorchid"] =  Color(153,50,204,255);
	html_colours["darkred"] =  Color(139,0,0,255);
	html_colours["darksalmon"] =  Color(233,150,122,255);
	html_colours["darkseagreen"] =  Color(143,188,143,255);
	html_colours["darkslateblue"] =  Color(72,61,139,255);
	html_colours["darkslategray"] =  Color(47,79,79,255);
	html_colours["darkslategrey"] =  Color(47,79,79,255);
	html_colours["darkturquoise"] =  Color(0,206,209,255);
	html_colours["darkviolet"] =  Color(148,0,211,255);
	html_colours["deeppink"] =  Color(255,20,147,255);
	html_colours["deepskyblue"] =  Color(0,191,255,255);
	html_colours["dimgray"] =  Color(105,105,105,255);
	html_colours["dimgrey"] =  Color(105,105,105,255);
	html_colours["dodgerblue"] =  Color(30,144,255,255);
	html_colours["firebrick"] =  Color(178,34,34,255);
	html_colours["floralwhite"] =  Color(255,250,240,255);
	html_colours["forestgreen"] =  Color(34,139,34,255);
	html_colours["fuchsia"] =  Color(255,0,255,255);
	html_colours["gainsboro"] =  Color(220,220,220,255);
	html_colours["ghostwhite"] =  Color(248,248,255,255);
	html_colours["gold"] =  Color(255,215,0,255);
	html_colours["goldenrod"] =  Color(218,165,32,255);
	html_colours["gray"] =  Color(128,128,128,255);
	html_colours["green"] =  Color(0,128,0,255);
	html_colours["greenyellow"] =  Color(173,255,47,255);
	html_colours["grey"] =  Color(128,128,128,255);
	html_colours["honeydew"] =  Color(240,255,240,255);
	html_colours["hotpink"] =  Color(255,105,180,255);
	html_colours["indianred"] =  Color(205,92,92,255);
	html_colours["indigo"] =  Color(75,0,130,255);
	html_colours["ivory"] =  Color(255,255,240,255);
	html_colours["khaki"] =  Color(240,230,140,255);
	html_colours["lavender"] =  Color(230,230,250,255);
	html_colours["lavenderblush"] =  Color(255,240,245,255);
	html_colours["lawngreen"] =  Color(124,252,0,255);
	html_colours["lemonchiffon"] =  Color(255,250,205,255);
	html_colours["lightblue"] =  Color(173,216,230,255);
	html_colours["lightcoral"] =  Color(240,128,128,255);
	html_colours["lightcyan"] =  Color(224,255,255,255);
	html_colours["lightgoldenrodyellow"] =  Color(250,250,210,255);
	html_colours["lightgray"] =  Color(211,211,211,255);
	html_colours["lightgreen"] =  Color(144,238,144,255);
	html_colours["lightgrey"] =  Color(211,211,211,255);
	html_colours["lightpink"] =  Color(255,182,193,255);
	html_colours["lightsalmon"] =  Color(255,160,122,255);
	html_colours["lightseagreen"] =  Color(32,178,170,255);
	html_colours["lightskyblue"] =  Color(135,206,250,255);
	html_colours["lightslategray"] =  Color(119,136,153,255);
	html_colours["lightslategrey"] =  Color(119,136,153,255);
	html_colours["lightsteelblue"] =  Color(176,196,222,255);
	html_colours["lightyellow"] =  Color(255,255,224,255);
	html_colours["lime"] =  Color(0,255,0,255);
	html_colours["limegreen"] =  Color(50,205,50,255);
	html_colours["linen"] =  Color(250,240,230,255);
	html_colours["magenta"] =  Color(255,0,255,255);
	html_colours["maroon"] =  Color(128,0,0,255);
	html_colours["mediumaquamarine"] =  Color(102,205,170,255);
	html_colours["mediumblue"] =  Color(0,0,205,255);
	html_colours["mediumorchid"] =  Color(186,85,211,255);
	html_colours["mediumpurple"] =  Color(147,112,219,255);
	html_colours["mediumseagreen"] =  Color(60,179,113,255);
	html_colours["mediumslateblue"] =  Color(123,104,238,255);
	html_colours["mediumspringgreen"] =  Color(0,250,154,255);
	html_colours["mediumturquoise"] =  Color(72,209,204,255);
	html_colours["mediumvioletred"] =  Color(199,21,133,255);
	html_colours["midnightblue"] =  Color(25,25,112,255);
	html_colours["mintcream"] =  Color(245,255,250,255);
	html_colours["mistyrose"] =  Color(255,228,225,255);
	html_colours["moccasin"] =  Color(255,228,181,255);
	html_colours["navajowhite"] =  Color(255,222,173,255);
	html_colours["navy"] =  Color(0,0,128,255);
	html_colours["oldlace"] =  Color(253,245,230,255);
	html_colours["olive"] =  Color(128,128,0,255);
	html_colours["olivedrab"] =  Color(107,142,35,255);
	html_colours["orange"] =  Color(255,165,0,255);
	html_colours["orangered"] =  Color(255,69,0,255);
	html_colours["orchid"] =  Color(218,112,214,255);
	html_colours["palegoldenrod"] =  Color(238,232,170,255);
	html_colours["palegreen"] =  Color(152,251,152,255);
	html_colours["paleturquoise"] =  Color(175,238,238,255);
	html_colours["palevioletred"] =  Color(219,112,147,255);
	html_colours["papayawhip"] =  Color(255,239,213,255);
	html_colours["peachpuff"] =  Color(255,218,185,255);
	html_colours["peru"] =  Color(205,133,63,255);
	html_colours["pink"] =  Color(255,192,203,255);
	html_colours["plum"] =  Color(221,160,221,255);
	html_colours["powderblue"] =  Color(176,224,230,255);
	html_colours["purple"] =  Color(128,0,128,255);
	html_colours["red"] =  Color(255,0,0,255);
	html_colours["rosybrown"] =  Color(188,143,143,255);
	html_colours["royalblue"] =  Color(65,105,225,255);
	html_colours["saddlebrown"] =  Color(139,69,19,255);
	html_colours["salmon"] =  Color(250,128,114,255);
	html_colours["sandybrown"] =  Color(244,164,96,255);
	html_colours["seagreen"] =  Color(46,139,87,255);
	html_colours["seashell"] =  Color(255,245,238,255);
	html_colours["sienna"] =  Color(160,82,45,255);
	html_colours["silver"] =  Color(192,192,192,255);
	html_colours["skyblue"] =  Color(135,206,235,255);
	html_colours["slateblue"] =  Color(106,90,205,255);
	html_colours["slategray"] =  Color(112,128,144,255);
	html_colours["slategrey"] =  Color(112,128,144,255);
	html_colours["snow"] =  Color(255,250,250,255);
	html_colours["springgreen"] =  Color(0,255,127,255);
	html_colours["steelblue"] =  Color(70,130,180,255);
	html_colours["tan"] =  Color(210,180,140,255);
	html_colours["teal"] =  Color(0,128,128,255);
	html_colours["thistle"] =  Color(216,191,216,255);
	html_colours["tomato"] =  Color(255,99,71,255);
	html_colours["turquoise"] =  Color(64,224,208,255);
	html_colours["violet"] =  Color(238,130,238,255);
	html_colours["wheat"] =  Color(245,222,179,255);
	html_colours["white"] =  Color(255,255,255,255);
	html_colours["whitesmoke"] =  Color(245,245,245,255);
	html_colours["yellow"] =  Color(255,255,0,255);
	html_colours["yellowgreen"] =  Color(154,205,50,255);
}

PropertyParserColour::~PropertyParserColour()
{
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

		// Parse each of the colour elements.
		for (int i = 0; i < 4; i++)
		{
			int tens = Math::HexToDecimal(hex_values[i][0]);
			int ones = Math::HexToDecimal(hex_values[i][1]);
			if (tens == -1 ||
				ones == -1)
				return false;

			colour[i] = (byte) (tens * 16 + ones);
		}
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

		// Parse the three RGB values.
		for (int i = 0; i < 4; ++i)
		{
			int component;

			// We're parsing a percentage value.
			if (values[i].size() > 0 && values[i][values[i].size() - 1] == '%')
				component = Math::RealToInteger((float) (atof(values[i].substr(0, values[i].size() - 1).c_str()) / 100.0f) * 255.0f);
			// We're parsing a 0 -> 255 integer value.
			else
				component = atoi(values[i].c_str());

			colour[i] = (byte) (Math::Clamp(component, 0, 255));
		}
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
