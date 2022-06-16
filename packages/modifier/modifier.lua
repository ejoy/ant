local ecs 	= ...
local world = ecs.world
local w 	= world.w

local modifier_sys = ecs.system "modifier_system"
local imodifier = ecs.interface "imodifier"
local iani      = ecs.import.interface "ant.animation|ianimation"
local timer     = ecs.import.interface "ant.timer|itimer"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util
local math3d    = require "math3d"

function modifier_sys:init()

end

function modifier_sys:component_init()
    for e in w:select "INIT modifier:in" do

    end
end

function modifier_sys:update_modifier()
    local delta_time = timer.delta() * 0.001
    for e in w:select "modifier:in" do
        e.modifier:update(delta_time)
    end
end

function modifier_sys:exit()

end

function imodifier.create_srt_modifier(target, generator, replace)
	local template = {
		policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.modifier|modifier",
		},
		data = {
            name = "",
            scene = {srt = {}},
            modifier = {
                target = target,
                continue = false,
                replace = replace,
                init_mat = replace and mc.IDENTITY_MAT or math3d.ref(math3d.matrix(world:entity(target).scene.srt)),
                update = function(self, time)
                    if not self.continue then
                        return
                    end
                    local value, running = generator(time)
                    iom.set_srt_matrix(world:entity(self.target), value and math3d.mul(self.init_mat, value) or self.init_mat)
                    self.continue = running
                end
            },
		},
    }
    local eid = ecs.create_entity(template)
    ecs.method.set_parent(eid, target)
    return eid
end

function imodifier.start(m, anim_name, forwards)
    local mf = world:entity(m.eid).modifier
    mf.continue = true
    if m.anim then
        mf.init_mat = mf.replace and mc.IDENTITY_MAT or math3d.ref(math3d.matrix(world:entity(mf.target).scene.srt))
        iani.play(m.anim, {name = anim_name, forwards = forwards})
    end
end

function imodifier.stop(m)
    world:entity(m.eid).modifier.continue = false
end

function imodifier.create_bone_modifier(target, filename, bone_name)
    local anim_inst = ecs.create_instance(filename)
    return {
        eid = imodifier.create_srt_modifier(target, function (time)
            local anim = world:entity(anim_inst.tag["*"][2])
            local pr = anim.anim_ctrl.pose_result
            return pr:joint(anim.skeleton._handle:joint_index(bone_name)), anim.anim_ctrl._current.play_state.play
        end),
        anim = anim_inst
    }
end

