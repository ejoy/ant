#pragma once
#include "context.h"
#include "fonteffect.h"

#include "RmlUi/FontEngineInterface.h"
#include "RmlUi/Texture.h"
#include <unordered_map>
#include <vector>
#include <cstdint>

struct FontFace{
	int	fontid;
	int pixelsize;
};

class FontEngine : public Rml::FontEngineInterface {
public:
	FontEngine(const RmlContext* context)
		: mcontext(context)
		, mDefaultFontEffect(uint16_t(context->font_tex.texid))
		{}
	virtual ~FontEngine() = default;
public:
	void RegisterFontEffectInstancer();
	bool IsFontTexResource(const Rml::String &sourcename) const;
	Rml::TextureHandle GetFontTexHandle(const Rml::String &sourcename, Rml::Vector2i& texture_dimensions) const;
public:
	virtual bool LoadFontFace(const Rml::byte* data, int data_size, const Rml::String& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, bool fallback_face) override;
	virtual Rml::FontFaceHandle GetFontFaceHandle(const Rml::String& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, int size)override;
	virtual Rml::TextEffectsHandle PrepareTextEffects(Rml::FontFaceHandle handle, const Rml::TextEffects& text_effects)override;

	virtual int GetSize(Rml::FontFaceHandle handle)override;
	virtual int GetXHeight(Rml::FontFaceHandle handle)override;

	virtual int GetLineHeight(Rml::FontFaceHandle handle)override;
	virtual int GetBaseline(Rml::FontFaceHandle handle)override;

	virtual void GetUnderline(Rml::FontFaceHandle handle, float& position, float &thickness)override;
	virtual int GetStringWidth(Rml::FontFaceHandle handle, const Rml::String& string, Rml::Character prior_character = Rml::Character::Null)override;
	int GenerateString(Rml::FontFaceHandle handle, Rml::TextEffectsHandle text_effects_handle, const Rml::String& string, const Rml::Point& position, const Rml::Colourb& colour, Rml::GeometryList& geometrys);
	virtual void GenerateString(Rml::FontFaceHandle face_handle, Rml::TextEffectsHandle text_effects_handle, Rml::LineList& lines, const Rml::Colourb& colour, Rml::GeometryList& geometry)override;

	virtual int GetVersion(Rml::FontFaceHandle handle)override;

private:
	struct font_glyph
	GetGlyph(const FontFace &face, int codepoint, struct font_glyph *og = nullptr);

	struct FontResource {
		Rml::Texture tex;
		SDFFontEffect *fe;
	};
	const FontResource& FindOrAddFontResource(Rml::TextEffectsHandle font_effects_handle);
private:
    const RmlContext* mcontext;
	struct fontinfo {
		std::vector<uint8_t>buffer;
		std::vector<int>	fontids;
	};
	std::unordered_map<Rml::String, fontinfo>	mFonts;

	std::unordered_map<Rml::String, int>		mFontIDs;
	std::vector<FontFace> mFontFaces;

	std::unordered_map<Rml::String, FontResource>	mFontResources;

	SDFFontEffectDefault mDefaultFontEffect;
};