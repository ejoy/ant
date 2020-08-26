local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local bgfxfont = require "bgfx.font"
local math3d = require "math3d"
local platform = require "platform"

local declmgr = require "vertexdecl_mgr"

local MAX_QUAD<const>       = 256
local MAX_VERTICES<const>   = MAX_QUAD * 4

local function create_font_texture2d()
    local s = bgfxfont.fonttexture_size
    return bgfx.create_texture2d(s, s, false, 1, "A8")
end

local fonttex       = create_font_texture2d()
local layout_desc   = declmgr.correct_layout "p20Nii|t20Nii|c40niu"
local fontquad_layout = declmgr.get(layout_desc)
local declformat    = declmgr.vertex_desc_str(layout_desc)
local tb            = bgfx.transient_buffer(declformat)

local irq = world:interface "ant.render|irenderqueue"
local function calc_screen_pos(pos3d, queueeid)
    queueeid = queueeid or world:singleton_entity_id "main_queue"

    local q = world[queueeid]
    local vp = world[q.camera_eid]._rendercache.viewprojmat
    local posNDC = math3d.transformH(vp, pos3d)

    local offset<const> = {0.5, 0.5, 0, 0}
    local posClamp = math3d.muladd(posNDC, 0.5, offset)
    local vr = irq.view_rect(queueeid)

    local posScreen = math3d.tovalue(math3d.mul(math3d.vector(vr.w, vr.h, 1, 1), posClamp))

    if not math3d.origin_bottom_left then
        posScreen[2] = vr.h - posScreen[2]
    end

    return posScreen
end

local ifontmgr = ecs.interface "ifontmgr"
local allfont = {}
function ifontmgr.add_font(fontname)
    local fontid = allfont[fontname]
    if fontid == nil then
        fontid = bgfxfont.add_font(platform.font(fontname))
        allfont[fontname] = fontid
    end

    return fontid
end

local function text_start_pos(textw, texth, screenpos)
    return screenpos[1] - textw * 0.5, screenpos[2] - texth * 0.5
end

function ifontmgr.add_text3d(pos3d, fontid, text, size, color, style, queueeid)
    local screenpos = calc_screen_pos(pos3d, queueeid)
    local textw, texth, numchar = bgfxfont.prepare_text(fonttex, text, size, fontid)
    
    local x, y = text_start_pos(textw, texth, screenpos)
    tb:allocTB(numchar * 4, fontquad_layout.handle)
    bgfxfont.load_text_quad(tb, x, y, text, size, color, fontid)
end