#pragma once

#include <core/Layout.h>
#include <memory>
#include <vector>

namespace Rml {
	class Element;

    class Node {
	public:
		Node(Layout::UseElement);
		Node(Layout::UseText, void* context);
		virtual ~Node();
		void UpdateLayout();
		Layout& GetLayout();
		const Layout& GetLayout() const;

		bool IsVisible() const;
		void SetVisible(bool visible);
		void DirtyLayout();

		Element* GetParentNode() const;
		Layout::Type GetType() const;

		const Rect& GetBounds() const;

		void ResetParentNode();

		virtual void SetParentNode(Element* parent) = 0;
		virtual Node* Clone(bool deep = true) const = 0;
		virtual void CalculateLayout() = 0;
		virtual void Render() = 0;
		virtual float GetZIndex() const = 0;
		virtual Element* ElementFromPoint(Point point) = 0;
		virtual std::string GetInnerHTML() const = 0;
		virtual std::string GetOuterHTML() const = 0;
		virtual void SetInnerHTML(const std::string& html) = 0;
		virtual void SetOuterHTML(const std::string& html) = 0;
		virtual const Rect& GetContentRect() const = 0;

	private:
		Layout layout;
	protected:
		Element* parent = nullptr;
	private:
		Rect bounds;
		bool visible = true;
	};
}
