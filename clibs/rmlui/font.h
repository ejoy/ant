#pragma once
#include "RmlUi/Core/FontEngineInterface.h"
#include "RmlUi/Core/Texture.h"
#include <unordered_map>
#include <vector>
struct font_namager;
struct FontFace{
	int	fontid;
	int fontsize;
};

class FontInterface : public Rml::FontEngineInterface {
public:
	FontInterface(struct font_manager *fm) : mfontmgr(fm){
	}
	virtual ~FontInterface() = default;

	void InitFontTex(){
		mFontTex.Set(FONT_TEX_NAME);
	}
	virtual bool LoadFontFace(const Rml::String& file_name, bool fallback_face) override;
	virtual bool LoadFontFace(const Rml::byte* data, int data_size, const Rml::String& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, bool fallback_face)override;

	virtual Rml::FontFaceHandle GetFontFaceHandle(const Rml::String& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, int size)override;
	//virtual Rml::FontEffectsHandle PrepareFontEffects(Rml::FontFaceHandle handle, const Rml::FontEffectList &font_effects)override;

	virtual int GetSize(Rml::FontFaceHandle handle)override;
	virtual int GetXHeight(Rml::FontFaceHandle handle)override;

	virtual int GetLineHeight(Rml::FontFaceHandle handle)override;
	virtual int GetBaseline(Rml::FontFaceHandle handle)override;

	virtual float GetUnderline(Rml::FontFaceHandle handle, float &thickness)override;
	virtual int GetStringWidth(Rml::FontFaceHandle handle, const Rml::String& string, Rml::Character prior_character = Rml::Character::Null)override;
	virtual int GenerateString(Rml::FontFaceHandle face_handle, Rml::FontEffectsHandle font_effects_handle, const Rml::String& string, const Rml::Vector2f& position, const Rml::Colourb& colour, Rml::GeometryList& geometry)override;

	virtual int GetVersion(Rml::FontFaceHandle handle)override;

private:
	struct font_glyph
	GetGlyph(const FontFace &face, int codepoint, uint16_t *uv_w = nullptr, uint16_t *uv_h = nullptr);
public:
	static const Rml::String FONT_TEX_NAME;
private:
    struct font_manager*		mfontmgr;
	struct fontinfo {
		std::vector<uint8_t>buffer;
		std::vector<int>	fontids;
	};
	std::unordered_map<Rml::String, fontinfo>	mFonts;

	std::unordered_map<Rml::String, int>		mFontIDs;
	std::vector<FontFace>		mFontFaces;
	Rml::Texture mFontTex;
};