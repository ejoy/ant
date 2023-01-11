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
local imaterial = ecs.import.interface "ant.asset|imaterial"
local ivs       = ecs.import.interface "ant.scene|ivisible_state"

local decl<const> = "p3|T4|t2"
local layout<const> = declmgr.get(decl)

local max_buffersize<const> = 1024 * 1024 * 10    --10 M
local bufferhandle<const> = bgfx.create_dynamic_vertex_buffer(max_buffersize, layout.handle)

local canvas_sys = ecs.system "canvas_system"

function canvas_sys:init()

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

local vec<const> = math3d.vector

local function trans_positions(m, v1, v2, v3, v4)
    v1, v2, v3, v4 = vec(v1), vec(v2), vec(v3), vec(v4)
    local center = math3d.mul(math3d.add(v1, v4), 0.5)
    local function trans(v)
        local vv = math3d.sub(v, center)
        return math3d.tovalue(math3d.add(math3d.transform(m, vv, 1), center))
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
            {u0, v1, 0.0}, {u0, v0, 0.0},
            {u1, v1, 0.0}, {u1, v0, 0.0}
    if tm then
        u0v1, u0v0, u1v1, u1v0 = trans_positions(tm, u0v1, u0v0, u1v1, u1v0)
    end

    local   vv1, vv2,
            vv3, vv4=
            {x,     0.0, z}, {x,     0.0, z+hh},
            {x+ww,  0.0, z}, {x+ww,  0.0, z+hh}

    local   vvt1, vvt2,
            vvt3, vvt4=
            math3d.vector(0.0, 0.0, -1.0), math3d.vector( 1.0, 0.0, 0.0),
            math3d.vector(0.0, 0.0,  1.0), math3d.vector(-1.0, 0.0, 0.0)

    local pm = posmat(rect.srt)
    if pm then
        vv1, vv2, vv3, vv4 = trans_positions(pm, vv1, vv2, vv3, vv4)
        vvt1, vvt2, vvt3, vvt4 = 
            math3d.transform(pm, vvt1, 0), math3d.transform(pm, vvt2, 0),
            math3d.transform(pm, vvt3, 0), math3d.transform(pm, vvt4, 0)
    end

    vvt1, vvt2, vvt3, vvt4 =
        math3d.tovalue(mu.pack_tangent_frame(mc.YAXIS, vvt1)), math3d.tovalue(mu.pack_tangent_frame(mc.YAXIS, vvt2)),
        math3d.tovalue(mu.pack_tangent_frame(mc.YAXIS, vvt3)), math3d.tovalue(mu.pack_tangent_frame(mc.YAXIS, vvt4))

    return itemfmt:pack(
        vv1[1], vv1[2], vv1[3], vvt1[1], vvt1[2], vvt1[3], vvt1[4], u0v1[1], u0v1[2],
        vv2[1], vv2[2], vv2[3], vvt2[1], vvt2[2], vvt2[3], vvt2[4], u0v0[1], u0v0[2],
        vv3[1], vv3[2], vv3[3], vvt3[1], vvt3[2], vvt3[3], vvt3[4], u1v1[1], u1v1[2],
        vv4[1], vv4[2], vv4[3], vvt4[1], vvt4[2], vvt4[3], vvt4[4], u1v0[1], u1v0[2])
end

local function get_texture_size(materialpath)
    local res = assetmgr.resource(materialpath)
    local texobj = assetmgr.resource(res.properties.s_basecolor.texture)
    local ti = texobj.texinfo
    return {w=ti.width, h=ti.height}
end

local function update_items()
    local bufferoffset = 0
    local buffers = {}
    for e in w:select "canvas:in" do
        local canvas = e.canvas
        local textures = canvas.textures
        for materialpath, tex in pairs(textures) do
            local values = {}
            local texsize = get_texture_size(materialpath)
            for _, v in pairs(tex.items) do
                values[#values+1] = add_item(texsize, v.texture, v)
            end

            if tex.renderer_eid then
                local hasitem = #values > 0
                if hasitem then
                    local re <close> = w:entity(tex.renderer_eid, "render_object:update")
                    local objbuffer = table.concat(values, "")
                    local ro = re.render_object

                    local buffersize = #objbuffer
                    local vbnum = buffersize//layout.stride
                    ro.vb_start, ro.vb_num = bufferoffset, vbnum
                    ro.ib_start, ro.ib_num = 0, (vbnum//4)*6

                    bufferoffset = bufferoffset + vbnum
                    buffers[#buffers+1] = objbuffer

                    ivs.set_state(re, "main_view", canvas.show)
                    ivs.set_state(re, "selectable", canvas.show)
                else
                    -- if no items to draw, should remove this entity
                    w:remove(tex.renderer_eid)
                    textures[materialpath] = nil
                end
            end
        end
    end

    if bufferoffset > 0 then
        local b = table.concat(buffers, "")
        assert(max_buffersize >= #b)
        bgfx.update(bufferhandle, 0, bgfx.memory_buffer(b))
    end
end

local canvas_texture_mb = world:sub{"canvas_update", "texture"}
function canvas_sys:data_changed()
    for _ in canvas_texture_mb:each() do
        update_items()
        break
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

local function create_texture_item_entity(materialpath, canvasentity, render_layer)
    w:extend(canvasentity, "eid:in canvas:in")
    local canvas_id = canvasentity.eid
    local canvas = canvasentity.canvas
    local eid; eid = ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh  = {
                vb = {
                    start = 0,
                    num = 0,
                    handle = bufferhandle,
                },
                ib = {
                    start = 0,
                    num = 0,
                    handle = irender.quad_ib(),
                }
            },
            material    = materialpath,
            scene       = {
                parent = canvas_id,
            },
            render_layer = render_layer or "ui",
            visible_state= "main_view",
            name        = "canvas_texture" .. gen_texture_id(),
            canvas_item = "texture",
            on_ready = function (e)
                --update renderer_eid
                local textures = canvas.textures
                local t = textures[materialpath]
                t.renderer_eid = eid
                world:pub{"canvas_update", "texture"}
                world:pub{"canvas_update", "new_entity", eid}
            end
        }
    }
    return eid
end

local gen_item_id = id_generator()
local item_cache = {}
function icanvas.add_items(e, materialpath, render_layer, ...)
    w:extend(e, "canvas:in")
    local canvas = e.canvas
    local textures = canvas.textures

    local added_items = {}

    for i=1, select("#", ...) do
        local item = select(i, ...)
        local t = textures[materialpath]
        if t == nil then
            create_texture_item_entity(materialpath, e, render_layer)
            t = {
                items = {},
            }
            textures[materialpath] = t
        end
        local id = gen_item_id()
        t.items[id] = item
        item_cache[id] = materialpath
        added_items[#added_items+1] = id
    end
    if #added_items > 0 then
        world:pub{"canvas_update", "texture"}
    end

    return added_items
end

local function get_texture(e, itemid)
    w:extend(e, "canvas:in")
    local canvas = e.canvas
    local textures = canvas.textures

    local texkey = assert(item_cache[itemid])
    return assert(textures[texkey])
end

function icanvas.remove_item(e, itemid)
    local t = get_texture(e, itemid)
    t.items[itemid] = nil
    item_cache[itemid] = nil
    world:pub{"canvas_update", "texture"}
end

local function get_item(e, itemid)
    local t = get_texture(e, itemid)
    return t.items[itemid]
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

    local textures = canvas.textures
    for _, tex in pairs(textures) do
        if tex.renderer_eid then
            local re <close> = w:entity(tex.renderer_eid)
            ivs.set_state(re, "main_view", b)
            ivs.set_state(re, "selectable", b)
        end
    end
end