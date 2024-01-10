#include <css/PropertyParserTransform.h>
#include <css/PropertyParserNumber.h>
#include <core/Transform.h>
#include <string.h>

namespace Rml {

using ParseFloatFunc = std::optional<PropertyFloat> (*) (const std::string&);

static ParseFloatFunc number = PropertyParseFloat<PropertyParseNumberUnit::Number>;
static ParseFloatFunc length = PropertyParseFloat<PropertyParseNumberUnit::LengthPercent>;
static ParseFloatFunc angle = PropertyParseFloat<PropertyParseNumberUnit::Angle>;

const ParseFloatFunc angle1[] = { angle };
const ParseFloatFunc angle2[] = { angle, angle };
const ParseFloatFunc length1[] = { length };
const ParseFloatFunc length2[] = { length, length };
const ParseFloatFunc length3[] = { length, length, length };
const ParseFloatFunc number3angle1[] = { number, number, number, angle };
const ParseFloatFunc number1[] = { number };
const ParseFloatFunc number2[] = { number, number };
const ParseFloatFunc number3[] = { number, number, number };
const ParseFloatFunc number6[] = { number, number, number, number, number, number };
const ParseFloatFunc number16[] = { number, number, number, number, number, number, number, number, number, number, number, number, number, number, number, number };

// Scan a string for a parameterized keyword with a certain number of numeric arguments.
static bool Scan(int& out_bytes_read, const char* str, const char* keyword, const ParseFloatFunc parsers[], PropertyFloat* args, int nargs) {
	out_bytes_read = 0;
	int total_bytes_read = 0, bytes_read = 0;

	/* use the quicker stack-based argument buffer, if possible */
	char *arg = 0;
	char arg_stack[1024];
	std::string arg_heap;
	if (strlen(str) < sizeof(arg_stack))
	{
		arg = arg_stack;
	}
	else
	{
		arg_heap = str;
		arg = &arg_heap[0];
	}

	/* skip leading white space */
	bytes_read = 0;
	sscanf(str, " %n", &bytes_read);
	str += bytes_read;
	total_bytes_read += bytes_read;

	/* find the keyword */
	if (!memcmp(str, keyword, strlen(keyword)))
	{
		bytes_read = (int)strlen(keyword);
		str += bytes_read;
		total_bytes_read += bytes_read;
	}
	else
	{
		return false;
	}

	/* skip any white space */
	bytes_read = 0;
	sscanf(str, " %n", &bytes_read);
	str += bytes_read;
	total_bytes_read += bytes_read;

	/* find the opening brace */
	bytes_read = 0;
	if (sscanf(str, " ( %n", &bytes_read), bytes_read)
	{
		str += bytes_read;
		total_bytes_read += bytes_read;
	}
	else
	{
		return false;
	}

	/* parse the arguments */
	for (int i = 0; i < nargs; ++i)
	{
		bytes_read = 0;
		sscanf(str, " %[^,)] %n", arg, &bytes_read);
		if (bytes_read == 0) {
			return false;
		}
		auto prop = parsers[i](std::string(arg));
		if (!prop) {
			return false;
		}

		args[i] = *prop;
		str += bytes_read;
		total_bytes_read += bytes_read;

		/* find the comma */
		if (i < nargs - 1)
		{
			bytes_read = 0;
			if (sscanf(str, " , %n", &bytes_read), bytes_read)
			{
				str += bytes_read;
				total_bytes_read += bytes_read;
			}
			else
			{
				return false;
			}
		}
	}

	/* find the closing brace */
	bytes_read = 0;
	if (sscanf(str, " ) %n", &bytes_read), bytes_read)
	{
		str += bytes_read;
		total_bytes_read += bytes_read;
	}
	else
	{
		return false;
	}

	out_bytes_read = total_bytes_read;
	return total_bytes_read > 0;
}

Property PropertyParseTransform(PropertyId id, const std::string& value) {
	if (value == "none") {
		return { id, Transform {} };
	}

	Transform transform {};

	char const* next = value.c_str();

	PropertyFloat args[16] = {
		{0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER},
		{0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER},
		{0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER},
		{0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER}, {0.f, PropertyUnit::NUMBER},
	};


	while (*next)
	{
		using namespace Transforms;
		int bytes_read = 0;

		if (Scan(bytes_read, next, "perspective", length1, args, 1))
		{
			transform.emplace_back(Perspective {args[0]});
		}
		else if (Scan(bytes_read, next, "matrix", number6, args, 6))
		{
			transform.emplace_back(Matrix2D(glm::mat3x2 {
				{args[0].value, args[1].value},
				{args[2].value, args[3].value},
				{args[4].value, args[5].value},
			}));
		}
		else if (Scan(bytes_read, next, "matrix3d", number16, args, 16))
		{
			transform.emplace_back(Matrix3D(glm::mat4x4 {
				{args[0].value, args[1].value, args[2].value, args[3].value},
				{args[4].value, args[5].value, args[6].value, args[7].value},
				{args[8].value, args[9].value, args[10].value, args[11].value},
				{args[12].value, args[13].value, args[14].value, args[15].value},
			}));
		}
		else if (Scan(bytes_read, next, "translateX", length1, args, 1))
		{
			transform.emplace_back(TranslateX {args[0]});
		}
		else if (Scan(bytes_read, next, "translateY", length1, args, 1))
		{
			transform.emplace_back(TranslateY{ args[0] });
		}
		else if (Scan(bytes_read, next, "translateZ", length1, args, 1))
		{
			transform.emplace_back(TranslateZ{ args[0] });
		}
		else if (Scan(bytes_read, next, "translate", length2, args, 2))
		{
			transform.emplace_back(Translate2D{ args[0], args[1] });
		}
		else if (Scan(bytes_read, next, "translate3d", length3, args, 3))
		{
			transform.emplace_back(Translate3D{ args[0], args[1], args[2] });
		}
		else if (Scan(bytes_read, next, "scaleX", number1, args, 1))
		{
			transform.emplace_back(ScaleX { args[0].value });
		}
		else if (Scan(bytes_read, next, "scaleY", number1, args, 1))
		{
			transform.emplace_back(ScaleY{ args[0].value });
		}
		else if (Scan(bytes_read, next, "scaleZ", number1, args, 1))
		{
			transform.emplace_back(ScaleZ{ args[0].value });
		}
		else if (Scan(bytes_read, next, "scale", number2, args, 2))
		{
			transform.emplace_back(Scale2D{ args[0].value, args[0].value });
		}
		else if (Scan(bytes_read, next, "scale", number1, args, 1))
		{
			args[1] = args[0];
			transform.emplace_back(Scale2D{ args[0].value, args[1].value });
		}
		else if (Scan(bytes_read, next, "scale3d", number3, args, 3))
		{
			transform.emplace_back(Scale3D{ args[0].value, args[1].value, args[2].value });
		}
		else if (Scan(bytes_read, next, "rotateX", angle1, args, 1))
		{
			transform.emplace_back(RotateX { args[0] });
		}
		else if (Scan(bytes_read, next, "rotateY", angle1, args, 1))
		{
			transform.emplace_back(RotateY{ args[0] });
		}
		else if (Scan(bytes_read, next, "rotateZ", angle1, args, 1))
		{
			transform.emplace_back(RotateZ{ args[0] });
		}
		else if (Scan(bytes_read, next, "rotate", angle1, args, 1))
		{
			transform.emplace_back(Rotate2D{ args[0] });
		}
		else if (Scan(bytes_read, next, "rotate3d", number3angle1, args, 4))
		{
			transform.emplace_back(Rotate3D{ {args[0].value, args[1].value, args[2].value}, args[3] });
		}
		else if (Scan(bytes_read, next, "skewX", angle1, args, 1))
		{
			transform.emplace_back(SkewX {args[0]});
		}
		else if (Scan(bytes_read, next, "skewY", angle1, args, 1))
		{
			transform.emplace_back(SkewX{ args[1] });
		}
		else if (Scan(bytes_read, next, "skew", angle2, args, 2))
		{
			transform.emplace_back(Skew2D{ args[0], args[1] });
		}

		if (bytes_read > 0)
		{
			next += bytes_read;
		}
		else
		{
			return {};
		}
	}

	return { id, transform };

}

}
