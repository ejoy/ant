#pragma once

#include "context.h"
#include <core/Interface.h>
#include <stdint.h>

extern "C" {
    #include "../font/font_manager.h"
}

namespace Rml {
	class FontEngine: public FontEngineInterface {
	public:
		FontEngine(const RmlContext* context);
		virtual ~FontEngine() = default;
		virtual FontFaceHandle GetFontFaceHandle(const std::string& family, Style::FontStyle style, Style::FontWeight weight, uint32_t size) override;
		virtual int GetLineHeight(FontFaceHandle handle) override;
		virtual int GetBaseline(FontFaceHandle handle) override;
		virtual void GetUnderline(FontFaceHandle handle, float& position, float& thickness) override;
		virtual int GetStringWidth(FontFaceHandle handle, const std::string& string) override;
		virtual void GenerateString(FontFaceHandle handle, LineList& lines, const Color& color, Geometry& geometry) override;

	private:
		const RmlContext* mcontext;
	};
}
