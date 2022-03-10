#include "../Include/RmlUi/ElementDocument.h"
#include "../Include/RmlUi/PropertyIdSet.h"

namespace Rml {
	ElementDocument::ElementDocument(Document* owner)
		: Element(owner, "body")
	{ }

	void ElementDocument::OnChange(const PropertyIdSet& changed_properties) {
		Element::OnChange(changed_properties);
		// If the document's font-size has been changed, we need to dirty all rem properties.
		if (changed_properties.Contains(PropertyId::FontSize))
			GetStyle()->DirtyPropertiesWithUnitRecursive(Property::REM);
	}
}
