#include <core/ElementBackgroundImage.h>
#include <core/Texture.h>
#include <core/Element.h>
#include <core/Geometry.h>
#include <core/Document.h>
#include <core/Interface.h>
#include <core/Core.h>
#include <regex>

namespace Rml {

void ElementBackgroundImage::GetRectArray(float ratio, Rect& rect, std::vector<Rect> &rect_array){
		float x = rect.origin.x;
		float y = rect.origin.y;
		float w = rect.size.w;
		float h = rect.size.h;
		float w1 = ratio * w;
		float w2 = (1 - ratio) * w;
		float w3 = (1 - 2 * ratio) * w;
		float h1 = ratio * h;
		float h2 = (1 - ratio) * h;
		float h3 = (1 - 2 * ratio) * h;
		rect_array[0] = Rect{x, y, w1, h1};
		rect_array[1] = Rect{w1, y, w3, h1};
		rect_array[2] = Rect{w2, y, w1, h1};
		rect_array[3] = Rect{x, h1, w1, h3};
		rect_array[4] = Rect{w1, h1, w3, h3};
		rect_array[5] = Rect{w2, h1, w1, h3};
		rect_array[6] = Rect{x, h2, w1, h1};
		rect_array[7] = Rect{w1, h2, w3, h1};
		rect_array[8] = Rect{w2, h2, w1, h1};
}

bool ElementBackgroundImage::GenerateGeometry(Element* element, Geometry& geometry, Geometry::Path const& paddingEdge) {
	auto image = element->GetComputedProperty(PropertyId::BackgroundImage);
	if (!image->Has<std::string>()) {
		// "none"
		return false;
	}
	const auto& bounds = element->GetBounds();
	const auto& border = element->GetBorder();
	const auto& padding = element->GetPadding();

	Style::BoxType origin = (Style::BoxType)element->GetComputedProperty(PropertyId::BackgroundOrigin)->Get<PropertyKeyword>();

	Rect surface = Rect{ {0, 0}, bounds.size };
	if (surface.size.IsEmpty()) {
		return false;
	}

	switch (origin) {
	case Style::BoxType::PaddingBox:
		surface = surface - border;
		break;
	case Style::BoxType::BorderBox:
		break;
	case Style::BoxType::ContentBox:
		surface = surface - border - padding;
		break;
	}
	if (surface.size.IsEmpty()) {
		return false;
	}

	SamplerFlag repeat = (SamplerFlag)element->GetComputedProperty(PropertyId::BackgroundRepeat)->Get<PropertyKeyword>();
	Style::BackgroundSize backgroundSize = (Style::BackgroundSize)element->GetComputedProperty(PropertyId::BackgroundSize)->Get<PropertyKeyword>();
	Size texSize {
		element->GetComputedProperty(PropertyId::BackgroundSizeX)->Get<PropertyFloat>().ComputeW(element),
		element->GetComputedProperty(PropertyId::BackgroundSizeY)->Get<PropertyFloat>().ComputeH(element)
	};
	Point texPosition {
		element->GetComputedProperty(PropertyId::BackgroundPositionX)->Get<PropertyFloat>().ComputeW(element),
		element->GetComputedProperty(PropertyId::BackgroundPositionY)->Get<PropertyFloat>().ComputeH(element)
	};

	Color color = Color::FromSRGB(255, 255, 255, 255);
	color.ApplyOpacity(element->GetOpacity());
	if (!color.IsVisible())
		return false;

	std::string path = image->Get<std::string>();
	bool isRT = false;
	if (regex_match(path, std::regex("<.*>"))) {
		isRT = true;
		path = regex_replace(path, std::regex("[<>]"), std::string(""));
	}
	auto const& texture = isRT? Texture::Fetch(element, path, surface.size): Texture::Fetch(element, path);
	if (!texture) {
		return false;
	}

	if (texSize.IsEmpty()) {
		texSize = texture.dimensions;
	}
	Size scale{
		surface.size.w / texSize.w,
		surface.size.h / texSize.h
	};
	Rect uv { {
		texPosition.x / texSize.w,
		texPosition.y / texSize.h
	}, {} };
	float aspectRatio = scale.w / scale.h;
	//uv
	switch (backgroundSize) {
	case Style::BackgroundSize::Auto:
		uv.size.w = scale.w;
		uv.size.h = scale.h;
		break;
	case Style::BackgroundSize::Contain:
		if (aspectRatio < 1.f) {
			uv.size.w = 1.f;
			uv.size.h = 1.f / aspectRatio;
		}
		else {
			uv.size.w = aspectRatio;
			uv.size.h = 1.f;
		}
		break;
	case Style::BackgroundSize::Cover:
		if (aspectRatio > 1.f) {
			uv.size.w = 1.f;
			uv.size.h = 1.f / aspectRatio;
		}
		else {
			uv.size.w = aspectRatio;
			uv.size.h = 1.f;
		}
		break;
	}
	Rml::MaterialHandle material;
 	if (isRT) {
		material = GetRenderInterface()->CreateRenderTextureMaterial(texture.handle, repeat);
	} 
	else {
		material = GetRenderInterface()->CreateTextureMaterial(texture.handle, repeat);
	} 
	
	geometry.SetMaterial(material);

	auto lattice = element->GetComputedProperty(PropertyId::BackgroundLattice);
	if(lattice->Has<PropertyFloat>()){
		std::vector<Rect> surface_array(9);
		std::vector<Rect> uv_array(9);
		GetRectArray(lattice->Get<PropertyFloat>().value / 100.0, surface, surface_array);
		GetRectArray((float)0.49, uv, uv_array);
		for(int idx = 0; idx < 9; ++idx){
			geometry.AddRectFilled(surface_array[idx], color);
			geometry.UpdateUV(4, surface_array[idx], uv_array[idx]);
		}		
	}
	else{
		if (paddingEdge.size() == 0 
			|| (origin == Style::BoxType::ContentBox && padding != EdgeInsets<float>{})
		) {
			geometry.AddRectFilled(surface, color);
			geometry.UpdateUV(4, surface, uv);
		}
		else {
			geometry.AddPolygon(paddingEdge, color);
			geometry.UpdateUV(paddingEdge.size(), surface, uv);
		}
	}
	return true;
}

}
