local aio = import_package "ant.io"

local ImGui = require "imgui"

local FontAtlas = {}

local function glyphRanges(t)
	assert(#t % 2 == 0)
	local s = {}
	for i = 1, #t do
		s[#s+1] = ("<I4"):pack(t[i])
	end
	s[#s+1] = "\x00\x00\x00"
	return table.concat(s)
end

function ImGui.FontAtlasClear()
    FontAtlas = {}
end

function ImGui.FontAtlasAddFont(config)
    if config.SystemFont then
        FontAtlas[#FontAtlas+1] = {
            FontData = ImGui.GetSystemFont(config.SystemFont),
            SizePixels = config.SizePixels,
            GlyphRanges = glyphRanges(config.GlyphRanges),
        }
        return
    end
    FontAtlas[#FontAtlas+1] = {
        FontData = aio.readall(config.FontPath),
        SizePixels = config.SizePixels,
        GlyphRanges = glyphRanges(config.GlyphRanges),
    }
end

function ImGui.FontAtlasBuild()
    ImGui.InitFont(FontAtlas)
    FontAtlas = {}
end

return ImGui
