#pragma once

#include <core/Geometry.h>

namespace Rml {

class Element;

class ElementBackground {
public:
	void Render();
	void Update(Element* element);
private:
	struct Box {
		Geometry::Path padding;
	};
	static void GenerateBorderGeometry(Element* element, Geometry& geometry, Box& edge);
	static bool GenerateImageGeometry(Element* element, Geometry& geometry, Box const& edge);
private:
	std::unique_ptr<Geometry> background;
	std::unique_ptr<Geometry> image;
};

}
