local ecs = ...

local ifontmgr = ecs.interface "ifont_mgr"
local bgfx = require "bgfx"
local bgfxui = require "bgfx.ui"

local declmgr = require "vertexdecl_mgr"

local MAX_QUAD<const> = 256
local MAX_VERTICES<const> = MAX_QUAD * 4

local function create_font_texture2d()
    local s = bgfxui.fonttexture_size
    return bgfx.create_texture2d(s, s, false, 1, "A8")
end

local fonttex       = create_font_texture2d()
local layout_desc   = declmgr.correct_layout "p3|c40niu|t2"
local fontquad_layout = declmgr.get(layout_desc)
local declformat    = declmgr.vertex_desc_str(layout_desc)
local tb            = bgfx.transient_buffer(declformat)

local alltext       = {}

function ifontmgr.add_text(pos, text)
    
end