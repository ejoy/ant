local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local renderpkg = import_package "ant.render"
local MESH      = world:clibs "render.mesh"
local layoutmgr = renderpkg.layoutmgr
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util

local assetmgr  = import_package "ant.asset"

local irender   = ecs.require "ant.render|render"
local decl<const> = "p3|T4|t2"
local layout<const> = layoutmgr.get(decl)

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

    assert(#r == #itemfmt*4, "Invalid vertex format")
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
        local cp = math3d.checkpoint()
        for _, v in pairs(de.canvas_drawer.items) do
            buffers[#buffers+1] = add_item(texsize, v.texture, v)
        end
        math3d.recover(cp)

        local objbuffer = table.concat(buffers, "")
        local vbnum = #objbuffer//layout.stride

        MESH.set_num(ro.mesh_idx, "vb0", vbnum)
        MESH.set_num(ro.mesh_idx, "ib", (vbnum//4)*6)
        local handle = MESH.fetch_handle(ro.mesh_idx, "vb0")
        bgfx.update(handle, 0, bgfx.memory_buffer(objbuffer))
    else
        ro.vb_num, ro.ib_num = 0, 0
    end
    w:submit(de)
end

local icanvas = {}

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

local function create_texture_item_entity(canvas_eid, show, materialpath, render_layer)
    return world:create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.terrain|canvas_drawer",
        },
        data = {
            mesh_result  = {
                vb = {
                    start = 0,
                    num = 0,
                    handle = bgfx.create_dynamic_vertex_buffer(1, layout.handle, "a"),
                },
                ib = {
                    start = 0,
                    num = 0,
                    handle = irender.quad_ib(),
					memory = true,	-- prevent to delete ib.handle
                }
            },
            material    = materialpath,
            scene       = {
                parent = canvas_eid,
            },
            render_layer = render_layer or "ui",
            visible = show,
            visible_masks = "main_view|selectable",
            canvas_drawer = {
                type = "texture",
                items = {},
            },
        }
    }
end

function icanvas.build(materials, canvas_eid, show, render_layer, ...)
    for i=1, select("#", ...) do
        local mp = select(i, ...)
        local key = ("%s|%s"):format(mp, render_layer)
        if nil == materials[key] then
            materials[key] = create_texture_item_entity(canvas_eid, show, mp, render_layer)
        end
    end
end

local item_cache = {}
function icanvas.add_items(e, key, ...)
    local newitem_count = select("#", ...)
    if newitem_count == 0 then
        return
    end

    w:extend(e, "canvas:in eid:in")
    local canvas = e.canvas
    local materials = canvas.materials

    local item_ids = {}
    local de = world:entity(materials[key], "canvas_drawer:in") or error (("%s materialpath is not found, use this materialpath to call icanvas.build() in 'init' stage"):format(key))
    local items = de.canvas_drawer.items

    for i=1, newitem_count do
        local id = gen_item_id()
        item_ids[#item_ids+1] = id
        assert(not items[id], "Duplicate item id!")

        items[id] = select(i, ...)

        item_cache[id] = key
    end
    update_drawer_items(de)
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
    local de = world:entity(deid, "canvas_drawer:in")
    if de.canvas_drawer.items[itemid] then
        de.canvas_drawer.items[itemid] = nil
        update_drawer_items(de)
    end
    item_cache[itemid] = nil
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
        local re <close> = world:entity(eid, "visible?out")
        irender.set_visible(re, b)
    end
end

return icanvas
