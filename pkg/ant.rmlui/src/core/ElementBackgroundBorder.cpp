#include <core/ElementBackground.h>
#include <core/Layout.h>
#include <core/ComputedValues.h>
#include <core/Element.h>

namespace Rml {

static const auto PI = acosf(-1);

void ElementBackground::GenerateBorderGeometry(Element* element, Geometry& geometry, Box& edge) {
	EdgeInsets<Color> border_color {
		element->GetComputedProperty(PropertyId::BorderLeftColor).Get<Color>(),
		element->GetComputedProperty(PropertyId::BorderTopColor).Get<Color>(),
		element->GetComputedProperty(PropertyId::BorderRightColor).Get<Color>(),
		element->GetComputedProperty(PropertyId::BorderBottomColor).Get<Color>(),
	};
	CornerInsets<float> border_radius {
		element->GetComputedProperty(PropertyId::BorderTopLeftRadius).Get<PropertyFloat>().ComputeW(element),
		element->GetComputedProperty(PropertyId::BorderTopRightRadius).Get<PropertyFloat>().ComputeH(element),
		element->GetComputedProperty(PropertyId::BorderBottomRightRadius).Get<PropertyFloat>().ComputeW(element),
		element->GetComputedProperty(PropertyId::BorderBottomLeftRadius).Get<PropertyFloat>().ComputeH(element),
	};
	Color background_color = element->GetComputedProperty(PropertyId::BackgroundColor).Get<Color>();
	float opacity = element->GetOpacity();
	if (opacity < 1) {
		background_color.ApplyOpacity(opacity);
		for (int i = 0; i < 4; ++i) {
			border_color[i].ApplyOpacity(opacity);
		}
	}
	
	const auto& bounds = element->GetBounds();
	const auto& border = element->GetBorder();
	float outlineWidth = element->GetComputedProperty(PropertyId::OutlineWidth).Get<PropertyFloat>().Compute(element);
	if (outlineWidth > 0.f) {
		Color outlineColor = element->GetComputedProperty(PropertyId::OutlineColor).Get<Color>();
		geometry.AddRect(Rect {Point{}, bounds.size}, outlineWidth, outlineColor);
	}

	bool topLeftInnerRounded     = border.left  < border_radius.topLeft     && border.top    < border_radius.topLeft;
	bool topRightInnerRounded    = border.right < border_radius.topRight    && border.top    < border_radius.topRight;
	bool bottomRightInnerRounded = border.right < border_radius.bottomRight && border.bottom < border_radius.bottomRight;
	bool bottomLeftInnerRounded  = border.left  < border_radius.bottomLeft  && border.bottom < border_radius.bottomLeft;
	auto topLeftInnerRadius = [&](float v) {
		return topLeftInnerRounded ? std::max(v, border_radius.topLeft) : v;
	};
	auto topRightInnerRadius = [&](float v) {
		return topRightInnerRounded ? std::max(v, border_radius.topRight) : v;
	};
	auto bottomRightInnerRadius = [&](float v) {
		return bottomRightInnerRounded ? std::max(v, border_radius.bottomRight) : v;
	};
	auto bottomLeftInnerRadius = [&](float v) {
		return bottomLeftInnerRounded ? std::max(v, border_radius.bottomLeft) : v;
	};

	Quad quadLeft = {
		{ 0, border_radius.topLeft },
		{ border.left, topLeftInnerRadius(border.top) },
		{ border.left, bounds.size.h - bottomLeftInnerRadius(border.bottom) },
		{ 0, bounds.size.h - border_radius.bottomLeft }
	};
	Quad quadTop = {
		{ border_radius.topLeft, 0 },
		{ bounds.size.w - border_radius.topRight, 0 },
		{ bounds.size.w - topRightInnerRadius(border.right), border.top },
		{ topLeftInnerRadius(border.left), border.top },
	};
	Quad quadRight = {
		{ bounds.size.w - border.right,  topRightInnerRadius(border.top) },
		{ bounds.size.w, border_radius.topRight },
		{ bounds.size.w, bounds.size.h - border_radius.bottomRight },
		{ bounds.size.w - border.right, bounds.size.h - bottomRightInnerRadius(border.bottom) },
	};
	Quad quadBottom = {
		{ bottomLeftInnerRadius(border.left), bounds.size.h - border.bottom },
		{ bounds.size.w - bottomRightInnerRadius(border.right), bounds.size.h - border.bottom },
		{ bounds.size.w - border_radius.bottomRight, bounds.size.h },
		{ border_radius.bottomLeft, bounds.size.h },
	};

	geometry.AddQuad(quadLeft, border_color.left);
	Geometry::Path topLeftOuter;
	topLeftOuter.DrawArc(
		{ border_radius.topLeft, border_radius.topLeft },
		border_radius.topLeft,
		border_radius.topLeft,
		PI, PI * 1.5f
	);
	Geometry::Path topLeftInner;
	if (topLeftInnerRounded) {
		topLeftInner.DrawArc(
			{ border_radius.topLeft, border_radius.topLeft },
			border_radius.topLeft - border.left,
			border_radius.topLeft - border.top,
			PI, PI * 1.5f
		);
	}
	else {
		topLeftInner.emplace({
			border.left,
			border.top
		});
	}
	geometry.AddArc(topLeftOuter, topLeftInner, border_color.left);

	geometry.AddQuad(quadTop, border_color.top);
	Geometry::Path topRightOuter;
	topRightOuter.DrawArc(
		{ bounds.size.w - border_radius.topRight, border_radius.topRight },
		border_radius.topRight,
		border_radius.topRight,
		PI * 1.5f, PI * 2.f
	);
	Geometry::Path topRightInner;
	if (topRightInnerRounded) {
		topRightInner.DrawArc(
			{ bounds.size.w - border_radius.topRight, border_radius.topRight },
			border_radius.topRight - border.right,
			border_radius.topRight - border.top,
			PI * 1.5f, PI * 2.f
		);
	}
	else {
		topRightInner.emplace({
			bounds.size.w - border.right,
			border.top
		});
	}
	geometry.AddArc(topRightOuter, topRightInner, border_color.top);

	geometry.AddQuad(quadRight, border_color.right);
	Geometry::Path bottomRightOuter;
	bottomRightOuter.DrawArc(
		{ bounds.size.w - border_radius.bottomRight, bounds.size.h - border_radius.bottomRight },
		border_radius.bottomRight,
		border_radius.bottomRight,
		0, PI * 0.5f
	);
	Geometry::Path bottomRightInner;
	if (bottomRightInnerRounded) {
		bottomRightInner.DrawArc(
			{ bounds.size.w - border_radius.bottomRight, bounds.size.h - border_radius.bottomRight },
			border_radius.bottomRight - border.right,
			border_radius.bottomRight - border.bottom,
			0, PI * 0.5f
		);
	}
	else {
		bottomRightInner.emplace({
			bounds.size.w - border.right,
			bounds.size.h - border.bottom
		});
	}
	geometry.AddArc(bottomRightOuter, bottomRightInner, border_color.right);

	geometry.AddQuad(quadBottom, border_color.bottom);
	Geometry::Path bottomLeftOuter;
	bottomLeftOuter.DrawArc(
		{ border_radius.bottomLeft, bounds.size.h - border_radius.bottomLeft },
		border_radius.bottomLeft,
		border_radius.bottomLeft,
		PI * 0.5f, PI
	);
	Geometry::Path bottomLeftInner;
	if (bottomLeftInnerRounded) {
		bottomLeftInner.DrawArc(
			{ border_radius.bottomLeft, bounds.size.h - border_radius.bottomLeft },
			border_radius.bottomLeft - border.left,
			border_radius.bottomLeft - border.bottom,
			PI * 0.5f, PI
		);
	}
	else {
		bottomLeftInner.emplace({
			border.left,
			bounds.size.h - border.bottom
		});
	}
	geometry.AddArc(bottomLeftOuter, bottomLeftInner, border_color.bottom);

	edge.padding.clear();
	edge.padding.append(topLeftInner);
	edge.padding.append(topRightInner);
	edge.padding.append(bottomRightInner);
	edge.padding.append(bottomLeftInner);
	geometry.AddPolygon(edge.padding, background_color);

	if (element->IsGray()) {
		geometry.SetGray();
	}
}

}
