#include <css/StyleSheetNode.h>
#include <core/Element.h>
#include <css/StyleSheetNodeSelector.h>
#include <css/StyleCache.h>
#include <util/StringUtilities.h>
#include <bee/nonstd/charconv.h>
#include <algorithm>
#include <bit>

namespace Rml {

template <typename T>
static T Str2I(std::string_view s) {
	T v;
	if (auto [p, ec] = std::from_chars(s.data(), s.data() + s.size(), v); ec != std::errc()) {
		return v;
	}
	return {};
}

static StructuralSelector GetSelector(std::string_view name) {
	const size_t parameter_start = name.find('(');
	auto func = (parameter_start == std::string_view::npos)
			? CreateSelector(name)
			: CreateSelector(name.substr(0, parameter_start))
			;
	if (!func)
		return StructuralSelector(nullptr, 0, 0);

	// Parse the 'a' and 'b' values.
	int a = 1;
	int b = 0;

	const size_t parameter_end = name.find(')', parameter_start + 1);
	if (parameter_start != std::string_view::npos && parameter_end != std::string_view::npos) {
		std::string_view parameters = StringUtilities::StripWhitespace(name.substr(parameter_start + 1, parameter_end - (parameter_start + 1)));

		// Check for 'even' or 'odd' first.
		if (parameters == "even") {
			a = 2;
			b = 0;
		}
		else if (parameters == "odd") {
			a = 2;
			b = 1;
		}
		else {
			// Alrighty; we've got an equation in the form of [[+/-]an][(+/-)b]. So, foist up, we split on 'n'.
			const size_t n_index = parameters.find('n');
			if (n_index == std::string_view::npos) {
				// The equation is 0n + b. So a = 0, and we only have to parse b.
				a = 0;
				b = Str2I<uint16_t>(parameters);
			}
			else {
				if (n_index == 0)
					a = 1;
				else {
					std::string_view a_parameter = parameters.substr(0, n_index);
					if (StringUtilities::StripWhitespace(a_parameter) == "-")
						a = -1;
					else
						a = Str2I<uint16_t>(a_parameter);
				}

				size_t pm_index = parameters.find('+', n_index + 1);
				if (pm_index != std::string_view::npos)
					b = 1;
				else {
					pm_index = parameters.find('-', n_index + 1);
					if (pm_index != std::string_view::npos)
						b = -1;
				}

				if (n_index == parameters.size() - 1 || pm_index == std::string_view::npos)
					b = 0;
				else
					b = b * atoi(parameters.data() + pm_index + 1);
			}
		}
	}

	return StructuralSelector(func, a, b);
}

StyleSheetRequirements::StyleSheetRequirements(const std::string& name) {
	std::vector<std::string> pseudo_strs;

	size_t index = 0;
	while (index < name.size()) {
		size_t start_index = index;
		size_t end_index = index + 1;

		// Read until we hit the next identifier.
		while (end_index < name.size() &&
				name[end_index] != '#' &&
				name[end_index] != '.' &&
				name[end_index] != ':' &&
				name[end_index] != '>')
			end_index++;

		std::string identifier = name.substr(start_index, end_index - start_index);
		if (!identifier.empty()) {
			switch (identifier[0]) {
				case '#':	id = identifier.substr(1); break;
				case '.':	class_names.push_back(identifier.substr(1)); break;
				case ':': {
					std::string pseudo_class_name = identifier.substr(1);
					StructuralSelector node_selector = GetSelector(pseudo_class_name);
					if (node_selector.selector)
						structural_selectors.push_back(node_selector);
					else
						pseudo_strs.push_back(pseudo_class_name);
				}
				break;
				case '>':	child_combinator = true; break;
				default:	if(identifier != "*") tag = identifier;
			}
		}
		index = end_index;
	}

	std::sort(class_names.begin(), class_names.end());
	std::sort(structural_selectors.begin(), structural_selectors.end());

	pseudo_classes = 0;
	for (auto& name : pseudo_strs) {
		if (name == "active") {
			pseudo_classes = pseudo_classes | PseudoClass::Active;
		}
		else if (name == "hover") {
			pseudo_classes = pseudo_classes | PseudoClass::Hover;
		}
	}
}

bool StyleSheetRequirements::operator==(const StyleSheetRequirements& rhs) const {
	if (tag != rhs.tag)
		return false;
	if (id != rhs.id)
		return false;
	if (class_names != rhs.class_names)
		return false;
	if (pseudo_classes != rhs.pseudo_classes)
		return false;
	if (structural_selectors != rhs.structural_selectors)
		return false;
	if (child_combinator != rhs.child_combinator)
		return false;
	return true;
}

bool StyleSheetRequirements::Match(const Element* element) const {
	if (!tag.empty() && tag != element->GetTagName())
		return false;
	if (!id.empty() && id != element->GetId())
		return false;
	for (auto& name : class_names) 	{
		if (!element->IsClassSet(name))
			return false;
	}
	return element->IsPseudoClassSet(pseudo_classes);
}

bool StyleSheetRequirements::MatchStructuralSelector(const Element* element) const {
	for (auto& node_selector : structural_selectors) {
		if (!node_selector.selector(element, node_selector.a, node_selector.b))
			return false;
	}
	return true;
}

int StyleSheetRequirements::GetSpecificity() const {
	int specificity = 0;
	if (!tag.empty())
		specificity += 10'000;
	if (!id.empty())
		specificity += 1'000'000;
	specificity += 100'000*(int)class_names.size();
	specificity += 100'000*(int)std::popcount(pseudo_classes);
	specificity += 100'000*(int)structural_selectors.size();
	return specificity;
}

StyleSheetNode::StyleSheetNode(const std::string& rule_name, const Style::TableRef& props)
	: properties(props) {
	ImportRequirements(rule_name);
}

int StyleSheetNode::GetSpecificity() const {
	return specificity;
}

void StyleSheetNode::SetSpecificity(int rule_specificity) {
	specificity = rule_specificity;
	for (auto const& req : requirements) {
		specificity += req.GetSpecificity();
	}
}

bool StyleSheetNode::IsApplicable(const Element* const in_element) const {
	if (!requirements[0].Match(in_element))
		return false;
	const Element* element = in_element;
	// Walk up through all our parent nodes, each one of them must be matched by some ancestor element.
	for (size_t i = 1; i < requirements.size(); ++i) {
		auto const& req = requirements[i];
		// Try a match on every element ancestor. If it succeeds, we continue on to the next node.
		for (element = element->GetParentNode(); element; element = element->GetParentNode()) {
			if (req.Match(element) && req.MatchStructuralSelector(element))
				break;
			// If we have a child combinator on the node, we must match this first ancestor.
			else if (req.child_combinator)
				return false;
		}
		// We have run out of element ancestors before we matched every node. Bail out.
		if (!element)
			return false;
	}
	return requirements[0].MatchStructuralSelector(in_element);
}

const Style::TableRef& StyleSheetNode::GetProperties() const {
	return properties;
}

void StyleSheetNode::ImportRequirements(std::string rule_name) {

	// Find child combinators, the RCSS '>' rule.
	size_t i_child = rule_name.find('>');
	while (i_child != std::string::npos) {
		// So we found one! Next, we want to format the rule such that the '>' is located at the 
		// end of the left-hand-side node, and that there is a space to the right-hand-side. This ensures that
		// the selector is applied to the "parent", and that parent and child are expanded properly below.
		size_t i_begin = i_child;
		while (i_begin > 0 && rule_name[i_begin - 1] == ' ')
			i_begin--;

		const size_t i_end = i_child + 1;
		rule_name.replace(i_begin, i_end - i_begin, "> ");
		i_child = rule_name.find('>', i_begin + 1);
	}

	// Expand each individual node separated by spaces. Don't expand inside parenthesis because of structural selectors.
	int quote_mode_depth = 0;
	const char* ptr = rule_name.c_str();
	const char* start_ptr = nullptr;
	const char* end_ptr = ptr;

	while (*ptr) {
		// Increment the quote depth for each quote character encountered
		if (*ptr == '(') {
			++quote_mode_depth;
		}
		// And decrement it for every unquote character
		else if (*ptr == ')') {
			--quote_mode_depth;
		}

		// If we encounter a delimiter while not in quote mode, add the item to the list
		if (*ptr == ' ' && quote_mode_depth == 0) {
			if (start_ptr)
				requirements.emplace_back(std::string(start_ptr, end_ptr + 1));
			start_ptr = nullptr;
		}
		// Otherwise if its not white space or we're in quote mode, advance the pointers
		else if (!StringUtilities::IsWhitespace(*ptr) || quote_mode_depth > 0) {
			if (!start_ptr)
				start_ptr = ptr;
			end_ptr = ptr;
		}

		ptr++;
	}

	// If there's data pending, add it.
	if (start_ptr) {
		requirements.emplace_back(std::string(start_ptr, end_ptr + 1));
	}
}

}
