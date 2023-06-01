local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util

local assetmgr  = import_package "ant.asset"

local irender   = ecs.import.interface "ant.render|irender"
local ivs       = ecs.import.interface "ant.scene|ivisible_state"

local decl<const> = "p3|T4|t2"
local layout<const> = declmgr.get(decl)

local canvas_sys = ecs.system "canvas_system"

function canvas_sys:component_init()
    for e in w:select "INIT canvas:in" do
        e.canvas.materials = {}
    end
end

--[[
    fff-> position
    ffff->pack tangent frame
    ff-> uv
]]
local itemfmt<const> = ("fffffffff"):rep(4)

local function texmat(srt)
    if srt then
        local s, r, t = srt.s, srt.r, srt.t
        if s then
            s = {s[1], s[2], 1.0}
        end
        if r then
            r = math3d.quaternion{0.0, 0.0, r}  --rotation with z-axis
        end
        if t then
            t = {t[1], t[2], 0.0}
        end

        return math3d.matrix{s=s, r=r, t=t}
    end
end

local function posmat(srt)
    if srt then
        local s, r, t = srt.s, srt.r, srt.t
        if s then
            s = {s[1], 1.0, s[2]}
        end
        if t then
            t = {t[1], 0.0, t[2]}
        end

        return math3d.matrix{s=s, r=r, t=t}
    end
end

local function trans_positions(m, v1, v2, v3, v4)
    local center = math3d.mul(math3d.add(v1, v4), 0.5)
    local function trans(v)
        local vv = math3d.sub(v, center)
        return math3d.add(math3d.transform(m, vv, 1), center)
    end

    return trans(v1), trans(v2), trans(v3), trans(v4)
end

local function add_item(texsize, tex, rect)
    --TODO: we should pack item when add or update
    local iw, ih = texsize.w, texsize.h
    local texrt = tex.rect
    local tm = texmat(tex.srt)
    local t_ww, t_hh = texrt.w or iw, texrt.h or ih

    local x, z = rect.x, rect.y
    local ww, hh = rect.w, rect.h
    --[[
        1---3
        |   |
        0---2
    ]]
    local u0, v0 = texrt.x/iw, texrt.y/ih
    local u1, v1 = (texrt.x+t_ww)/iw, (texrt.y+t_hh)/ih

    local   u0v1, u0v0,
            u1v1, u1v0 = 
            math3d.vector(u0, v1, 0.0), math3d.vector(u0, v0, 0.0),
            math3d.vector(u1, v1, 0.0), math3d.vector(u1, v0, 0.0)
    if tm then
        u0v1, u0v0, u1v1, u1v0 = trans_positions(tm, u0v1, u0v0, u1v1, u1v0)
    end

    local   vv1, vv2,
            vv3, vv4=
            math3d.vector(x,     0.0, z), math3d.vector(x,     0.0, z+hh),
            math3d.vector(x+ww,  0.0, z), math3d.vector(x+ww,  0.0, z+hh)

    local   vvt1, vvt2,
            vvt3, vvt4=
            mc.NZAXIS, mc.XAXIS,
            mc.ZAXIS,  mc.NXAXIS

    local pm = posmat(rect.srt)
    if pm then
        vv1, vv2, vv3, vv4 = trans_positions(pm, vv1, vv2, vv3, vv4)
        vvt1, vvt2, vvt3, vvt4 = 
            math3d.transform(pm, vvt1, 0), math3d.transform(pm, vvt2, 0),
            math3d.transform(pm, vvt3, 0), math3d.transform(pm, vvt4, 0)
    end

    vvt1, vvt2, vvt3, vvt4 =
    mu.pack_tangent_frame(mc.YAXIS, vvt1), mu.pack_tangent_frame(mc.YAXIS, vvt2),
    mu.pack_tangent_frame(mc.YAXIS, vvt3), mu.pack_tangent_frame(mc.YAXIS, vvt4)

    u0v1, u0v0, u1v1, u1v0 = 
    math3d.serialize(u0v1), math3d.serialize(u0v0), 
    math3d.serialize(u1v1), math3d.serialize(u1v0)

    vv1, vv2, vv3, vv4 = 
    math3d.serialize(vv1), math3d.serialize(vv2), 
    math3d.serialize(vv3), math3d.serialize(vv4)

    vvt1, vvt2, vvt3, vvt4 =
    math3d.serialize(vvt1), math3d.serialize(vvt2),
    math3d.serialize(vvt3), math3d.serialize(vvt4)

    local r = ("c12c16c8"):rep(4):pack(
        vv1:sub(1, 12), vvt1, u0v1:sub(1, 8),
        vv2:sub(1, 12), vvt2, u0v0:sub(1, 8),
        vv3:sub(1, 12), vvt3, u1v1:sub(1, 8),
        vv4:sub(1, 12), vvt4, u1v0:sub(1, 8))

    assert(#r ~= #itemfmt*4*4, "Invalid vertex format")
    return r
end

local function get_texture_size(materialpath)
    local res = assetmgr.resource(materialpath)
    local texobj = assetmgr.resource(res.properties.s_basecolor.texture)
    local ti = texobj.texinfo
    return {w=ti.width, h=ti.height}
end

local function update_drawer_items(de)
    w:extend(de, "canvas_drawer:in material:in render_object:update")
    local ro = de.render_object
    if next(de.canvas_drawer.items) then
        local buffers = {}
        local texsize = get_texture_size(de.material)
        for _, v in pairs(de.canvas_drawer.items) do
            buffers[#buffers+1] = add_item(texsize, v.texture, v)
        end
    
        local objbuffer = table.concat(buffers, "")
        local vbnum = #objbuffer//layout.stride
        ro.vb_start, ro.vb_num = 0, vbnum
        ro.ib_start, ro.ib_num = 0, (vbnum//4)*6

        bgfx.update(ro.vb_handle, 0, bgfx.memory_buffer(objbuffer))
    else
        ro.vb_num, ro.ib_num = 0, 0
    end
    w:submit(de)
end

local canvas_mb = world:sub{"canvas_update", "add_items"}

function canvas_sys:data_changed()
    for _, _, eid, items in canvas_mb:unpack() do
        local de = w:entity(eid, "canvas_drawer:in")
        local citems = de.canvas_drawer.items
        for id, item in pairs(items) do
            assert(citems[id] == nil, "Ivalid item id!")
            citems[id] = item
        end
        update_drawer_items(de)
    end
end

local icanvas = ecs.interface "icanvas"

local function id_generator()
    local id = 0
    return function()
        local ii = id
        id = ii + 1
        return ii
    end
end

local gen_texture_id = id_generator()
local gen_item_id = id_generator()

local function create_texture_item_entity(materialpath, render_layer)
    return ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh  = {
                vb = {
                    start = 0,
                    num = 0,
                    handle = bgfx.create_dynamic_vertex_buffer(1, layout.handle, "a"),
                    owned = true
                },
                ib = {
                    start = 0,
                    num = 0,
                    handle = irender.quad_ib(),
                }
            },
            owned_mesh_buffer = true,
            material    = materialpath,
            scene       = {},
            render_layer = render_layer or "ui",
            visible_state= "main_view|selectable",
            name        = "canvas_texture" .. gen_texture_id(),
            canvas_drawer = {
                type = "texture",
                items = {},
            },
        }
    }
end

local item_cache = {}
function icanvas.add_items(e, materialpath, render_layer, ...)
    w:extend(e, "canvas:in")
    local canvas = e.canvas
    local materials = canvas.materials

    local item_ids = {}
    local items = {}
    for i=1, select("#", ...) do
        local item = select(i, ...)
        
        local id = gen_item_id()
        item_ids[#item_ids+1] = id
        items[id] = item

        item_cache[id] = materialpath
    end

    local itemeid = materials[materialpath]
    if itemeid == nil then
        itemeid = create_texture_item_entity(materialpath, render_layer)
        materials[materialpath] = itemeid
    end

    world:pub{"canvas_update", "add_items", itemeid, items}
    return item_ids
end

local function find_drawer_eid(e, itemid)
    w:extend(e, "canvas:in")
    local mp = assert(item_cache[itemid], "Ivalid itemid")
    local materials = e.canvas.materials
    return assert(materials[mp], "Invalid itemid, nout found valid materialpath")
end

function icanvas.remove_item(e, itemid)
    local deid = find_drawer_eid(e, itemid)
    local de = w:entity(deid, "canvas_drawer:in")
    if de.canvas_drawer.items[itemid] then
        de.canvas_drawer.items[itemid] = nil
        update_drawer_items(de)
    end
    item_cache[itemid] = nil
end

local function get_item(e, itemid)
    local deid = find_drawer_eid(e, itemid)
    local de = w:entity(deid, "canvas_drawer:in")
    return assert(de.canvas_drawer.items[itemid], "Invalid itemid")
end

local function update_item(item, posrect, tex_rect)
    local changed
    if posrect then
        item.x, item.y = posrect.x, posrect.y
        item.w, item.h = posrect.w, posrect.h
        changed = true
    end

    if tex_rect then
        local rt = item.texture.rect

        rt.x, rt.y = tex_rect.x, tex_rect.y
        rt.w, rt.h = tex_rect.w, tex_rect.h
        changed = true
    end

    if changed then
        world:pub{"canvas_update", "texture"}
    end
end

function icanvas.update_item_rect(e, itemid, rect)
    update_item(get_item(e, itemid), rect)
end

function icanvas.update_item_tex_rect(e, itemid, texrect)
    update_item(get_item(e, itemid), nil, texrect)
end

function icanvas.update_item(e, itemid, item)
    update_item(get_item(e, itemid), item, item.texture.rect)
end

function icanvas.add_text(e, ...)
    for i=1, select('#', ...) do
        local t = select(1, ...)
        ---
    end
end

function icanvas.show(e, b)
    w:extend(e, "canvas:in")
    local canvas = e.canvas
    canvas.show = b

    for _, eid in pairs(canvas.materials) do
        local re <close> = w:entity(eid)
        ivs.set_state(re, "main_view|selectable", b)
    end
end