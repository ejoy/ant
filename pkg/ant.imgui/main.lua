local aio = import_package "ant.io"
local fontutil = require "font.util"
local fastio = require "fastio"
local ImGui = require "imgui"
local ImGuiIO = ImGui.io

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
            FontData = fastio.tostring(fontutil.systemfont(config.SystemFont)),
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


local ImGuiEvent = {}

function ImGuiEvent.mouseclick(e)
    local btn = 0
    if e.what == "LEFT" then
        btn = 0
    elseif e.what == "RIGHT" then
        btn = 1
    elseif e.what == "MIDDLE" then
        btn = 2
    end
    if e.state == "DOWN" then
        ImGuiIO.AddMouseButtonEvent(btn, true)
    elseif e.state == "UP" then
        ImGuiIO.AddMouseButtonEvent(btn, false)
    end
    return ImGuiIO.WantCaptureMouse
end

function ImGuiEvent.mousewheel(e)
    ImGuiIO.AddMouseWheelEvent(0, e.delta)
    return ImGuiIO.WantCaptureMouse
end

function ImGuiEvent.keyboard(e)
    ImGuiIO.AddKeyEvent(ImGui.Enum.Mod.Ctrl, e.state.CTRL ~= nil);
    ImGuiIO.AddKeyEvent(ImGui.Enum.Mod.Shift, e.state.SHIFT ~= nil);
    ImGuiIO.AddKeyEvent(ImGui.Enum.Mod.Alt, e.state.ALT ~= nil);
    ImGuiIO.AddKeyEvent(ImGui.Enum.Mod.Super, e.state.SYS ~= nil);
    if e.press == 1 then
        ImGuiIO.AddKeyEvent(e.key, true);
    elseif e.press == 0 then
        ImGuiIO.AddKeyEvent(e.key, false);
    end
    return ImGuiIO.WantCaptureKeyboard
end

function ImGuiEvent.inputchar(e)
    if e.what == "native" then
        ImGuiIO.AddInputCharacter(e.code)
    elseif e.what == "utf16" then
        ImGuiIO.AddInputCharacterUTF16(e.code)
    end
end

function ImGuiEvent.focus(e)
    ImGuiIO.AddFocusEvent(e.focused)
end

function ImGui.DispatchEvent(e)
    local func = ImGuiEvent[e.type]
    return func and func(e)
end

return ImGui
