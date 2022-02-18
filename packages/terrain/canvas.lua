local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local assetmgr  = import_package "ant.asset"

local imaterial = ecs.import.interface "ant.asset|imaterial"
local irender   = ecs.import.interface "ant.render|irender"
local ifs       = ecs.import.interface "ant.scene|ifilter_state"

local decl<const> = "p3|t2"
local layout<const> = declmgr.get(decl)

local max_buffersize<const> = 1024 * 1024 * 10    --10 M
local bufferhandle<const> = bgfx.create_dynamic_vertex_buffer(max_buffersize, layout.handle)

local canvas_sys = ecs.system "canvas_system"

function canvas_sys:init()

end

local itemfmt<const> = ("fffff"):rep(4)

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
        if r then
            r = math3d.quaternion{0.0, r, 0.0}  --rotation with z-axis
        end
        if t then
            t = {t[1], 0.0, t[2]}
        end

        return math3d.matrix{s=s, r=r, t=t}
    end
end

local function add_item(texsize, tex, rect)
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

    local function trans(m, pt)
        return m and math3d.tovalue(math3d.transform(m, pt, 1)) or pt
    end

    local   u0v1 , u0v0 ,
            u1v1 , u1v0 = 
            trans(tm, {u0, v1, 0.0}), trans(tm, {u0, v0, 0.0}),
            trans(tm, {u1, v1, 0.0}), trans(tm, {u1, v0, 0.0})

    
    local   vv0, vv1,
            vv2, vv3=
            {x,     0.0, z}, {x,     0.0, z+hh},
            {x+ww,  0.0, z}, {x+ww,  0.0, z+hh}

    local pm = posmat(rect.srt)
    if pm then
        vv0, vv1, vv2, vv3 = math3d.vector(vv0), math3d.vector(vv1), math3d.vector(vv2), math3d.vector(vv3)
        local center = math3d.mul(math3d.add(vv0, vv3), 0.5)
        local function trans_pos(v, offset)
            local vv = math3d.sub(v, offset)
            return math3d.tovalue(math3d.transform(pm, vv, 1))
        end

        vv0 = trans_pos(vv0, center)
        vv1 = trans_pos(vv1, center)
        vv2 = trans_pos(vv2, center)
        vv3 = trans_pos(vv3, center)
    end

    return itemfmt:pack(
        vv0[1], vv0[2], vv0[3], u0v1[1], u0v1[2],
        vv1[1], vv1[2], vv1[3], u0v0[1], u0v0[2],
        vv2[1], vv2[2], vv2[3], u1v1[1], u1v1[2],
        vv3[1], vv3[2], vv3[3], u1v0[1], u1v0[2])
end

local function get_tex_size(texpath)
    local texobj = assetmgr.resource(texpath)
    local ti = texobj.texinfo
    return {w=ti.width, h=ti.height}
end

local function update_items()
    local bufferoffset = 0
    local buffers = {}
    for e in w:select "canvas:in" do
        local canvas = e.canvas
        local textures = canvas.textures
        for texpath, tex in pairs(textures) do
            local texsize = get_tex_size(texpath)
            local values = {}
            for _, v in pairs(tex.items) do
                values[#values+1] = add_item(texsize, v.texture, v)
            end

            local re = tex.renderer
            if re then
                local hasitem = #values > 0
                if hasitem then
                    local objbuffer = table.concat(values, "")
                    w:sync("render_object:in", re)
                    local ro = re.render_object

                    local buffersize = #objbuffer
                    local vbnum = buffersize//layout.stride
                    local vb = ro.vb
                    vb.start = bufferoffset
                    vb.num = vbnum

                    bufferoffset = bufferoffset + vbnum

                    local ib = ro.ib
                    ib.start = 0
                    ib.num = (vbnum//4)*6

                    
                    buffers[#buffers+1] = objbuffer
                end

                --TODO: if no items to draw, should remove this entity
                ifs.set_state(re, "main_view", hasitem)
                ifs.set_state(re, "selectable", hasitem)
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

local function create_texture_item_entity(texpath, canvasentity)
    w:sync("reference:in canvas:in", canvasentity)
    local canvas_ref = canvasentity.reference
    local canvas = canvasentity.canvas
    return ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            reference = true,
            simplemesh  = {
                vb = {
                    start = 0,
                    num = 0,
                    {
                        handle = bufferhandle,
                    }
                },
                ib = {
                    start = 0,
                    num = 0,
                    handle = irender.quad_ib(),
                }
            },
            material    = "/pkg/ant.resources/materials/canvas_texture.material",
            scene       = {srt={}},
            filter_state= "main_view",
            name        = "canvas_texture" .. gen_texture_id(),
            canvas_item = "texture",
            on_ready = function (e)
                local texobj = assetmgr.resource(texpath)
                imaterial.set_property(e, "s_basecolor", {texture=texobj, stage=0})

                --update parent
                w:sync("reference:in", e)
                
                local objref = e.reference
                ecs.method.set_parent(objref, canvas_ref)

                --update renderer
                local textures = canvas.textures
                local t = textures[texpath]
                t.renderer = e.reference
                world:pub{"canvas_update", "texture"}
            end
        }
    }
end

local gen_item_id = id_generator()
local item_cache = {}
function icanvas.add_items(e, ...)
    w:sync("canvas:in", e)
    local canvas = e.canvas
    local textures = canvas.textures

    local n = select("#", ...)
    
    local added_items = {}
    for i=1, n do
        local item = select(i, ...)
        local texture = item.texture
        local texpath = texture.path
        local t = textures[texpath]
        if t == nil then
            create_texture_item_entity(texpath, e)
            t = {
                items = {},
            }
            textures[texpath] = t
        end
        local id = gen_item_id()
        t.items[id] = item
        item_cache[id] = texpath
        added_items[#added_items+1] = id
    end
    if n > 0 then
        world:pub{"canvas_update", "texture"}
    end

    return added_items
end

local function get_texture(e, itemid)
    w:sync("canvas:in", e)
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