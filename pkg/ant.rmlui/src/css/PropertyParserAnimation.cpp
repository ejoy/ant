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
	{"back",               {Keyword::TWEEN, Tween::BackIn}},
	{"back-in",            {Keyword::TWEEN, Tween::BackIn}},
	{"back-out",           {Keyword::TWEEN, Tween::BackOut}},
	{"back-in-out",        {Keyword::TWEEN, Tween::BackInOut}},
	{"bounce",             {Keyword::TWEEN, Tween::BounceIn}},
	{"bounce-in",          {Keyword::TWEEN, Tween::BounceIn}},
	{"bounce-out",         {Keyword::TWEEN, Tween::BounceOut}},
	{"bounce-in-out",      {Keyword::TWEEN, Tween::BounceInOut}},
	{"circular",           {Keyword::TWEEN, Tween::CircularIn}},
	{"circular-in",        {Keyword::TWEEN, Tween::CircularIn}},
	{"circular-out",       {Keyword::TWEEN, Tween::CircularOut}},
	{"circular-in-out",    {Keyword::TWEEN, Tween::CircularInOut}},
	{"cubic",              {Keyword::TWEEN, Tween::CubicIn}},
	{"cubic-in",           {Keyword::TWEEN, Tween::CubicIn}},
	{"cubic-out",          {Keyword::TWEEN, Tween::CubicOut}},
	{"cubic-in-out",       {Keyword::TWEEN, Tween::CubicInOut}},
	{"elastic",            {Keyword::TWEEN, Tween::ElasticIn}},
	{"elastic-in",         {Keyword::TWEEN, Tween::ElasticIn}},
	{"elastic-out",        {Keyword::TWEEN, Tween::ElasticOut}},
	{"elastic-in-out",     {Keyword::TWEEN, Tween::ElasticInOut}},
	{"exponential",        {Keyword::TWEEN, Tween::ExponentialIn}},
	{"exponential-in",     {Keyword::TWEEN, Tween::ExponentialIn}},
	{"exponential-out",    {Keyword::TWEEN, Tween::ExponentialOut}},
	{"exponential-in-out", {Keyword::TWEEN, Tween::ExponentialInOut}},
	{"linear",             {Keyword::TWEEN, Tween::LinearIn}},
	{"linear-in",          {Keyword::TWEEN, Tween::LinearIn}},
	{"linear-out",         {Keyword::TWEEN, Tween::LinearOut}},
	{"linear-in-out",      {Keyword::TWEEN, Tween::LinearInOut}},
	{"quadratic",          {Keyword::TWEEN, Tween::QuadraticIn}},
	{"quadratic-in",       {Keyword::TWEEN, Tween::QuadraticIn}},
	{"quadratic-out",      {Keyword::TWEEN, Tween::QuadraticOut}},
	{"quadratic-in-out",   {Keyword::TWEEN, Tween::QuadraticInOut}},
	{"quartic",            {Keyword::TWEEN, Tween::QuarticIn}},
	{"quartic-in",         {Keyword::TWEEN, Tween::QuarticIn}},
	{"quartic-out",        {Keyword::TWEEN, Tween::QuarticOut}},
	{"quartic-in-out",     {Keyword::TWEEN, Tween::QuarticInOut}},
	{"quintic",            {Keyword::TWEEN, Tween::QuinticIn}},
	{"quintic-in",         {Keyword::TWEEN, Tween::QuinticIn}},
	{"quintic-out",        {Keyword::TWEEN, Tween::QuinticOut}},
	{"quintic-in-out",     {Keyword::TWEEN, Tween::QuinticInOut}},
	{"sine",               {Keyword::TWEEN, Tween::SineIn}},
	{"sine-in",            {Keyword::TWEEN, Tween::SineIn}},
	{"sine-out",           {Keyword::TWEEN, Tween::SineOut}},
	{"sine-in-out",        {Keyword::TWEEN, Tween::SineInOut}},
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
