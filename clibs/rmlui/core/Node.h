#pragma once

#include "Layout.h"
#include <memory>
#include <vector>
#include <glm/glm.hpp>

namespace Rml {
	class Element;

    class Node {
	public:
		virtual ~Node();
		bool UpdateVisible();
		void UpdateMetrics(const Rect& child);
		Layout& GetLayout();
		const Layout::Metrics& GetMetrics() const;

		bool IsVisible() const;
		void SetVisible(bool visible);
		void SetParentNode(Element* parent);
		Element* GetParentNode() const;
		void DirtyLayout();

		virtual void Render() = 0;
		virtual void OnChange(const PropertyIdSet& properties) = 0;

	protected:
		Layout layout;
		Layout::Metrics metrics;
		Element* parent = nullptr;
    };
}
