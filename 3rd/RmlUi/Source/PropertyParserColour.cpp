#include "PropertyParserColour.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "../Include/RmlUi/Property.h"
#include <string.h>
#include <unordered_map>

namespace Rml {

static std::unordered_map<std::string, Color> html_colours = {
	{ "transparent", ColorFromSRGB(255,255,255,0) },
	{ "aliceblue", ColorFromSRGB(240,248,255,255) },
	{ "antiquewhite", ColorFromSRGB(250,235,215,255) },
	{ "aqua", ColorFromSRGB(0,255,255,255) },
	{ "aquamarine", ColorFromSRGB(127,255,212,255) },
	{ "azure", ColorFromSRGB(240,255,255,255) },
	{ "beige", ColorFromSRGB(245,245,220,255) },
	{ "bisque", ColorFromSRGB(255,228,196,255) },
	{ "black", ColorFromSRGB(0,0,0,255) },
	{ "blanchedalmond", ColorFromSRGB(255,235,205,255) },
	{ "blue", ColorFromSRGB(0,0,255,255) },
	{ "blueviolet", ColorFromSRGB(138,43,226,255) },
	{ "brown", ColorFromSRGB(165,42,42,255) },
	{ "burlywood", ColorFromSRGB(222,184,135,255) },
	{ "cadetblue", ColorFromSRGB(95,158,160,255) },
	{ "chartreuse", ColorFromSRGB(127,255,0,255) },
	{ "chocolate", ColorFromSRGB(210,105,30,255) },
	{ "coral", ColorFromSRGB(255,127,80,255) },
	{ "cornflowerblue", ColorFromSRGB(100,149,237,255) },
	{ "cornsilk", ColorFromSRGB(255,248,220,255) },
	{ "crimson", ColorFromSRGB(220,20,60,255) },
	{ "cyan", ColorFromSRGB(0,255,255,255) },
	{ "darkblue", ColorFromSRGB(0,0,139,255) },
	{ "darkcyan", ColorFromSRGB(0,139,139,255) },
	{ "darkgoldenrod", ColorFromSRGB(184,134,11,255) },
	{ "darkgray", ColorFromSRGB(169,169,169,255) },
	{ "darkgreen", ColorFromSRGB(0,100,0,255) },
	{ "darkgrey", ColorFromSRGB(169,169,169,255) },
	{ "darkkhaki", ColorFromSRGB(189,183,107,255) },
	{ "darkmagenta", ColorFromSRGB(139,0,139,255) },
	{ "darkolivegreen", ColorFromSRGB(85,107,47,255) },
	{ "darkorange", ColorFromSRGB(255,140,0,255) },
	{ "darkorchid", ColorFromSRGB(153,50,204,255) },
	{ "darkred", ColorFromSRGB(139,0,0,255) },
	{ "darksalmon", ColorFromSRGB(233,150,122,255) },
	{ "darkseagreen", ColorFromSRGB(143,188,143,255) },
	{ "darkslateblue", ColorFromSRGB(72,61,139,255) },
	{ "darkslategray", ColorFromSRGB(47,79,79,255) },
	{ "darkslategrey", ColorFromSRGB(47,79,79,255) },
	{ "darkturquoise", ColorFromSRGB(0,206,209,255) },
	{ "darkviolet", ColorFromSRGB(148,0,211,255) },
	{ "deeppink", ColorFromSRGB(255,20,147,255) },
	{ "deepskyblue", ColorFromSRGB(0,191,255,255) },
	{ "dimgray", ColorFromSRGB(105,105,105,255) },
	{ "dimgrey", ColorFromSRGB(105,105,105,255) },
	{ "dodgerblue", ColorFromSRGB(30,144,255,255) },
	{ "firebrick", ColorFromSRGB(178,34,34,255) },
	{ "floralwhite", ColorFromSRGB(255,250,240,255) },
	{ "forestgreen", ColorFromSRGB(34,139,34,255) },
	{ "fuchsia", ColorFromSRGB(255,0,255,255) },
	{ "gainsboro", ColorFromSRGB(220,220,220,255) },
	{ "ghostwhite", ColorFromSRGB(248,248,255,255) },
	{ "gold", ColorFromSRGB(255,215,0,255) },
	{ "goldenrod", ColorFromSRGB(218,165,32,255) },
	{ "gray", ColorFromSRGB(128,128,128,255) },
	{ "green", ColorFromSRGB(0,128,0,255) },
	{ "greenyellow", ColorFromSRGB(173,255,47,255) },
	{ "grey", ColorFromSRGB(128,128,128,255) },
	{ "honeydew", ColorFromSRGB(240,255,240,255) },
	{ "hotpink", ColorFromSRGB(255,105,180,255) },
	{ "indianred", ColorFromSRGB(205,92,92,255) },
	{ "indigo", ColorFromSRGB(75,0,130,255) },
	{ "ivory", ColorFromSRGB(255,255,240,255) },
	{ "khaki", ColorFromSRGB(240,230,140,255) },
	{ "lavender", ColorFromSRGB(230,230,250,255) },
	{ "lavenderblush", ColorFromSRGB(255,240,245,255) },
	{ "lawngreen", ColorFromSRGB(124,252,0,255) },
	{ "lemonchiffon", ColorFromSRGB(255,250,205,255) },
	{ "lightblue", ColorFromSRGB(173,216,230,255) },
	{ "lightcoral", ColorFromSRGB(240,128,128,255) },
	{ "lightcyan", ColorFromSRGB(224,255,255,255) },
	{ "lightgoldenrodyellow", ColorFromSRGB(250,250,210,255) },
	{ "lightgray", ColorFromSRGB(211,211,211,255) },
	{ "lightgreen", ColorFromSRGB(144,238,144,255) },
	{ "lightgrey", ColorFromSRGB(211,211,211,255) },
	{ "lightpink", ColorFromSRGB(255,182,193,255) },
	{ "lightsalmon", ColorFromSRGB(255,160,122,255) },
	{ "lightseagreen", ColorFromSRGB(32,178,170,255) },
	{ "lightskyblue", ColorFromSRGB(135,206,250,255) },
	{ "lightslategray", ColorFromSRGB(119,136,153,255) },
	{ "lightslategrey", ColorFromSRGB(119,136,153,255) },
	{ "lightsteelblue", ColorFromSRGB(176,196,222,255) },
	{ "lightyellow", ColorFromSRGB(255,255,224,255) },
	{ "lime", ColorFromSRGB(0,255,0,255) },
	{ "limegreen", ColorFromSRGB(50,205,50,255) },
	{ "linen", ColorFromSRGB(250,240,230,255) },
	{ "magenta", ColorFromSRGB(255,0,255,255) },
	{ "maroon", ColorFromSRGB(128,0,0,255) },
	{ "mediumaquamarine", ColorFromSRGB(102,205,170,255) },
	{ "mediumblue", ColorFromSRGB(0,0,205,255) },
	{ "mediumorchid", ColorFromSRGB(186,85,211,255) },
	{ "mediumpurple", ColorFromSRGB(147,112,219,255) },
	{ "mediumseagreen", ColorFromSRGB(60,179,113,255) },
	{ "mediumslateblue", ColorFromSRGB(123,104,238,255) },
	{ "mediumspringgreen", ColorFromSRGB(0,250,154,255) },
	{ "mediumturquoise", ColorFromSRGB(72,209,204,255) },
	{ "mediumvioletred", ColorFromSRGB(199,21,133,255) },
	{ "midnightblue", ColorFromSRGB(25,25,112,255) },
	{ "mintcream", ColorFromSRGB(245,255,250,255) },
	{ "mistyrose", ColorFromSRGB(255,228,225,255) },
	{ "moccasin", ColorFromSRGB(255,228,181,255) },
	{ "navajowhite", ColorFromSRGB(255,222,173,255) },
	{ "navy", ColorFromSRGB(0,0,128,255) },
	{ "oldlace", ColorFromSRGB(253,245,230,255) },
	{ "olive", ColorFromSRGB(128,128,0,255) },
	{ "olivedrab", ColorFromSRGB(107,142,35,255) },
	{ "orange", ColorFromSRGB(255,165,0,255) },
	{ "orangered", ColorFromSRGB(255,69,0,255) },
	{ "orchid", ColorFromSRGB(218,112,214,255) },
	{ "palegoldenrod", ColorFromSRGB(238,232,170,255) },
	{ "palegreen", ColorFromSRGB(152,251,152,255) },
	{ "paleturquoise", ColorFromSRGB(175,238,238,255) },
	{ "palevioletred", ColorFromSRGB(219,112,147,255) },
	{ "papayawhip", ColorFromSRGB(255,239,213,255) },
	{ "peachpuff", ColorFromSRGB(255,218,185,255) },
	{ "peru", ColorFromSRGB(205,133,63,255) },
	{ "pink", ColorFromSRGB(255,192,203,255) },
	{ "plum", ColorFromSRGB(221,160,221,255) },
	{ "powderblue", ColorFromSRGB(176,224,230,255) },
	{ "purple", ColorFromSRGB(128,0,128,255) },
	{ "red", ColorFromSRGB(255,0,0,255) },
	{ "rosybrown", ColorFromSRGB(188,143,143,255) },
	{ "royalblue", ColorFromSRGB(65,105,225,255) },
	{ "saddlebrown", ColorFromSRGB(139,69,19,255) },
	{ "salmon", ColorFromSRGB(250,128,114,255) },
	{ "sandybrown", ColorFromSRGB(244,164,96,255) },
	{ "seagreen", ColorFromSRGB(46,139,87,255) },
	{ "seashell", ColorFromSRGB(255,245,238,255) },
	{ "sienna", ColorFromSRGB(160,82,45,255) },
	{ "silver", ColorFromSRGB(192,192,192,255) },
	{ "skyblue", ColorFromSRGB(135,206,235,255) },
	{ "slateblue", ColorFromSRGB(106,90,205,255) },
	{ "slategray", ColorFromSRGB(112,128,144,255) },
	{ "slategrey", ColorFromSRGB(112,128,144,255) },
	{ "snow", ColorFromSRGB(255,250,250,255) },
	{ "springgreen", ColorFromSRGB(0,255,127,255) },
	{ "steelblue", ColorFromSRGB(70,130,180,255) },
	{ "tan", ColorFromSRGB(210,180,140,255) },
	{ "teal", ColorFromSRGB(0,128,128,255) },
	{ "thistle", ColorFromSRGB(216,191,216,255) },
	{ "tomato", ColorFromSRGB(255,99,71,255) },
	{ "turquoise", ColorFromSRGB(64,224,208,255) },
	{ "violet", ColorFromSRGB(238,130,238,255) },
	{ "wheat", ColorFromSRGB(245,222,179,255) },
	{ "white", ColorFromSRGB(255,255,255,255) },
	{ "whitesmoke", ColorFromSRGB(245,245,245,255) },
	{ "yellow", ColorFromSRGB(255,255,0,255) },
	{ "yellowgreen", ColorFromSRGB(154,205,50,255) },
};

static int HexToDecimal(char hex_digit) {
	if (hex_digit >= '0' && hex_digit <= '9')
		return hex_digit - '0';
	else if (hex_digit >= 'a' && hex_digit <= 'f')
		return 10 + (hex_digit - 'a');
	else if (hex_digit >= 'A' && hex_digit <= 'F')
		return 10 + (hex_digit - 'A');
	return -1;
}

std::optional<Property> PropertyParserColour::ParseValue(const std::string& value) const {
	if (value.empty())
		return {};

	Color colour(0,0,0,255);

	if (value[0] == '#') {
		char hex_values[4][2] = { {'f', 'f'},
								  {'f', 'f'},
								  {'f', 'f'},
								  {'f', 'f'} };

		switch (value.size()) {
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
				return {};
		}

		uint8_t sRGB[4];
		for (int i = 0; i < 4; i++) {
			int tens = HexToDecimal(hex_values[i][0]);
			int ones = HexToDecimal(hex_values[i][1]);
			if (tens == -1 || ones == -1)
				return {};
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
			return {};

		size_t begin_values = find + 1;

		StringUtilities::ExpandString(values, value.substr(begin_values, value.rfind(')') - begin_values), ',');

		// Check if we're parsing an 'rgba' or 'rgb' colour declaration.
		if (value.size() > 3 && value[3] == 'a')
		{
			if (values.size() != 4)
				return {};
		}
		else
		{
			if (values.size() != 3)
				return {};

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
		auto iterator = html_colours.find(StringUtilities::ToLower(value));
		if (iterator == html_colours.end())
			return {};
		else
			colour = (*iterator).second;
	}

	return Property {colour};
}

}
