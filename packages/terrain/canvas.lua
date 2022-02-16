local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx      = require "bgfx"

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
local function add_item(tex, rect)
    local texsize, texrt = tex.size, tex.rect
    local t_ww, t_hh = texrt.w, texrt.h

    local x, z = rect.x, rect.y
    local ww, hh = rect.w, rect.h

    local iw, ih = texsize.w, texsize.h
    --[[
        1---3
        |   |
        0---2
    ]]
    local u0, v0 = texrt.x/iw, texrt.y/ih
    local u1, v1 = (texrt.x+t_ww)/iw, (texrt.y+t_hh)/ih

    return itemfmt:pack(
        x,     0.0, z,     u0, v1,
        x,     0.0, z+hh,  u0, v0,
        x+ww,  0.0, z,     u1, v1,
        x+ww,  0.0, z+hh,  u1, v0)
end

local function update_items()
    local bufferoffset = 0
    local buffers = {}
    for e in w:select "canvas:in" do
        local canvas = e.canvas
        local textures = canvas.textures
        for _, tex in pairs(textures) do
            local values = {}
            for _, v in pairs(tex.items) do
                values[#values+1] = add_item(v.texture, v)
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

                    local ib = ro.ib
                    ib.start = 0
                    ib.num = (vbnum//4)*6

                    bufferoffset = bufferoffset + buffersize
                    buffers[#buffers+1] = objbuffer
                end

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

local function update_item(item, posrect, tex)
    local changed
    if posrect then
        item.x, item.y = posrect.x, posrect.y
        item.w, item.h = posrect.w, posrect.h
        changed = true
    end

    if tex then
        local itex = item.texture
        if tex.size then
            itex.size.w, itex.size.h = tex.size.w, tex.size.h
            changed = true
        end
    
        local rt = itex.rect
        if rt then
            rt.x, rt.y = tex.ect.x, tex.rect.y
            rt.w, rt.h = tex.ect.w, tex.rect.h
            changed = true
        end
    end

    if changed then
        world:pub{"canvas_update", "texture"}
    end
end

function icanvas.update_item_rect(e, itemid, rect)
    update_item(get_item(e, itemid), rect)
end

function icanvas.update_item_tex(e, itemid, tex)
    update_item(get_item(e, itemid), nil, tex)
end

function icanvas.update_item(e, itemid, item)
    update_item(get_item(e, itemid), item, item.texture)
end

function icanvas.add_text(e, ...)
    for i=1, select('#', ...) do
        local t = select(1, ...)
        ---
    end
end