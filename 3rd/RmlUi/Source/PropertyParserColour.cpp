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
#include <string.h>

namespace Rml {

PropertyParserColour::PropertyParserColour()
{
	html_colours["transparent"] = Colourb(255, 255, 255, 0);

	html_colours["aliceblue"] =  Colourb(240,248,255);
	html_colours["antiquewhite"] =  Colourb(250,235,215);
	html_colours["aqua"] =  Colourb(0,255,255);
	html_colours["aquamarine"] =  Colourb(127,255,212);
	html_colours["azure"] =  Colourb(240,255,255);
	html_colours["beige"] =  Colourb(245,245,220);
	html_colours["bisque"] =  Colourb(255,228,196);
	html_colours["black"] =  Colourb(0,0,0);
	html_colours["blanchedalmond"] =  Colourb(255,235,205);
	html_colours["blue"] =  Colourb(0,0,255);
	html_colours["blueviolet"] =  Colourb(138,43,226);
	html_colours["brown"] =  Colourb(165,42,42);
	html_colours["burlywood"] =  Colourb(222,184,135);
	html_colours["cadetblue"] =  Colourb(95,158,160);
	html_colours["chartreuse"] =  Colourb(127,255,0);
	html_colours["chocolate"] =  Colourb(210,105,30);
	html_colours["coral"] =  Colourb(255,127,80);
	html_colours["cornflowerblue"] =  Colourb(100,149,237);
	html_colours["cornsilk"] =  Colourb(255,248,220);
	html_colours["crimson"] =  Colourb(220,20,60);
	html_colours["cyan"] =  Colourb(0,255,255);
	html_colours["darkblue"] =  Colourb(0,0,139);
	html_colours["darkcyan"] =  Colourb(0,139,139);
	html_colours["darkgoldenrod"] =  Colourb(184,134,11);
	html_colours["darkgray"] =  Colourb(169,169,169);
	html_colours["darkgreen"] =  Colourb(0,100,0);
	html_colours["darkgrey"] =  Colourb(169,169,169);
	html_colours["darkkhaki"] =  Colourb(189,183,107);
	html_colours["darkmagenta"] =  Colourb(139,0,139);
	html_colours["darkolivegreen"] =  Colourb(85,107,47);
	html_colours["darkorange"] =  Colourb(255,140,0);
	html_colours["darkorchid"] =  Colourb(153,50,204);
	html_colours["darkred"] =  Colourb(139,0,0);
	html_colours["darksalmon"] =  Colourb(233,150,122);
	html_colours["darkseagreen"] =  Colourb(143,188,143);
	html_colours["darkslateblue"] =  Colourb(72,61,139);
	html_colours["darkslategray"] =  Colourb(47,79,79);
	html_colours["darkslategrey"] =  Colourb(47,79,79);
	html_colours["darkturquoise"] =  Colourb(0,206,209);
	html_colours["darkviolet"] =  Colourb(148,0,211);
	html_colours["deeppink"] =  Colourb(255,20,147);
	html_colours["deepskyblue"] =  Colourb(0,191,255);
	html_colours["dimgray"] =  Colourb(105,105,105);
	html_colours["dimgrey"] =  Colourb(105,105,105);
	html_colours["dodgerblue"] =  Colourb(30,144,255);
	html_colours["firebrick"] =  Colourb(178,34,34);
	html_colours["floralwhite"] =  Colourb(255,250,240);
	html_colours["forestgreen"] =  Colourb(34,139,34);
	html_colours["fuchsia"] =  Colourb(255,0,255);
	html_colours["gainsboro"] =  Colourb(220,220,220);
	html_colours["ghostwhite"] =  Colourb(248,248,255);
	html_colours["gold"] =  Colourb(255,215,0);
	html_colours["goldenrod"] =  Colourb(218,165,32);
	html_colours["gray"] =  Colourb(128,128,128);
	html_colours["green"] =  Colourb(0,128,0);
	html_colours["greenyellow"] =  Colourb(173,255,47);
	html_colours["grey"] =  Colourb(128,128,128);
	html_colours["honeydew"] =  Colourb(240,255,240);
	html_colours["hotpink"] =  Colourb(255,105,180);
	html_colours["indianred"] =  Colourb(205,92,92);
	html_colours["indigo"] =  Colourb(75,0,130);
	html_colours["ivory"] =  Colourb(255,255,240);
	html_colours["khaki"] =  Colourb(240,230,140);
	html_colours["lavender"] =  Colourb(230,230,250);
	html_colours["lavenderblush"] =  Colourb(255,240,245);
	html_colours["lawngreen"] =  Colourb(124,252,0);
	html_colours["lemonchiffon"] =  Colourb(255,250,205);
	html_colours["lightblue"] =  Colourb(173,216,230);
	html_colours["lightcoral"] =  Colourb(240,128,128);
	html_colours["lightcyan"] =  Colourb(224,255,255);
	html_colours["lightgoldenrodyellow"] =  Colourb(250,250,210);
	html_colours["lightgray"] =  Colourb(211,211,211);
	html_colours["lightgreen"] =  Colourb(144,238,144);
	html_colours["lightgrey"] =  Colourb(211,211,211);
	html_colours["lightpink"] =  Colourb(255,182,193);
	html_colours["lightsalmon"] =  Colourb(255,160,122);
	html_colours["lightseagreen"] =  Colourb(32,178,170);
	html_colours["lightskyblue"] =  Colourb(135,206,250);
	html_colours["lightslategray"] =  Colourb(119,136,153);
	html_colours["lightslategrey"] =  Colourb(119,136,153);
	html_colours["lightsteelblue"] =  Colourb(176,196,222);
	html_colours["lightyellow"] =  Colourb(255,255,224);
	html_colours["lime"] =  Colourb(0,255,0);
	html_colours["limegreen"] =  Colourb(50,205,50);
	html_colours["linen"] =  Colourb(250,240,230);
	html_colours["magenta"] =  Colourb(255,0,255);
	html_colours["maroon"] =  Colourb(128,0,0);
	html_colours["mediumaquamarine"] =  Colourb(102,205,170);
	html_colours["mediumblue"] =  Colourb(0,0,205);
	html_colours["mediumorchid"] =  Colourb(186,85,211);
	html_colours["mediumpurple"] =  Colourb(147,112,219);
	html_colours["mediumseagreen"] =  Colourb(60,179,113);
	html_colours["mediumslateblue"] =  Colourb(123,104,238);
	html_colours["mediumspringgreen"] =  Colourb(0,250,154);
	html_colours["mediumturquoise"] =  Colourb(72,209,204);
	html_colours["mediumvioletred"] =  Colourb(199,21,133);
	html_colours["midnightblue"] =  Colourb(25,25,112);
	html_colours["mintcream"] =  Colourb(245,255,250);
	html_colours["mistyrose"] =  Colourb(255,228,225);
	html_colours["moccasin"] =  Colourb(255,228,181);
	html_colours["navajowhite"] =  Colourb(255,222,173);
	html_colours["navy"] =  Colourb(0,0,128);
	html_colours["oldlace"] =  Colourb(253,245,230);
	html_colours["olive"] =  Colourb(128,128,0);
	html_colours["olivedrab"] =  Colourb(107,142,35);
	html_colours["orange"] =  Colourb(255,165,0);
	html_colours["orangered"] =  Colourb(255,69,0);
	html_colours["orchid"] =  Colourb(218,112,214);
	html_colours["palegoldenrod"] =  Colourb(238,232,170);
	html_colours["palegreen"] =  Colourb(152,251,152);
	html_colours["paleturquoise"] =  Colourb(175,238,238);
	html_colours["palevioletred"] =  Colourb(219,112,147);
	html_colours["papayawhip"] =  Colourb(255,239,213);
	html_colours["peachpuff"] =  Colourb(255,218,185);
	html_colours["peru"] =  Colourb(205,133,63);
	html_colours["pink"] =  Colourb(255,192,203);
	html_colours["plum"] =  Colourb(221,160,221);
	html_colours["powderblue"] =  Colourb(176,224,230);
	html_colours["purple"] =  Colourb(128,0,128);
	html_colours["red"] =  Colourb(255,0,0);
	html_colours["rosybrown"] =  Colourb(188,143,143);
	html_colours["royalblue"] =  Colourb(65,105,225);
	html_colours["saddlebrown"] =  Colourb(139,69,19);
	html_colours["salmon"] =  Colourb(250,128,114);
	html_colours["sandybrown"] =  Colourb(244,164,96);
	html_colours["seagreen"] =  Colourb(46,139,87);
	html_colours["seashell"] =  Colourb(255,245,238);
	html_colours["sienna"] =  Colourb(160,82,45);
	html_colours["silver"] =  Colourb(192,192,192);
	html_colours["skyblue"] =  Colourb(135,206,235);
	html_colours["slateblue"] =  Colourb(106,90,205);
	html_colours["slategray"] =  Colourb(112,128,144);
	html_colours["slategrey"] =  Colourb(112,128,144);
	html_colours["snow"] =  Colourb(255,250,250);
	html_colours["springgreen"] =  Colourb(0,255,127);
	html_colours["steelblue"] =  Colourb(70,130,180);
	html_colours["tan"] =  Colourb(210,180,140);
	html_colours["teal"] =  Colourb(0,128,128);
	html_colours["thistle"] =  Colourb(216,191,216);
	html_colours["tomato"] =  Colourb(255,99,71);
	html_colours["turquoise"] =  Colourb(64,224,208);
	html_colours["violet"] =  Colourb(238,130,238);
	html_colours["wheat"] =  Colourb(245,222,179);
	html_colours["white"] =  Colourb(255,255,255);
	html_colours["whitesmoke"] =  Colourb(245,245,245);
	html_colours["yellow"] =  Colourb(255,255,0);
	html_colours["yellowgreen"] =  Colourb(154,205,50);
}

PropertyParserColour::~PropertyParserColour()
{
}

// Called to parse a RCSS colour declaration.
bool PropertyParserColour::ParseValue(Property& property, const String& value, const ParameterMap& RMLUI_UNUSED_PARAMETER(parameters)) const
{
	RMLUI_UNUSED(parameters);

	if (value.empty())
		return false;

	Colourb colour;

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
		StringList values;
		values.reserve(4);

		size_t find = value.find('(');
		if (find == String::npos)
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

	property.value = Variant(colour);
	property.unit = Property::COLOUR;

	return true;
}

} // namespace Rml
