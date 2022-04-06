#pragma once

#include "context.h"
#include <core/Interface.h>
#include <core/Texture.h>
#include <unordered_map>
#include <vector>
#include <cstdint>

extern "C"{
    #include "../font/font_manager.h"
}

struct FontFace{
	int	fontid;
	int pixelsize;
};

class FontEngine : public Rml::FontEngineInterface {
public:
	FontEngine(const RmlContext* context)
		: mcontext(context)
		{}
	virtual ~FontEngine() = default;

	virtual Rml::FontFaceHandle GetFontFaceHandle(const std::string& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, int size)override;

	virtual int GetSize(Rml::FontFaceHandle handle)override;
	virtual int GetXHeight(Rml::FontFaceHandle handle)override;

	virtual int GetLineHeight(Rml::FontFaceHandle handle)override;
	virtual int GetBaseline(Rml::FontFaceHandle handle)override;

	virtual void GetUnderline(Rml::FontFaceHandle handle, float& position, float &thickness)override;
	virtual int GetStringWidth(Rml::FontFaceHandle handle, const std::string& string)override;
	int GenerateString(Rml::FontFaceHandle handle, const std::string& string, const Rml::Point& position, const Rml::Color& color, Rml::Geometry& geometry);
	virtual void GenerateString(Rml::FontFaceHandle face_handle, Rml::LineList& lines, const Rml::Color& color, Rml::Geometry& geometry) override;

private:
	struct font_glyph
	GetGlyph(const FontFace &face, int codepoint, struct font_glyph *og = nullptr);

private:
    const RmlContext* mcontext;
	struct fontinfo {
		std::vector<uint8_t>buffer;
		std::vector<int>	fontids;
	};
	std::unordered_map<std::string, fontinfo>	mFonts;
	std::unordered_map<std::string, int>		mFontIDs;
	std::vector<FontFace> mFontFaces;
};
