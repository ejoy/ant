/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2018 Michael R. P. Ragazzon
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


#include "PropertyParserAnimation.h"
#include "PropertyShorthandDefinition.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/PropertyIdSet.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/Tween.h"

namespace Rml {

struct Keyword {
	enum Type { NONE, TWEEN, ALL, ALTERNATE, INFINITE, PAUSED } type;
	Tween tween;

	bool ValidTransition() const {
		return type == NONE || type == TWEEN || type == ALL;
	}
	bool ValidAnimation() const {
		return type == NONE || type == TWEEN || type == ALTERNATE || type == INFINITE || type == PAUSED;
	}
};


static const std::unordered_map<std::string, Keyword> keywords = {
	{"none", {Keyword::NONE} },
	{"all", {Keyword::ALL}},
	{"alternate", {Keyword::ALTERNATE}},
	{"infinite", {Keyword::INFINITE}},
	{"paused", {Keyword::PAUSED}},
	{"back-in",            {Keyword::TWEEN, {Tween::Type::Back, Tween::Direction::In}}},
	{"back-out",           {Keyword::TWEEN, {Tween::Type::Back, Tween::Direction::Out}}},
	{"back-in-out",        {Keyword::TWEEN, {Tween::Type::Back, Tween::Direction::InOut}}},
	{"bounce-in",          {Keyword::TWEEN, {Tween::Type::Bounce, Tween::Direction::In}}},
	{"bounce-out",         {Keyword::TWEEN, {Tween::Type::Bounce, Tween::Direction::Out}}},
	{"bounce-in-out",      {Keyword::TWEEN, {Tween::Type::Bounce, Tween::Direction::InOut}}},
	{"circular-in",        {Keyword::TWEEN, {Tween::Type::Circular, Tween::Direction::In}}},
	{"circular-out",       {Keyword::TWEEN, {Tween::Type::Circular, Tween::Direction::Out}}},
	{"circular-in-out",    {Keyword::TWEEN, {Tween::Type::Circular, Tween::Direction::InOut}}},
	{"cubic-in",           {Keyword::TWEEN, {Tween::Type::Cubic, Tween::Direction::In}}},
	{"cubic-out",          {Keyword::TWEEN, {Tween::Type::Cubic, Tween::Direction::Out}}},
	{"cubic-in-out",       {Keyword::TWEEN, {Tween::Type::Cubic, Tween::Direction::InOut}}},
	{"elastic-in",         {Keyword::TWEEN, {Tween::Type::Elastic, Tween::Direction::In}}},
	{"elastic-out",        {Keyword::TWEEN, {Tween::Type::Elastic, Tween::Direction::Out}}},
	{"elastic-in-out",     {Keyword::TWEEN, {Tween::Type::Elastic, Tween::Direction::InOut}}},
	{"exponential-in",     {Keyword::TWEEN, {Tween::Type::Exponential, Tween::Direction::In}}},
	{"exponential-out",    {Keyword::TWEEN, {Tween::Type::Exponential, Tween::Direction::Out}}},
	{"exponential-in-out", {Keyword::TWEEN, {Tween::Type::Exponential, Tween::Direction::InOut}}},
	{"linear-in",          {Keyword::TWEEN, {Tween::Type::Linear, Tween::Direction::In}}},
	{"linear-out",         {Keyword::TWEEN, {Tween::Type::Linear, Tween::Direction::Out}}},
	{"linear-in-out",      {Keyword::TWEEN, {Tween::Type::Linear, Tween::Direction::InOut}}},
	{"quadratic-in",       {Keyword::TWEEN, {Tween::Type::Quadratic, Tween::Direction::In}}},
	{"quadratic-out",      {Keyword::TWEEN, {Tween::Type::Quadratic, Tween::Direction::Out}}},
	{"quadratic-in-out",   {Keyword::TWEEN, {Tween::Type::Quadratic, Tween::Direction::InOut}}},
	{"quartic-in",         {Keyword::TWEEN, {Tween::Type::Quartic, Tween::Direction::In}}},
	{"quartic-out",        {Keyword::TWEEN, {Tween::Type::Quartic, Tween::Direction::Out}}},
	{"quartic-in-out",     {Keyword::TWEEN, {Tween::Type::Quartic, Tween::Direction::InOut}}},
	{"quintic-in",         {Keyword::TWEEN, {Tween::Type::Quintic, Tween::Direction::In}}},
	{"quintic-out",        {Keyword::TWEEN, {Tween::Type::Quintic, Tween::Direction::Out}}},
	{"quintic-in-out",     {Keyword::TWEEN, {Tween::Type::Quintic, Tween::Direction::InOut}}},
	{"sine-in",            {Keyword::TWEEN, {Tween::Type::Sine, Tween::Direction::In}}},
	{"sine-out",           {Keyword::TWEEN, {Tween::Type::Sine, Tween::Direction::Out}}},
	{"sine-in-out",        {Keyword::TWEEN, {Tween::Type::Sine, Tween::Direction::InOut}}},
};


PropertyParserAnimation::PropertyParserAnimation(Type type) : type(type)
{
}


static bool ParseAnimation(Property & property, const std::vector<std::string>& animation_values)
{
	AnimationList animation_list;

	for (const std::string& single_animation_value : animation_values)
	{
		Animation animation;

		std::vector<std::string> arguments;
		StringUtilities::ExpandString(arguments, single_animation_value, ' ');

		bool duration_found = false;
		bool delay_found = false;
		bool num_iterations_found = false;

		for (auto& argument : arguments)
		{
			if (argument.empty())
				continue;

			// See if we have a <keyword> or <tween> specifier as defined in keywords
			auto it = keywords.find(argument); 
			if (it != keywords.end() && it->second.ValidAnimation())
			{
				switch (it->second.type)
				{
				case Keyword::NONE:
				{
					if (animation_list.size() > 0) // The none keyword can not be part of multiple definitions
						return false;
					property = Property{ AnimationList{}, Property::Unit::ANIMATION };
					return true;
				}
				break;
				case Keyword::TWEEN:
					animation.tween = it->second.tween;
					break;
				case Keyword::ALTERNATE:
					animation.alternate = true;
					break;
				case Keyword::INFINITE:
					if (num_iterations_found)
						return false;
					animation.num_iterations = -1;
					num_iterations_found = true;
					break;
				case Keyword::PAUSED:
					animation.paused = true;
					break;
				default:
					break;
				}
			}
			else
			{
				// Either <duration>, <delay>, <num_iterations> or a <keyframes-name>
				float number = 0.0f;
				int count = 0;

				if (sscanf(argument.c_str(), "%fs%n", &number, &count) == 1)
				{
					// Found a number, if there was an 's' unit, count will be positive
					if (count > 0)
					{
						// Duration or delay was assigned
						if (!duration_found)
						{
							duration_found = true;
							animation.duration = number;
						}
						else if (!delay_found)
						{
							delay_found = true;
							animation.delay = number;
						}
						else
							return false;
					}
					else
					{
						// No 's' unit means num_iterations was found
						if (!num_iterations_found)
						{
							animation.num_iterations = (int)(number + 0.5f);
							num_iterations_found = true;
						}
						else
							return false;
					}
				}
				else
				{
					// Must be an animation name
					animation.name = argument;
				}
			}
		}

		// Validate the parsed transition
		if (animation.name.empty() || animation.duration <= 0.0f || (animation.num_iterations < -1 || animation.num_iterations == 0))
		{
			return false;
		}

		animation_list.push_back(std::move(animation));
	}

	property.value = std::move(animation_list);
	property.unit = Property::Unit::ANIMATION;

	return true;
}


static bool ParseTransition(Property & property, const std::vector<std::string>& transition_values)
{
	TransitionList transition_list{ false, false, {} };

	for (const std::string& single_transition_value : transition_values)
	{

		Transition transition;
		PropertyIdSet target_property_names;

		std::vector<std::string> arguments;
		StringUtilities::ExpandString(arguments, single_transition_value, ' ');


		bool duration_found = false;
		bool delay_found = false;
		bool reverse_adjustment_factor_found = false;

		for (auto& argument : arguments)
		{
			if (argument.empty())
				continue;

			// See if we have a <keyword> or <tween> specifier as defined in keywords
			auto it = keywords.find(argument);
			if (it != keywords.end() && it->second.ValidTransition())
			{
				if (it->second.type == Keyword::NONE)
				{
					if (transition_list.transitions.size() > 0) // The none keyword can not be part of multiple definitions
						return false;
					property = Property{ TransitionList{true, false, {}}, Property::Unit::TRANSITION };
					return true;
				}
				else if (it->second.type == Keyword::ALL)
				{
					if (transition_list.transitions.size() > 0) // The all keyword can not be part of multiple definitions
						return false;
					transition_list.all = true;
				}
				else if (it->second.type == Keyword::TWEEN)
				{
					transition.tween = it->second.tween;
				}
			}
			else
			{
				// Either <duration>, <delay> or a <property name>
				float number = 0.0f;
				int count = 0;

				if (sscanf(argument.c_str(), "%fs%n", &number, &count) == 1)
				{
					// Found a number, if there was an 's' unit, count will be positive
					if (count > 0)
					{
						// Duration or delay was assigned
						if (!duration_found)
						{
							duration_found = true;
							transition.duration = number;
						}
						else if (!delay_found)
						{
							delay_found = true;
							transition.delay = number;
						}
						else
							return false;
					}
					else
					{
						// No 's' unit means reverse adjustment factor was found
						if (!reverse_adjustment_factor_found)
						{
							reverse_adjustment_factor_found = true;
							transition.reverse_adjustment_factor = number;
						}
						else
							return false;
					}
				}
				else
				{
					PropertyIdSet properties;
					if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, argument)) {
						return false;
					}
					target_property_names |= properties;
				}
			}
		}

		// Validate the parsed transition
		if (transition.duration <= 0.0f || transition.reverse_adjustment_factor < 0.0f || transition.reverse_adjustment_factor > 1.0f) {
			return false;
		}

		if (transition_list.all) {
			if (!target_property_names.Empty()) {
				return false;
			}
			transition_list.transitions.push_back(transition);
		}
		else {
			if (target_property_names.Empty()) {
				return false;
			}
			for (const auto& property_name : target_property_names) {
				transition.id = property_name;
				transition_list.transitions.push_back(transition);
			}
		}
	}

	property.value = std::move(transition_list);
	property.unit = Property::Unit::TRANSITION;

	return true;
}


bool PropertyParserAnimation::ParseValue(Property & property, const std::string & value, const ParameterMap & /*parameters*/) const
{
	std::vector<std::string> list_of_values;
	{
		auto lowercase_value = StringUtilities::ToLower(value);
		StringUtilities::ExpandString(list_of_values, lowercase_value, ',');
	}

	bool result = false;

	if (type == ANIMATION_PARSER)
	{
		result = ParseAnimation(property, list_of_values);
	}
	else if (type == TRANSITION_PARSER)
	{
		result = ParseTransition(property, list_of_values);
	}

	return result;
}

}
