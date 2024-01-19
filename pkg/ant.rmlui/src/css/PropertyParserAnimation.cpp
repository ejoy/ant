#include <css/PropertyParserAnimation.h>
#include <css/PropertyIdSet.h>
#include <util/StringUtilities.h>
#include <css/StyleSheetSpecification.h>
#include <core/Tween.h>
#include <unordered_map>

namespace Rml {

struct Keyword {
	enum Type { NONE, TWEEN, ALL, ALTERNATE, INFINITE } type;
	Tween tween;

	bool ValidTransition() const {
		return type == NONE || type == TWEEN || type == ALL;
	}
	bool ValidAnimation() const {
		return type == NONE || type == TWEEN || type == ALTERNATE || type == INFINITE;
	}
};

static const std::unordered_map<std::string, Keyword> keywords = {
	{"none", {Keyword::NONE} },
	{"all", {Keyword::ALL}},
	{"alternate", {Keyword::ALTERNATE}},
	{"infinite", {Keyword::INFINITE}},
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

Property PropertyParseAnimation(PropertyId id, const std::string& value) {
	Animation animation;
	std::vector<std::string> arguments;
	StringUtilities::ExpandString(arguments, value, ' ');

	bool duration_found = false;
	bool delay_found = false;
	bool num_iterations_found = false;

	for (auto& argument : arguments) {
		if (argument.empty())
			continue;

		// See if we have a <keyword> or <tween> specifier as defined in keywords
		auto it = keywords.find(argument); 
		if (it != keywords.end() && it->second.ValidAnimation()) {
			switch (it->second.type) {
			case Keyword::NONE:
				return {};
			case Keyword::TWEEN:
				animation.transition.tween = it->second.tween;
				break;
			case Keyword::ALTERNATE:
				animation.alternate = true;
				break;
			case Keyword::INFINITE:
				if (num_iterations_found)
					return {};
				animation.num_iterations = -1;
				num_iterations_found = true;
				break;
			default:
				break;
			}
		}
		else {
			// Either <duration>, <delay>, <num_iterations> or a <keyframes-name>
			float number = 0.0f;
			int count = 0;

			if (sscanf(argument.c_str(), "%fs%n", &number, &count) == 1) {
				// Found a number, if there was an 's' unit, count will be positive
				if (count > 0) {
					// Duration or delay was assigned
					if (!duration_found) {
						duration_found = true;
						animation.transition.duration = number;
					}
					else if (!delay_found) {
						delay_found = true;
						animation.transition.delay = number;
					}
					else
						return false;
				}
				else {
					// No 's' unit means num_iterations was found
					if (!num_iterations_found) {
						animation.num_iterations = (int)(number + 0.5f);
						num_iterations_found = true;
					}
					else
						return false;
				}
			}
			else {
				// Must be an animation name
				animation.name = argument;
			}
		}
	}

	// Validate the parsed transition
	if (animation.name.empty() || (animation.num_iterations < -1 || animation.num_iterations == 0)) {
		return {};
	}

	return { id, animation };
}

Property PropertyParseTransition(PropertyId id, const std::string& value) {
	std::vector<std::string> transition_values;
	StringUtilities::ExpandString(transition_values, value, ',');

	TransitionList transition_list;

	for (const std::string& single_transition_value : transition_values) {
		Transition transition;
		PropertyIdSet target_property_ids;

		std::vector<std::string> arguments;
		StringUtilities::ExpandString(arguments, single_transition_value, ' ');

		bool duration_found = false;
		bool delay_found = false;

		for (auto& argument : arguments) {
			if (argument.empty())
				continue;

			// See if we have a <keyword> or <tween> specifier as defined in keywords
			auto it = keywords.find(argument);
			if (it != keywords.end() && it->second.ValidTransition()) {
				if (it->second.type == Keyword::NONE) {
					if (transition_list.size() > 0) // The none keyword can not be part of multiple definitions
						return {};
					return { id, transition_list };
				}
				else if (it->second.type == Keyword::TWEEN) {
					transition.tween = it->second.tween;
				}
			}
			else {
				// Either <duration>, <delay> or a <property name>
				float number = 0.0f;
				int count = 0;

				if (sscanf(argument.c_str(), "%fs%n", &number, &count) == 1) {
					// Found a number, if there was an 's' unit, count will be positive
					if (count > 0) {
						// Duration or delay was assigned
						if (!duration_found) {
							duration_found = true;
							transition.duration = number;
						}
						else if (!delay_found) {
							delay_found = true;
							transition.delay = number;
						}
						else
							return {};
					}
					else {
						return {};
					}
				}
				else {
					PropertyIdSet properties;
					if (!StyleSheetSpecification::ParseDeclaration(properties, argument)) {
						return {};
					}
					target_property_ids |= properties;
				}
			}
		}

		// Validate the parsed transition
		if (transition.duration <= 0.0f) {
			return {};
		}

		if (target_property_ids.empty()) {
			return {};
		}
		for (const auto& id : target_property_ids) {
			transition_list.emplace(id, transition);
		}
	}

	return { id, transition_list };
}

}
