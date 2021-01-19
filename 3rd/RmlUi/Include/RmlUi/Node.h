#pragma once

#include "Layout.h"
#include <memory>
#include <vector>

namespace Rml {
	class Element;

    class Node {
	public:
		enum class Type {
			Unset,
			Element,
			Text,
		};
		virtual ~Node();
		void SetType(Type type);
		Type GetType();
		bool UpdateMetrics();
		Layout& GetLayout();
		const Layout::Metrics& GetMetrics() const;

		bool IsVisible() const;
		void SetVisible(bool visible);
		void SetParentNode(Element* parent);
		Element* GetParentNode() const;
		void DirtyLayout();

		virtual void OnRender() = 0;
		virtual void OnChange(const PropertyIdSet& properties) = 0;

	protected:
		Type type = Type::Unset;
		Layout layout;
		Layout::Metrics metrics;
		Element* parent = nullptr;
    };
}
