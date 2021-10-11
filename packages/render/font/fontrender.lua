local ecs = ...
local world = ecs.world
local w = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local declmgr   = require "vertexdecl_mgr"
local font      = import_package "ant.font"
local lfont     = require "font"

font.init()

local fonttex_handle    = font.texture()
local fonttex           = {stage=0, texture={handle=fonttex_handle}}
local layout_desc       = declmgr.correct_layout "p20nii|t20nii|c40niu"
local fontquad_layout   = declmgr.get(layout_desc)
local declformat        = declmgr.vertex_desc_str(layout_desc)

local imaterial = ecs.import.interface "ant.asset|imaterial"
local irender = ecs.import.interface "ant.render|irender"
local icamera	= ecs.import.interface "ant.camera|camera"

local irq = ecs.import.interface "ant.render|irenderqueue"
local function calc_screen_pos(pos3d, queuename)
    queuename = queuename or "main_queue"

    local q = w:singleton(queuename, "camera_ref:in")
	local camera = icamera.find_camera(q.camera_ref)
    local vp = camera.viewprojmat
    local posNDC = math3d.transformH(vp, pos3d)

    local mask<const>, offset<const> = {0.5, 0.5, 1, 1}, {0.5, 0.5, 0, 0}
    local posClamp = math3d.muladd(posNDC, mask, offset)
    local vr = irq.view_rect(queuename)

    local posScreen = math3d.tovalue(math3d.mul(math3d.vector(vr.w, vr.h, 1, 1), posClamp))

    if not math3d.origin_bottom_left then
        posScreen[2] = vr.h - posScreen[2]
    end

    return posScreen
end

local function text_start_pos(textw, texth, screenpos)
    return screenpos[1] - textw * 0.5, screenpos[2] - texth * 0.5
end

local fontsys = ecs.system "font_system"

local mask<const> = {0, 1, 0, 0}
local function calc_aabb_pos(e, offset, offsetop)
    local attach_e = e.render_object.attach_eid
    if attach_e then
        w:sync("render_object:in", attach_e)
        local aabb = attach_e.render_object.aabb
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

local function load_text(e)
    local font = e.font
    local sc = e.show_config
    local screenpos = calc_screen_pos(calc_3d_anchor_pos(e, sc))

    local textw, texth, num = lfont.prepare_text(fonttex_handle, sc.description, font.size, font.id)
    local x, y = text_start_pos(textw, texth, screenpos)
    local rc = e.render_object
    local vb, ib = rc.vb, rc.ib
    vb.start, vb.num = 0, num*4
    local vbhandle = vb.handles[1]
    local vbdata = vbhandle:alloc(vb.num, fontquad_layout.handle)

    ib.num = num * 2 * 3

    rc.depth = screenpos[3]

    lfont.load_text_quad(vbdata, sc.description, x, y, font.size, sc.color, font.id)
end

local ev = world:sub {"show_name"}

function fontsys:component_init()
    for e in w:select "INIT font:in mesh:out" do
        if e.font.file then
            lfont.import(e.font.file:string())
        end
        e.font.id = lfont.name(e.font.name)

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
    for e in w:select "INIT show_config:in" do
        if e.show_config.location_offset then
            e.show_config.location_offset = math3d.ref(math3d.vector(e.show_config.location_offset))
        end
        if e.show_config.location then
            e.show_config.location = math3d.ref(math3d.vector(e.show_config.location))
        end
    end
end

function fontsys:camera_usage()
    for _, e, attach in ev:unpack() do
        w:sync("render_object:in", e)
        e.render_object.attach_eid = attach
        imaterial.set_property(e, "s_tex", fonttex)
    end
    for e in w:select "font:in show_config:in render_object:in" do
        load_text(e)
    end
    lfont.submit()
end

function ecs.method.show_name(e, attach)
    world:pub {"show_name", e, attach}
end
