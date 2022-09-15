local ecs = ...
local world = ecs.world
local w = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local declmgr   = require "vertexdecl_mgr"
local fs        = require "filesystem"

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local fontpkg   = import_package "ant.font"
local lfont     = require "font"
fontpkg.init()


local layout    = require "layout"(fontpkg.handle())

local dyn_vb = require "font.dyn_vb"



local fonttex_handle, fonttex_width, fonttex_height = fontpkg.texture()
local layout_desc       = declmgr.correct_layout "p20nii|t20nii|c40niu"
local fontquad_layout   = declmgr.get(layout_desc)
local dvb               = dyn_vb:create(10240, layout_desc)

local imaterial = ecs.import.interface "ant.asset|imaterial"
local irender = ecs.import.interface "ant.render|irender"


local function calc_screen_pos(pos3d)
    local q = w:first("main_queue camera_ref:in render_target:in")
    local ce = w:entity(q.camera_ref, "camera:in")
    return mu.world_to_screen(ce.camera.viewprojmat, q.render_target.view_rect, pos3d)
end

local function text_start_pos(textw, texth, sx, sy)
    return (sx - textw * 0.5)*8, (sy - texth * 0.5)*8
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

    --local textw, texth, num = lfont.prepare_text(fonttex_handle, "你好", font.size, font.id)

    local layoutdata,codepoints,textw,texth = layout.prepare_text(
        fonttex_handle,
        sc.description,
        font.size,
        font.id,
        0xffff0000
    )

    local x, y = text_start_pos(textw, texth, sx, sy)
    local ro = e.render_object

    --local m = bgfx.memory_buffer(num*4 * fontquad_layout.stride)
    local m = bgfx.memory_buffer(#codepoints * 4 * fontquad_layout.stride)

    --local xx,yy=lfont.load_text_quad(m,  font.id,"ABCDE", x, y, fonttex_width, fonttex_height, font.size, sc.color)
    local offset=0

    for _, ld in ipairs(layoutdata) do
        --assert(ld.start > 0 and ld.start+ld.num <= #codepoints)
        local xx, yy = layout.load_text_quad(
            m, font.id, offset, x, y, fonttex_width, fonttex_height, font.size, ld.color,ld.num,ld.start
        )
        x = xx
        y = yy
        offset = offset+ld.num * 4
    end 
    --font.idx = add_text_mem(m, num, ro)
    font.idx = add_text_mem(m, #codepoints, ro)
end

local ev = world:sub {"show_name"}

function fontsys:component_init()
    for e in w:select "INIT font:in simplemesh:out owned_mesh_buffer?out" do
        fontpkg.import(fs.path(e.font.file))
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
        imaterial.set_property(e, "s_tex", fonttex_handle)
    end

    for e in w:select "font:in show_config:in scene:in render_object:update" do
        --if e.font.idx == nil then
            load_text(e)
        --end
    end
    lfont.submit()
end

function fontsys:entity_remove()
    for _, e in w:select "REMOVED font:in" do
        local idx = e.font.idx
        if idx then
            dvb:remove(idx)
        end
    end
end

function fontsys:exit()
    dvb:destroy()
end

function ecs.method.show_name(eid, attach)
    world:pub {"show_name", eid, attach}
end
