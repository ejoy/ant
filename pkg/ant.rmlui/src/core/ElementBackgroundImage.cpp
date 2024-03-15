#include <core/ElementBackground.h>
#include <core/Texture.h>
#include <core/Element.h>
#include <core/Geometry.h>
#include <core/Document.h>
#include <core/Interface.h>
#include <binding/Context.h>
#include <regex>

namespace Rml {

static void GetRectArray(float wl, float ht, float wr, float hb, Rect& rect, std::vector<Rect> &rect_array){
		float x = rect.origin.x;
		float y = rect.origin.y;
		float w = rect.size.w;
		float h = rect.size.h;
		float w1 = wl * w;
		float w2 = (1 - wl - wr) * w;
		float w3 = wr * w;
		float w4 = (1 - wr) * w;
		float h1 = ht * h;
		float h2 = (1 - ht - hb) * h;
		float h3 = hb * h;
		float h4 = (1 - hb) * h;
		rect_array[0] = Rect{x     , y     , w1, h1};
		rect_array[1] = Rect{x + w1, y     , w2, h1};
		rect_array[2] = Rect{x + w4, y     , w3, h1};
		rect_array[3] = Rect{x     , y + h1, w1, h2};
		rect_array[4] = Rect{x + w1, y + h1, w2, h2};
		rect_array[5] = Rect{x + w4, y + h1, w3, h2};
		rect_array[6] = Rect{x     , y + h4, w1, h3};
		rect_array[7] = Rect{x + w1, y + h4, w2, h3};
		rect_array[8] = Rect{x + w4, y + h4, w3, h3};
}

static Rect CalcUV(const Rect& surface, const Rect& texture) {
	Rect uv;
	uv.origin = (surface.origin - texture.origin) / texture.size;
	uv.size = surface.size / texture.size;
	return uv;
}

static auto GetSamplerFlag(Style::BackgroundRepeat v) {
	switch (v) {
	case Style::BackgroundRepeat::NoRepeat:
		return SamplerFlag::Clamp;
	case Style::BackgroundRepeat::Repeat:
		return SamplerFlag::Repeat;
	case Style::BackgroundRepeat::RepeatX:
		return SamplerFlag::RepeatX;
	case Style::BackgroundRepeat::RepeatY:
		return SamplerFlag::RepeatY;
	default:
		std::unreachable();
	}
}

bool ElementBackground::GenerateImageGeometry(Element* element, Geometry& geometry, Box const& edge) {
	auto image = element->GetComputedProperty(PropertyId::BackgroundImage);
	if (!image.Has<std::string>()) {
		// "none"
		return false;
	}
	std::string path = image.Get<std::string>();
	if (path.empty()) {
		return false;
	}

	const auto& bounds = element->GetBounds();
	const auto& border = element->GetBorder();
	const auto& padding = element->GetPadding();

	bool isRT = false;
	if (regex_match(path, std::regex("<.*>"))) {
		isRT = true;
		path = regex_replace(path, std::regex("[<>]"), std::string(""));
	}
	auto const& texture = isRT? Texture::Fetch(element, path, bounds.size): Texture::Fetch(element, path);
	if (!texture) {
		return false;
	}

	Style::BoxType origin = element->GetComputedProperty(PropertyId::BackgroundOrigin).GetEnum<Style::BoxType>();
	Rect surface = Rect { {0, 0}, bounds.size };
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

	Color color = Color::FromSRGB(255, 255, 255, 255);
	bool setGray = false;
	if (element->IsGray()) {
		setGray = true;
	}
	else {
		auto property = element->GetComputedProperty(PropertyId::BackgroundFilter);
		if (!property.Has<PropertyKeyword>()) {
			setGray = true;
			color = property.Get<Color>();
		}
	}
	color.ApplyOpacity(element->GetOpacity());
	if (!color.IsVisible())
		return false;

	Rect background {};
	background.origin = surface.origin + Point {
		PropertyComputeX(element, element->GetComputedProperty(PropertyId::BackgroundPositionX)),
		PropertyComputeY(element, element->GetComputedProperty(PropertyId::BackgroundPositionY))
	};
	switch (element->GetComputedProperty(PropertyId::BackgroundSize).GetEnum<Style::BackgroundSize>()) {
	case Style::BackgroundSize::Contain: {
		Size scale {
			surface.size.w / texture.dimensions.w,
			surface.size.h / texture.dimensions.h
		};
		if (scale.w < scale.h) {
			background.size = {
				surface.size.w,
				surface.size.w / texture.dimensions.w * texture.dimensions.h,
			};
		}
		else {
			background.size = {
				surface.size.h / texture.dimensions.h * texture.dimensions.w,
				surface.size.h,
			};
		}
		break;
	}
	case Style::BackgroundSize::Cover: {
		Size scale {
			surface.size.w / texture.dimensions.w,
			surface.size.h / texture.dimensions.h
		};
		if (scale.w > scale.h) {
			background.size = {
				surface.size.w,
				surface.size.w / texture.dimensions.w * texture.dimensions.h,
			};
		}
		else {
			background.size = {
				surface.size.h / texture.dimensions.h * texture.dimensions.w,
				surface.size.h,
			};
		}
		break;
	}
	case Style::BackgroundSize::Auto: {
		background.size = texture.dimensions;
		break;
	}
	default:
	case Style::BackgroundSize::Unset: {
		background.size = {
			element->GetComputedProperty(PropertyId::BackgroundSizeX).Get<PropertyFloat>().ComputeW(element),
			element->GetComputedProperty(PropertyId::BackgroundSizeY).Get<PropertyFloat>().ComputeH(element)
		};
		break;
	}
	}

	Rect uv = CalcUV(surface, background);
	auto atlasData = std::get_if<TextureData::Atlas>(&texture.extra);
	if (atlasData) {
		uv.origin.x = uv.origin.x + atlasData->ux;
		uv.origin.x = uv.origin.x + atlasData->uy;
		uv.size.w = uv.size.w * atlasData->uw;
		uv.size.h = uv.size.h * atlasData->uh;
	}

	auto backgroundRepeat = element->GetComputedProperty(PropertyId::BackgroundRepeat).GetEnum<Style::BackgroundRepeat>();

	if (backgroundRepeat == Style::BackgroundRepeat::Repeat){
		uv.size = uv.size / ( Size(texture.dimensions) / background.size);
	}
	else if (backgroundRepeat == Style::BackgroundRepeat::RepeatX){
		uv.size = uv.size / ( Size(texture.dimensions) / background.size);
		background.size.h = background.size.h > texture.dimensions.h ? texture.dimensions.h : background.size.h;
	}
	else if (backgroundRepeat == Style::BackgroundRepeat::RepeatY){
		uv.size = uv.size / ( Size(texture.dimensions) / background.size);
		background.size.w = background.size.w > texture.dimensions.w ? texture.dimensions.w : background.size.w;		
	}

	Material* material = GetRender()->CreateTextureMaterial(texture.handle, GetSamplerFlag(backgroundRepeat));
	geometry.SetMaterial(material);

	if (auto latticeData = std::get_if<TextureData::Lattice>(&texture.extra)) {
		if (origin == Style::BoxType::ContentBox && edge.padding.size() != 4) {
			return false;
		}
		else {
			float x1 = latticeData->x1;
			float x2 = latticeData->x2;
			float y1 = latticeData->y1;
			float y2 = latticeData->y2;
			float u  = latticeData->u;
			float v  = latticeData->v;	
			std::vector<Rect> surface_array(9);
			std::vector<Rect> uv_array(9);
			GetRectArray(x1, y1, x2, y2, surface, surface_array);
			float ur = 1.f - u - 2.f / texture.dimensions.w;
			float vb = 1.f - v - 2.f / texture.dimensions.h;
			GetRectArray(u, v, ur, vb, uv, uv_array);
			for (int idx = 0; idx < 9; ++idx) {
				geometry.AddRectFilled(surface_array[idx], color);
				geometry.UpdateUV(4, surface_array[idx], uv_array[idx]);
			}
		}
	}
	else {
		if (origin == Style::BoxType::ContentBox && edge.padding.size() != 4) {
			if (backgroundRepeat == Style::BackgroundRepeat::NoRepeat) {
				auto poly = geometry.ClipPolygon(edge.padding, background);
				if (!poly.IsEmpty()) {
					geometry.AddPolygon(poly, color);
					geometry.UpdateUV(poly.points.size(), surface, uv);
				}
			}
			else {
				//TODO: optimization repeat-x/repeat-y
				geometry.AddPolygon(edge.padding, color);
				geometry.UpdateUV(edge.padding.points.size(), surface, uv);
			}
		}
		else {
			if (backgroundRepeat == Style::BackgroundRepeat::NoRepeat) {
				background.Inter(surface);
				if (!background.IsEmpty()) {
					geometry.AddRectFilled(background, color);
					geometry.UpdateUV(4, surface, uv);
 					if (atlasData) {
						background.origin = background.origin + Point {atlasData->fx * background.size.w, atlasData->fy* background.size.h};
						background.size.w = atlasData->fw * background.size.w;
						background.size.h = atlasData->fh * background.size.h;
						geometry.UpdateRectFilled(background, 0, 0, color);
					}
				}
			}
			else {
				//TODO: optimization repeat-x/repeat-y
				geometry.AddRectFilled(surface, color);
				geometry.UpdateUV(4, surface, uv);
			}
		}
	}

	if (setGray) {
		geometry.SetGray();
	}
	return true;
}

}
