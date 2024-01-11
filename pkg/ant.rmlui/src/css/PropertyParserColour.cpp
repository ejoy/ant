#include <css/PropertyParserColour.h>
#include <util/StringUtilities.h>
#include <string.h>
#include <unordered_map>
#include <algorithm>

namespace Rml {

static std::unordered_map<std::string_view, Color> html_colours = {
	{ "transparent", Color::FromSRGB(0,0,0,0) },
	{ "aliceblue", Color::FromSRGB(240,248,255,255) },
	{ "antiquewhite", Color::FromSRGB(250,235,215,255) },
	{ "aqua", Color::FromSRGB(0,255,255,255) },
	{ "aquamarine", Color::FromSRGB(127,255,212,255) },
	{ "azure", Color::FromSRGB(240,255,255,255) },
	{ "beige", Color::FromSRGB(245,245,220,255) },
	{ "bisque", Color::FromSRGB(255,228,196,255) },
	{ "black", Color::FromSRGB(0,0,0,255) },
	{ "blanchedalmond", Color::FromSRGB(255,235,205,255) },
	{ "blue", Color::FromSRGB(0,0,255,255) },
	{ "blueviolet", Color::FromSRGB(138,43,226,255) },
	{ "brown", Color::FromSRGB(165,42,42,255) },
	{ "burlywood", Color::FromSRGB(222,184,135,255) },
	{ "cadetblue", Color::FromSRGB(95,158,160,255) },
	{ "chartreuse", Color::FromSRGB(127,255,0,255) },
	{ "chocolate", Color::FromSRGB(210,105,30,255) },
	{ "coral", Color::FromSRGB(255,127,80,255) },
	{ "cornflowerblue", Color::FromSRGB(100,149,237,255) },
	{ "cornsilk", Color::FromSRGB(255,248,220,255) },
	{ "crimson", Color::FromSRGB(220,20,60,255) },
	{ "cyan", Color::FromSRGB(0,255,255,255) },
	{ "darkblue", Color::FromSRGB(0,0,139,255) },
	{ "darkcyan", Color::FromSRGB(0,139,139,255) },
	{ "darkgoldenrod", Color::FromSRGB(184,134,11,255) },
	{ "darkgray", Color::FromSRGB(169,169,169,255) },
	{ "darkgreen", Color::FromSRGB(0,100,0,255) },
	{ "darkgrey", Color::FromSRGB(169,169,169,255) },
	{ "darkkhaki", Color::FromSRGB(189,183,107,255) },
	{ "darkmagenta", Color::FromSRGB(139,0,139,255) },
	{ "darkolivegreen", Color::FromSRGB(85,107,47,255) },
	{ "darkorange", Color::FromSRGB(255,140,0,255) },
	{ "darkorchid", Color::FromSRGB(153,50,204,255) },
	{ "darkred", Color::FromSRGB(139,0,0,255) },
	{ "darksalmon", Color::FromSRGB(233,150,122,255) },
	{ "darkseagreen", Color::FromSRGB(143,188,143,255) },
	{ "darkslateblue", Color::FromSRGB(72,61,139,255) },
	{ "darkslategray", Color::FromSRGB(47,79,79,255) },
	{ "darkslategrey", Color::FromSRGB(47,79,79,255) },
	{ "darkturquoise", Color::FromSRGB(0,206,209,255) },
	{ "darkviolet", Color::FromSRGB(148,0,211,255) },
	{ "deeppink", Color::FromSRGB(255,20,147,255) },
	{ "deepskyblue", Color::FromSRGB(0,191,255,255) },
	{ "dimgray", Color::FromSRGB(105,105,105,255) },
	{ "dimgrey", Color::FromSRGB(105,105,105,255) },
	{ "dodgerblue", Color::FromSRGB(30,144,255,255) },
	{ "firebrick", Color::FromSRGB(178,34,34,255) },
	{ "floralwhite", Color::FromSRGB(255,250,240,255) },
	{ "forestgreen", Color::FromSRGB(34,139,34,255) },
	{ "fuchsia", Color::FromSRGB(255,0,255,255) },
	{ "gainsboro", Color::FromSRGB(220,220,220,255) },
	{ "ghostwhite", Color::FromSRGB(248,248,255,255) },
	{ "gold", Color::FromSRGB(255,215,0,255) },
	{ "goldenrod", Color::FromSRGB(218,165,32,255) },
	{ "gray", Color::FromSRGB(128,128,128,255) },
	{ "green", Color::FromSRGB(0,128,0,255) },
	{ "greenyellow", Color::FromSRGB(173,255,47,255) },
	{ "grey", Color::FromSRGB(128,128,128,255) },
	{ "honeydew", Color::FromSRGB(240,255,240,255) },
	{ "hotpink", Color::FromSRGB(255,105,180,255) },
	{ "indianred", Color::FromSRGB(205,92,92,255) },
	{ "indigo", Color::FromSRGB(75,0,130,255) },
	{ "ivory", Color::FromSRGB(255,255,240,255) },
	{ "khaki", Color::FromSRGB(240,230,140,255) },
	{ "lavender", Color::FromSRGB(230,230,250,255) },
	{ "lavenderblush", Color::FromSRGB(255,240,245,255) },
	{ "lawngreen", Color::FromSRGB(124,252,0,255) },
	{ "lemonchiffon", Color::FromSRGB(255,250,205,255) },
	{ "lightblue", Color::FromSRGB(173,216,230,255) },
	{ "lightcoral", Color::FromSRGB(240,128,128,255) },
	{ "lightcyan", Color::FromSRGB(224,255,255,255) },
	{ "lightgoldenrodyellow", Color::FromSRGB(250,250,210,255) },
	{ "lightgray", Color::FromSRGB(211,211,211,255) },
	{ "lightgreen", Color::FromSRGB(144,238,144,255) },
	{ "lightgrey", Color::FromSRGB(211,211,211,255) },
	{ "lightpink", Color::FromSRGB(255,182,193,255) },
	{ "lightsalmon", Color::FromSRGB(255,160,122,255) },
	{ "lightseagreen", Color::FromSRGB(32,178,170,255) },
	{ "lightskyblue", Color::FromSRGB(135,206,250,255) },
	{ "lightslategray", Color::FromSRGB(119,136,153,255) },
	{ "lightslategrey", Color::FromSRGB(119,136,153,255) },
	{ "lightsteelblue", Color::FromSRGB(176,196,222,255) },
	{ "lightyellow", Color::FromSRGB(255,255,224,255) },
	{ "lime", Color::FromSRGB(0,255,0,255) },
	{ "limegreen", Color::FromSRGB(50,205,50,255) },
	{ "linen", Color::FromSRGB(250,240,230,255) },
	{ "magenta", Color::FromSRGB(255,0,255,255) },
	{ "maroon", Color::FromSRGB(128,0,0,255) },
	{ "mediumaquamarine", Color::FromSRGB(102,205,170,255) },
	{ "mediumblue", Color::FromSRGB(0,0,205,255) },
	{ "mediumorchid", Color::FromSRGB(186,85,211,255) },
	{ "mediumpurple", Color::FromSRGB(147,112,219,255) },
	{ "mediumseagreen", Color::FromSRGB(60,179,113,255) },
	{ "mediumslateblue", Color::FromSRGB(123,104,238,255) },
	{ "mediumspringgreen", Color::FromSRGB(0,250,154,255) },
	{ "mediumturquoise", Color::FromSRGB(72,209,204,255) },
	{ "mediumvioletred", Color::FromSRGB(199,21,133,255) },
	{ "midnightblue", Color::FromSRGB(25,25,112,255) },
	{ "mintcream", Color::FromSRGB(245,255,250,255) },
	{ "mistyrose", Color::FromSRGB(255,228,225,255) },
	{ "moccasin", Color::FromSRGB(255,228,181,255) },
	{ "navajowhite", Color::FromSRGB(255,222,173,255) },
	{ "navy", Color::FromSRGB(0,0,128,255) },
	{ "oldlace", Color::FromSRGB(253,245,230,255) },
	{ "olive", Color::FromSRGB(128,128,0,255) },
	{ "olivedrab", Color::FromSRGB(107,142,35,255) },
	{ "orange", Color::FromSRGB(255,165,0,255) },
	{ "orangered", Color::FromSRGB(255,69,0,255) },
	{ "orchid", Color::FromSRGB(218,112,214,255) },
	{ "palegoldenrod", Color::FromSRGB(238,232,170,255) },
	{ "palegreen", Color::FromSRGB(152,251,152,255) },
	{ "paleturquoise", Color::FromSRGB(175,238,238,255) },
	{ "palevioletred", Color::FromSRGB(219,112,147,255) },
	{ "papayawhip", Color::FromSRGB(255,239,213,255) },
	{ "peachpuff", Color::FromSRGB(255,218,185,255) },
	{ "peru", Color::FromSRGB(205,133,63,255) },
	{ "pink", Color::FromSRGB(255,192,203,255) },
	{ "plum", Color::FromSRGB(221,160,221,255) },
	{ "powderblue", Color::FromSRGB(176,224,230,255) },
	{ "purple", Color::FromSRGB(128,0,128,255) },
	{ "red", Color::FromSRGB(255,0,0,255) },
	{ "rosybrown", Color::FromSRGB(188,143,143,255) },
	{ "royalblue", Color::FromSRGB(65,105,225,255) },
	{ "saddlebrown", Color::FromSRGB(139,69,19,255) },
	{ "salmon", Color::FromSRGB(250,128,114,255) },
	{ "sandybrown", Color::FromSRGB(244,164,96,255) },
	{ "seagreen", Color::FromSRGB(46,139,87,255) },
	{ "seashell", Color::FromSRGB(255,245,238,255) },
	{ "sienna", Color::FromSRGB(160,82,45,255) },
	{ "silver", Color::FromSRGB(192,192,192,255) },
	{ "skyblue", Color::FromSRGB(135,206,235,255) },
	{ "slateblue", Color::FromSRGB(106,90,205,255) },
	{ "slategray", Color::FromSRGB(112,128,144,255) },
	{ "slategrey", Color::FromSRGB(112,128,144,255) },
	{ "snow", Color::FromSRGB(255,250,250,255) },
	{ "springgreen", Color::FromSRGB(0,255,127,255) },
	{ "steelblue", Color::FromSRGB(70,130,180,255) },
	{ "tan", Color::FromSRGB(210,180,140,255) },
	{ "teal", Color::FromSRGB(0,128,128,255) },
	{ "thistle", Color::FromSRGB(216,191,216,255) },
	{ "tomato", Color::FromSRGB(255,99,71,255) },
	{ "turquoise", Color::FromSRGB(64,224,208,255) },
	{ "violet", Color::FromSRGB(238,130,238,255) },
	{ "wheat", Color::FromSRGB(245,222,179,255) },
	{ "white", Color::FromSRGB(255,255,255,255) },
	{ "whitesmoke", Color::FromSRGB(245,245,245,255) },
	{ "yellow", Color::FromSRGB(255,255,0,255) },
	{ "yellowgreen", Color::FromSRGB(154,205,50,255) },
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

Property PropertyParseColour(PropertyId id, const std::string& value) {
	if (value.empty())
		return {};

	Color color = Color::FromSRGB(0,0,0,255);

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
		color = Color::FromSRGB(sRGB[0], sRGB[1], sRGB[2], sRGB[3]);
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

		// Check if we're parsing an 'rgba' or 'rgb' color declaration.
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
		color = Color::FromSRGB(sRGB[0], sRGB[1], sRGB[2], sRGB[3]);
	}
	else
	{
		// Check for the specification of an HTML color.
		auto iterator = html_colours.find(value);
		if (iterator == html_colours.end())
			return {};
		else
			color = (*iterator).second;
	}

	return { id, color };
}

}
