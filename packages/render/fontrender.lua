local ecs = ...
local world = ecs.world

local bgfx      = require "bgfx"
local  lfont    = require "font"
local math3d    = require "math3d"

local declmgr   = require "vertexdecl_mgr"

local fontmgr   = import_package "ant.font".mgr

local function create_font_texture2d()
    local s = lfont.fonttexture_size
    return bgfx.create_texture2d(s, s, false, 1, "A8")
end

local fonttex_handle    = create_font_texture2d()
local fonttex           = {stage=0, texture={handle=fonttex_handle}}
local  layout_desc      = declmgr.correct_layout "p20nii|t20nii|c40niu"
local fontquad_layout   = declmgr.get(layout_desc)
local declformat        = declmgr.vertex_desc_str(layout_desc)

local ifont             = ecs.interface "ifont"
function ifont.font_tex_handle()
    return fonttex_handle
end

function ifont.font_tex_dim()
    local s = lfont.fonttexture_size
    return s, s
end

function ifont.handle()
    return lfont.font_manager
end

local imaterial = world:interface "ant.asset|imaterial"
local irender = world:interface "ant.render|irender"

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

local function text_start_pos(textw, texth, screenpos)
    return screenpos[1] - textw * 0.5, screenpos[2] - texth * 0.5
end

local fontcomp = ecs.component "font"
function fontcomp:init()
    self.id = fontmgr.name(self.family)
    return self
end

local sc_comp = ecs.component "show_config"
function sc_comp:init()
    if self.location_offset then
        self.location_offset = math3d.ref(math3d.vector(self.location_offset))
    end
    
    if self.location then
        self.location = math3d.ref(math3d.vector(self.location))
    end

    return self
end

local fontmesh = ecs.transform "font_mesh"
function fontmesh.process_prefab(e)
    e.mesh = world.component "mesh" {
        vb = {
            start = 0,
            num = 0,
            bgfx.transient_buffer(declformat),
        },
        ib = {
            start = 0,
            num = 0,
            handle = irender.quad_ib()
        }
    }
end

local fontsys = ecs.system "font_system"

local mask<const> = {0, 1, 0, 0}
local function calc_aabb_pos(e, offset, offsetop)
    local attacheid = e._rendercache.attach_eid
    local attach_e = world[attacheid]
    if attach_e then
        local aabb = attach_e._rendercache.aabb
        if aabb then
            local center, extent = math3d.aabb_center_extents(aabb)
            local pos = offsetop(center, extent)
            if offset then
                return math3d.add(offset, pos)
            end
            return pos
        end
    end
end

local function calc_3d_anchor_pos(e, cfg)
    if cfg.location_type == "aabb_top" then
        return calc_aabb_pos(e, cfg.location_offset, function (center, extent)
            return math3d.muladd(mask, extent, center)
        end)
    elseif cfg.location_type == "aabb_bottom" then
        return calc_aabb_pos(e, cfg.location_offset, function (center, extent)
                return math3d.muladd(mask, math3d.inverse(extent), center)
            end)
    elseif cfg.location then
        return cfg.location
    else
        error(("not support location:%s"):format(cfg.location))
    end
end

local function load_text(eid)
    local e = world[eid]
    local font = e.font
    local sc = e.show_config
    local screenpos = calc_screen_pos(calc_3d_anchor_pos(e, sc))

    local textw, texth, num = lfont.prepare_text(fonttex_handle, sc.description, font.size, font.id)
    local x, y = text_start_pos(textw, texth, screenpos)
    local rc = e._rendercache
    local vb, ib = rc.vb, rc.ib
    vb.start, vb.num = 0, num*4
    local vbhandle = vb.handles[1]
    local vbdata = vbhandle:alloc(vb.num, fontquad_layout.handle)

    ib.num = num * 2 * 3

    rc.depth = screenpos[3]

    lfont.load_text_quad(vbdata, sc.description, x, y, font.size, sc.color, font.id)
end

function fontsys:camera_usage()
    for _, eid in world:each "show_config" do
        load_text(eid)
    end
    lfont.submit()
end

local sn_a = ecs.action "show_name"
function sn_a.init(prefab, idx, value)
    local eid = prefab[idx]
    local e = world[eid]
    e._rendercache.attach_eid = prefab[value]

    imaterial.set_property(eid, "s_tex", fonttex)
end