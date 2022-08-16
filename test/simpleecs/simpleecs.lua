local ecs = ...
local world = ecs.world

local w = world.w

local initsys = ecs.system "init_system"
function initsys:init()
    ecs.create_entity{
        policy = {
            "ant.test.simpleecs|testpolicy",
            "ant.test.simpleecs|name",
        },
        data = {
            name = "test",
            simpleecs = {
                id = 1,
            }
        }
    }
    print "init"
end

function initsys:data_changed()
    print "data_changed"

    for e in w:select "testtab" do
        print "will not came here"
    end

    for e in w:select "simpleecs:in testtab?out" do
        e.simpleecs.id = e.simpleecs.id + 1
        e.testtab = true
    end

    for e in w:select "testtab" do
        print(e.simpleecs)
        w:extend(e, "simpleecs:in")
        print(e.simpleecs)
    end
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