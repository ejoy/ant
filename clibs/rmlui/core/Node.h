#pragma once

#include <core/Layout.h>
#include <memory>
#include <vector>

namespace Rml {
	class DataModel;
	class Element;

    class Node {
	public:
		enum class Type : uint8_t {
			Text = 0,
			Element,
		};
		Node(Type type);
		virtual ~Node();
		void UpdateLayout();
		Layout& GetLayout();
		const Layout& GetLayout() const;

		bool IsVisible() const;
		void SetVisible(bool visible);
		void DirtyLayout();

		Element* GetParentNode() const;
		DataModel* GetDataModel() const;
		Type GetType() const;

		const Rect& GetBounds() const;

		virtual void SetParentNode(Element* parent) = 0;
		virtual void SetDataModel(DataModel* data_model) = 0;
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
		DataModel* data_model = nullptr;
	private:
		Rect bounds;
		Type type;
		bool visible = true;
	};
}
