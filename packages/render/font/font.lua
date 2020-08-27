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

    local mask<const>, offset<const> = {0.5, 0.5, 1, 1}, {0.5, 0.5, 0, 0}
    local posClamp = math3d.muladd(posNDC, mask, offset)
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
        fontid = bgfxfont.addfont(platform.font(fontname))
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
    tb:alloc(numchar * 4, fontquad_layout.handle)
    bgfxfont.load_text_quad(tb, text, x, y, size, color, fontid)
end

local fontcomp = ecs.component "font"
function fontcomp:init()
    self.id = ifontmgr.add_font(self.name)
    return self
end

local fontsys = ecs.system "font_system"

local function calc_pos(e, cfg)
    if cfg.location == "header" then
        local mask<const> = {0, 1, 0, 0}
        local aabb = e._rendercache.aabb
        if aabb then
            local center, extent = math3d.aabb_center_extents(aabb)
            return math3d.muladd(mask, extent, center)
        end
    else
        error(("not support location:%s"):format(cfg.location))
    end
end

function fontsys:camera_usage()
    for _, eid in world:each "show_config" do
        local e = world[eid]
        local n = e.name
        local font = assert(e.font)
        local pos = calc_pos(e, e.show_config)
        if font then
            ifontmgr.add_text3d(pos, font.id, n, font.size, 0xffafafaf, 0)
        end
    end
end