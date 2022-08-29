#pragma once

#include <core/Geometry.h>

namespace Rml {

class Element;

struct ElementBackgroundBorder {
	static void GenerateGeometry(Element* element, Geometry& geometry, Geometry::Path& paddingEdge);
};

}
