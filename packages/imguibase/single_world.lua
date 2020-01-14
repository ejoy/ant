local runtime = require "runtime_cb"
local inputmgr = require "inputmgr"
local keymap = require "keymap"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local rhwi = renderpkg.hwi

local single_world = {}

local packages,system 

function single_world.init(nwh, context, width, height)
    local su = import_package "ant.scene".util
    world = su.start_new_world(width, height, packages, systems)
    world_update = su.loop(world)
    single_world.world = world
end

function single_world.mouse_wheel(x, y, delta)
    iq:push("mouse_wheel", x, y, delta)
end

function single_world.mouse(x, y, what, state)
    iq:push("mouse", x, y, inputmgr.translate_mouse_button(what), inputmgr.translate_mouse_state(state))
end

function single_world.touch(x, y, id, state)
    iq:push("touch", x, y, id, inputmgr.translate_mouse_state(state))
end

function single_world.keyboard(key, press, state)
    iq:push("keyboard", keymap[key], press, inputmgr.translate_key_state(state))
end

function single_world.size(width,height,_)
    iq:push("resize", width,height)
end

function single_world.exit()

end

function single_world.update()
    if world_update then
        world_update()
        return true
    end
end

function single_world.start(pkgs, sys)
    packages, systems = pkgs, sys
    runtime.start(single_world)
end

return single_world