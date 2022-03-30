#pragma once

#include "Layout.h"
#include <memory>
#include <vector>

namespace Rml {
	class DataModel;
	class Element;

    class Node {
	public:
		enum class Type {
			Text,
			Element,
		};
		Node(Type type);
		virtual ~Node();
		bool UpdateVisible();
		void UpdateMetrics(const Rect& child);
		Layout& GetLayout();
		const Layout::Metrics& GetMetrics() const;

		bool IsVisible() const;
		void SetVisible(bool visible);
		void DirtyLayout();
		Element* GetParentNode() const;
		DataModel* GetDataModel() const;
		Type GetType() const;

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

	protected:
		Layout layout;
		Layout::Metrics metrics;
		Element* parent = nullptr;
		DataModel* data_model = nullptr;
		Type type;
    };
}
