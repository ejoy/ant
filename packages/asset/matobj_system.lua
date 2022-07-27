local ecs = ...

local matobj    = require "matobj"
matobj.rmat     = ecs.clibs "render.material"

local mos       = ecs.system "matobj_system"

function mos:init()
    matobj.color_palettes   = ecs.require "color_palette"
    matobj.sa			    = ecs.require "system_attribs"
end
