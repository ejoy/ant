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
        e.modifier.update(delta_time)
    end
end

function modifier_sys:exit()

end

function imodifier.create_srt_modifier(target, generator, replace)
    local init_mat = replace and mc.IDENTITY_MAT or math3d.ref(math3d.matrix(world:entity(target).scene.srt))
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
                update = function(time) iom.set_srt_matrix(world:entity(target), math3d.mul(init_mat, generator(time))) end
            },
		},
    }
    local eid = ecs.create_entity(template)
    ecs.method.set_parent(eid, target)
    return eid
end

function imodifier.create_bone_modifier(target, filename, bone_name)
    local anim_inst = ecs.create_instance(filename)
    return imodifier.create_srt_modifier(target, function (time)
        local all_e = anim_inst.tag["*"]
        local anim = world:entity(all_e[2])
        local pr = anim.anim_ctrl.pose_result
        return math3d.mul(math3d.matrix(world:entity(all_e[1]).scene.srt), math3d.mul(mc.R2L_MAT, pr:joint(anim.skeleton._handle:joint_index(bone_name))))
    end), anim_inst
end

