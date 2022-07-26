local ecs = ...
local world = ecs.world

local w = world.w

local initsys = ecs.system "init_system"
function initsys:init()
    print "init"
end

function initsys:data_changed()
    print "data_changed"
end

function initsys:simpleecs()
    print "simpleecs"
end

function initsys:update()
    print "update"
end

function initsys:exit()
    print "exit"
end