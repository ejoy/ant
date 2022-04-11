#pragma once

#include <core/Element.h>

namespace Rml {
	class ElementDocument : public Element {
	public:
		ElementDocument(Document* owner);
	protected:
		void ChangedProperties(const PropertyIdSet& changed_properties) override;
	};
}
