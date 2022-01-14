local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx = require "bgfx"

local declmgr = require "vertexdecl_mgr"

local assetmgr = import_package "ant.asset"

local imaterial = ecs.import.interface "ant.asset|imaterial"
local irender = ecs.import.interface "ant.render|irender"

local decl<const> = "p3|t2"
local layout<const> = declmgr.get(decl)
local layoutfmt<const> = declmgr.vertex_desc_str(declmgr.correct_layout(decl))

local buffer = {}

function buffer:create(size)
    self.buffer_size = size
    self.handle = bgfx.create_dynamic_vertex_buffer(size, layout.handle)
end

function buffer:remove()
    self.buffer_size = 0
    bgfx.destroy(self.handle)
    self.data = nil
end

function buffer:update()
    bgfx.update(self.handle, 0, assert(self.data))
end

buffer:create(1024 * 1024 * 10)    --10 M

local canvas_sys = ecs.system "canvas_system"

function canvas_sys:init()

end


local icanvas = ecs.interface "icanvas"

function icanvas.create_canvas(transform, name)
    return ecs.create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.terrain|canvas",
            "ant.general|name",
        },
        data = {
            name = name,
            scene = {srt=transform},
            reference = true,
            canvas = {
                textures = {},
                texts = {},
            },
        }
    }
end

local textureid = 0
local function gen_texture_id()
    local id = textureid
    textureid = id + 1
    return id
end

local function create_texture_item_entity(texture, start, num)
    return ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh  = {
                vb = {
                    start = start,
                    num = num,
                    handles = {
                        buffer.handle,
                    }
                },
                ib = {
                    start = 0,
                    num = (num // 4) * 6,
                    handle = irender.quad_ib(),
                }
            },
            material    = "/pkg/ant.resources/materials/canvas_texture.material",
            scene       = {srt={}},
            filter_state= "main_view",
            name        = "canvas_texture" .. gen_texture_id(),
            on_ready = function (e)
                imaterial.set_property(e, "u_image", texture)
            end
        }
    }
end

local function add_item(item, imagesize)
    local rt = item.rect
    local ww, hh = rt.w, rt.h
    local hww, hhh = ww*0.5, hh*0.5
    local x, z = item.x, item.y

    local iw, ih = imagesize.w, imagesize.h
    local fmt = "fffff"
    local vv = {
        fmt:format(x-hww, 0.0, z-hhh, rt.x/iw, (rt.y+hh)/ih),
        fmt:format(x-hww, 0.0, z+hhh, rt.x/iw, rt.y/ih),
        fmt:format(x+hww, 0.0, z+hhh, (rt.x+ww)/iw, rt.y/ih),
        fmt:format(x+hww, 0.0, z-hhh, (rt.x+ww)/iw, (rt.y+hh)/ih),
    }
    return table.concat(vv, "")
end

local function create_buffer_data(itemsize)
    local startidx
    if buffer.data then
        local olddata = tostring(buffer.data)
        buffer.data = bgfx.memory_buffer(#olddata + itemsize)
        startidx = #olddata
        buffer.data[1] = olddata
    else
        startidx = 0
        buffer.data = bgfx.memory_buffer(itemsize)
    end
    return buffer.data, startidx
end

function icanvas.add_items(e, items)
    w:sync("canvas:in", e)
    local canvas = e.canvas
    local textures = canvas.textures
    local n = #items
    local itemsize = n * layout.stride
    local data, startidx = create_buffer_data(itemsize)

    for _=1, n do
        local item = items[n]
        local texture = item.texture
        local t = textures[texture]
        if t == nil then
            local texobj = assetmgr.load(texture)
            t = {
                renderer = create_texture_item_entity(texobj, startidx),
                texobj = texobj,
            }
            textures[texture] = t
        end
        data[startidx] = add_item(t)
    end

    buffer:update()
end
