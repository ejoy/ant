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

#include "../Include/RmlUi/Math.h"
#include "../Include/RmlUi/Types.h"
#include <time.h>
#include <math.h>
#include <stdlib.h>

namespace Rml {

namespace Math {

const float RMLUI_PI = 3.141592653f;

static constexpr float FZERO = 0.0001f;

// Calculates the absolute value of a number.
RMLUICORE_API float AbsoluteValue(float value)
{
	return fabsf(value);
}

// Calculates the cosine of an angle.
RMLUICORE_API float Cos(float angle)
{
	return cosf(angle);
}

// Calculates the arc-cosine of an value.
RMLUICORE_API float ACos(float value)
{
	return acosf(value);
}

// Calculates the sine of an angle.
RMLUICORE_API float Sin(float angle)
{
	return sinf(angle);
}

// Calculates the arc-sine of an value.
RMLUICORE_API float ASin(float angle)
{
	return asinf(angle);
}

// Calculates the tangent of an angle.
RMLUICORE_API float Tan(float angle)
{
	return tanf(angle);
}

// Calculates the angle of a two-dimensional line.
RMLUICORE_API float ATan2(float y, float x)
{
	return atan2f(y, x);
}

// Evaluates the natural exponential function on a value.
RMLUICORE_API float Exp(float value)
{
	return expf(value);
}

// Converts an angle from radians to degrees.
RMLUICORE_API float RadiansToDegrees(float angle)
{
	return angle * (180.0f / RMLUI_PI);
}

// Converts an angle from degrees to radians.
RMLUICORE_API float DegreesToRadians(float angle)
{
	return angle * (RMLUI_PI / 180.0f);
}

// Calculates the square root of a value.
RMLUICORE_API float SquareRoot(float value)
{
	return sqrtf(value);
}

// Rounds a floating-point value to the nearest integer.
RMLUICORE_API int RoundToInteger(float value)
{
	if (value > 0.0f)
		return RealToInteger(value + 0.5f);

	return RealToInteger(value - 0.5f);
}

// Efficiently truncates a floating-point value into an integer.
RMLUICORE_API int RealToInteger(float value)
{
	return int(value);
}

// Converts from a hexadecimal digit to decimal.
RMLUICORE_API int HexToDecimal(char hex_digit)
{
	if (hex_digit >= '0' && hex_digit <= '9')
		return hex_digit - '0';
	else if (hex_digit >= 'a' && hex_digit <= 'f')
		return 10 + (hex_digit - 'a');
	else if (hex_digit >= 'A' && hex_digit <= 'F')
		return 10 + (hex_digit - 'A');

	return -1;
}

}
} // namespace Rml
