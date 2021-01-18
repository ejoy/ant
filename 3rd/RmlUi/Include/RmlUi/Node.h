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
		void SetType(Type type);
		Type GetType();
		bool UpdateMetrics();
		Layout& GetLayout();
		const Layout::Metrics& GetMetrics() const;

		bool IsVisible() const;
		void SetVisible(bool visible);
		void SetParentNode(Element* parent);
		bool DirtyOffset();
		const Point& GetOffset();

	private:
		Type type = Type::Unset;
		Layout layout;
		Layout::Metrics metrics;
		Element* parent = nullptr;
		Point offset;
		bool dirty_offset = false;
    };
}
