local ecs = ...

local matobj    = require "matobj"
matobj.rmat     = ecs.clibs "render.material"
matobj.rmat.init()

local mos       = ecs.system "matobj_system"

function mos:init()
    matobj.color_palettes   = ecs.require "color_palette"
    matobj.sa			    = ecs.require "system_attribs"
end

function mos:exit()
    matobj.color_palettes = nil
    matobj.sa = nil
    matobj.rmat.release()
    matobj.rmat = nil
    local assetmgr = require "main"
    assetmgr.unload_all()
end
