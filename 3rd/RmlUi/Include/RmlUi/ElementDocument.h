#pragma once

#include "Element.h"

namespace Rml {
	class ElementDocument : public Element {
	public:
		ElementDocument(Document* owner);
	protected:
		void OnChange(const PropertyIdSet& changed_properties) override;
	};
}
