local ecs = ...
local world = ecs.world
local w = world.w
local image  = require "image"
local fastio = require "fastio"
local m = ecs.system "main_system"
local iatlas = import_package "ant.atlas"
local fs = require "bee.filesystem"
local vfs = require "vfs"

local vpath = "/pkg/ant.resources/textures/atlas"
local output = "/test/atlas/pkg/ant.test.atlas"
local rects = {}

for i = 1, 6 do
    table.insert(rects, {
        irpath = fs.current_path():string() .. vpath .. "/t" .. i .. ".png",
        arpath = fs.current_path():string() .. output .. "/t" .. i .. ".a"
    })
end

local atlas = {
    name = "test", x = 1, y = 1, w = 1024, h = 1024, bottom_y = 1,
    irpath = fs.current_path():string() .. output .. '/out.png',
    ivpath = "/pkg/ant.test.atlas/out.png",
    trpath = fs.current_path():string() .. output .. "/out.texture",
    tvpath = "/pkg/ant.test.atlas/out.texture",
    rects = rects
}

function m:init_world()
    iatlas.set_atlas(atlas)
end

local kb_mb         = world:sub{"keyboard"}
function m.data_changed()
    for _, key, press in kb_mb:unpack() do
        if key == "A" and press == 0 then
            iatlas.update_atlas(atlas)
        end
        if key == "B" and press == 0 then
            iatlas.clear_atlas(atlas)
        end
    end
end