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

#ifndef RMLUI_CORE_MATH_H
#define RMLUI_CORE_MATH_H

#include "Header.h"

namespace Rml {


namespace Math {

// The constant PI.
extern RMLUICORE_API const float RMLUI_PI;

template < typename Type >
Type Max(Type a, Type b)
{
	return (a > b) ? a : b;
}

template< typename Type >
Type Min(Type a, Type b)
{
	return (a < b) ? a : b;
}

template < typename Type >
Type ClampLower(Type value, Type min)
{
	return (value < min) ? min : value;
}

template < typename Type >
Type ClampUpper(Type value, Type max)
{
	return (value > max) ? max: value;
}

template< typename Type >
Type Clamp(Type value, Type min, Type max)
{
	return (value < min) ? min : (value > max) ? max : value;
}

/// Calculates the cosine of an angle.
/// @param[in] angle The angle to calculate the cosine of, in radians.
/// @return The cosine of the angle.
RMLUICORE_API float Cos(float angle);
/// Calculates the sine of an angle.
/// @param[in] angle The angle to calculate the sine of, in radians.
/// @return The sine of the angle.
RMLUICORE_API float Sin(float angle);
/// Evaluates the natural exponential function on a value.
/// @param[in] value The value
/// @return e^(value)
RMLUICORE_API float Exp(float value);

/// Converts an angle from degrees to radians.
/// @param[in] The angle, in degrees.
/// @return The angle converted to radians.
RMLUICORE_API float DegreesToRadians(float angle);

/// Calculates the square root of a value.
/// @param[in] value The value to calculate the square root of. This must be above zero.
/// @return The square root of the value.
RMLUICORE_API float SquareRoot(float value);

/// Rounds a floating-point value to the nearest integer.
/// @param[in] value The value to round.
/// @return The rounded integer.
RMLUICORE_API int RoundToInteger(float value);

/// Efficiently truncates a floating-point value into an integer.
/// @param[in] value The value to truncate.
/// @return The truncated value as a signed integer.
RMLUICORE_API int RealToInteger(float value);

/// Converts from the ASCII-representation of a hexadecimal digit to decimal.
/// @param[in] hex_digit The hexadecimal digit to convert to decimal.
/// @return The digit in decimal.
RMLUICORE_API int HexToDecimal(char hex_digit);


}
} // namespace Rml
#endif
