#include <core/ElementDocument.h>
#include <core/PropertyIdSet.h>

namespace Rml {
	ElementDocument::ElementDocument(Document* owner)
		: Element(owner, "body")
	{ }

	void ElementDocument::ChangedProperties(const PropertyIdSet& changed_properties) {
		Element::ChangedProperties(changed_properties);
		// If the document's font-size has been changed, we need to dirty all rem properties.
		if (changed_properties.contains(PropertyId::FontSize)) {
			DirtyPropertiesWithUnitRecursive(PropertyUnit::REM);
		}
	}
}
