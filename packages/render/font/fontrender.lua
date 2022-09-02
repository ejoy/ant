local ecs = ...
local world = ecs.world
local w = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local declmgr   = require "vertexdecl_mgr"

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local fontpkg   = import_package "ant.font"
local lfont     = require "font"

fontpkg.init()

local fonttex_handle    = fontpkg.texture()
local fonttex           = {stage=0, texture={handle=fonttex_handle}}
local layout_desc       = declmgr.correct_layout "p20nii|t20nii|c40niu"
local fontquad_layout   = declmgr.get(layout_desc)
local declformat        = declmgr.vertex_desc_str(layout_desc)

local imaterial = ecs.import.interface "ant.asset|imaterial"
local irender = ecs.import.interface "ant.render|irender"

local dyn_vb = {}; dyn_vb.__index = dyn_vb

function dyn_vb:create(maxsize, fmt)
    local d = declmgr.get(fmt)
    local handle = bgfx.create_dynamic_vertex_buffer(maxsize, d.handle)
    return setmetatable({
        data={},
        handle = handle,
        format = fmt,
        stride = d.stride,
    }, dyn_vb)
end

function dyn_vb:add(mem)
    local idx = #self.data+1
    self.data[idx] = mem
    local offsetV = self:update(idx, idx)
    local numV = #mem // self.stride
    return idx, offsetV-numV, numV
end

function dyn_vb:remove(idx)
    table.remove(self.data, idx)
    self:update(idx)
end

function dyn_vb:update(from, to)
    from = from or 1
    to = to or #self.data
    local offsetV = 0
    while from <= to do
        local m = self.data[from]
        bgfx.update(self.handle, offsetV, m)
        local sizebytes = #m
        local numv = sizebytes // self.stride
        offsetV = offsetV + numv
        from = from + 1
    end

    return offsetV
end

local dvb = dyn_vb:create(10240, layout_desc)

local function calc_screen_pos(pos3d)
    local q = w:first("main_queue camera_ref:in render_target:in")
    local ce = w:entity(q.camera_ref, "camera:in")
    return mu.world_to_screen(ce.camera.viewprojmat, q.render_target.view_rect, pos3d)
end

local function text_start_pos(textw, texth, sx, sy)
    return sx - textw * 0.5, sy - texth * 0.5
end

local fontsys = ecs.system "font_system"

local vertical_mask<const> = math3d.ref(math3d.vector(0, 1, 0, 0))
local function calc_aabb_pos(e, offset, offsetop)
    local a_eid = e.font.attach_eid
    if a_eid then
        local ae <close> = w:entity(a_eid, "bounding:in")
        local aabb = ae.bounding.scene_aabb
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
            return math3d.muladd(vertical_mask, extent, center)
        end)
    elseif cfg.location_type == "aabb_bottom" then
        return calc_aabb_pos(e, cfg.location_offset, function (center, extent)
                return math3d.muladd(vertical_mask, math3d.inverse(extent), center)
            end)
    elseif cfg.location then
        return cfg.location
    else
        error(("not support location:%s"):format(cfg.location))
    end
end

local function add_text_mem(m, num, ro)
    local vbnum = num*4
    local idx, s, n = dvb:add(m)
    assert(n == vbnum)
    ro.vb_num = vbnum
    ro.vb_start = s

    ro.ib_start, ro.ib_num = 0, num * 2 * 3
    return idx
end

local function load_text(e)
    local font = e.font
    local sc = e.show_config
    local pos = calc_3d_anchor_pos(e, sc)
    local sx, sy, depth = math3d.index(calc_screen_pos(pos), 1, 2, 3)

    local textw, texth, num = lfont.prepare_text(fonttex_handle, sc.description, font.size, font.id)
    local x, y = text_start_pos(textw, texth, sx, sy)
    local ro = e.render_object

    local m = bgfx.memory_buffer(num*4 * fontquad_layout.stride)
    lfont.load_text_quad(m, sc.description, x, y, font.size, sc.color, font.id)

    font.idx = add_text_mem(m, num, ro)
end

local ev = world:sub {"show_name"}

function fontsys:component_init()
    for e in w:select "INIT font:in simplemesh:out owned_mesh_buffer?out" do
        lfont.import(e.font.file)
        e.font.id = lfont.name(e.font.name)
        e.simplemesh = {
            vb = {
                start = 0,
                num = 0,
                handle = dvb.handle,
            },
            ib = {
                start = 0,
                num = 0,
                handle = irender.quad_ib()
            }
        }
        e.owned_mesh_buffer = true
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
    for _, eid, attach in ev:unpack() do
        local e <close> = w:entity(eid, "font:in")
        local f = e.font
        f.attach_eid = attach
        imaterial.set_property(e, "s_tex", fonttex)
    end
    for e in w:select "font:in show_config:in scene:in render_object:update" do
        if e.font.idx == nil then
            load_text(e)
        end
    end
    lfont.submit()
end

function ecs.method.show_name(eid, attach)
    world:pub {"show_name", eid, attach}
end
