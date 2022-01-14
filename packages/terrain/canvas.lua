local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx      = require "bgfx"

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local assetmgr  = import_package "ant.asset"

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

local canvas_texture_mb = world:sub{"canvas_update", "texture"}
function canvas_sys:data_changed()
    for _ in canvas_texture_mb:each() do
        for e in w:select "canvas:in" do
            local canvas = e.canvas
            local textures = canvas.textures
            local tt = {}
            
            for p, obj in pairs(canvas.textures) do
                tt[#tt+1] = p
                for _, it in ipairs(obj.items) do
                    
                end
            end
            table.sort(tt)
            for _, n in ipairs(tt) do
                local tex = textures[n]
                local re = tex.renderer
                w:sync("render_object:in", re)
                local ro = re.render_object

            end
        end
    end
end

local icanvas = ecs.interface "icanvas"

local textureid = 0
local function gen_texture_id()
    local id = textureid
    textureid = id + 1
    return id
end

local function create_texture_item_entity(texobj)
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
                    handles = {
                        buffer.handle,
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
                imaterial.set_property(e, "u_image", {texture=texobj, stage=0})
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

function icanvas.add_items(e, ...)
    w:sync("canvas:in", e)
    local canvas = e.canvas
    local textures = canvas.textures

    local n = select("#", ...)
    
    for i=1, n do
        local item = select(i, ...)
        local texture = item.texture
        local texpath = texture.path
        local t = textures[texpath]
        if t == nil then
            local texobj = assetmgr.resource(texpath)
            t = {
                renderer = create_texture_item_entity(texobj),
                items = {},
            }
            textures[texpath] = t
        end
        t.items[#t.items+1] = add_item(t, texture.size)
    end
    if n > 0 then
        world:pub{"canvas_update", "texture"}
    end
end

function icanvas.remove_item(e, texpath, idx)
    world:pub{"canvas_update", "texture"}
end

function icanvas.add_text(e, ...)
    for i=1, select('#', ...) do
        local t = select(1, ...)
        ---
    end
end