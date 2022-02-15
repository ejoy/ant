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

local max_buffersize<const> = 1024 * 1024 * 10    --10 M
local bufferhandle<const> = bgfx.create_dynamic_vertex_buffer(max_buffersize, layout.handle)

local canvas_sys = ecs.system "canvas_system"

function canvas_sys:init()

end

local canvas_texture_mb = world:sub{"canvas_update", "texture"}
function canvas_sys:data_changed()
    for _ in canvas_texture_mb:each() do
        local bufferoffset = 0
        local buffers = {}
        for e in w:select "canvas:in" do
            local canvas = e.canvas
            local textures = canvas.textures
            local tt = {}
            for p in pairs(canvas.textures) do
                tt[#tt+1] = p
            end
            table.sort(tt)

            for _, n in ipairs(tt) do
                local tex = textures[n]
                local re = tex.renderer
                local objbuffer = table.concat(tex.items, "")
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
        end

        if bufferoffset > 0 then
            local b = table.concat(buffers, "")
            assert(max_buffersize >= #b)
            bgfx.update(bufferhandle, 0, bgfx.memory_buffer(b))
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

local function create_texture_item_entity(texobj, canvasentity)
    w:sync("reference:in", canvasentity)
    local parentref = canvasentity.reference
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
                w:sync("reference:in", e)
                ecs.method.set_parent(e.reference, parentref)
                imaterial.set_property(e, "s_basecolor", {texture=texobj, stage=0})
            end
        }
    }
end

local function add_item(item)
    local tex = item.texture
    local texsize, texrt = tex.size, tex.rect
    local t_ww, t_hh = texrt.w, texrt.h

    local x, z = item.x, item.y
    local ww, hh = item.w, item.h
    local hww, hhh = ww*0.5, hh*0.5

    local iw, ih = texsize.w, texsize.h
    local fmt = "fffff"
    --[[
        1---3
        |   |
        0---2
    ]]
    local vv = {
        fmt:pack(x-hww, 0.0, z-hhh, texrt.x/iw, (texrt.y+t_hh)/ih),
        fmt:pack(x-hww, 0.0, z+hhh, texrt.x/iw, texrt.y/ih),
        fmt:pack(x+hww, 0.0, z-hhh, (texrt.x+t_ww)/iw, texrt.y/ih),
        fmt:pack(x+hww, 0.0, z+hhh, (texrt.x+t_ww)/iw, (texrt.y+t_hh)/ih),
    }
    return table.concat(vv, "")
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
                renderer = create_texture_item_entity(texobj, e),
                items = {},
            }
            textures[texpath] = t
        end
        t.items[#t.items+1] = add_item(item)
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