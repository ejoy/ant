local ecs 	= ...
local world = ecs.world
local w 	= world.w

local serialize = import_package "ant.serialize"

local modifier_sys = ecs.system "modifier_system"
local iani      = ecs.require "ant.anim_ctrl|state_machine"
local timer     = ecs.require "ant.timer|timer_system"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local ika       = ecs.require "ant.anim_ctrl|keyframe"
local imaterial = ecs.require "ant.asset|material"
local mathpkg	= import_package "ant.math"
local aio = import_package "ant.io"
local mc	= mathpkg.constant
local math3d    = require "math3d"

local imodifier = {}
local auto_destroy_map = {}
function modifier_sys:init()

end

function modifier_sys:component_init()
    for e in w:select "INIT modifier:in" do

    end
end

local modifierevent = world:sub {"modifier"}
function modifier_sys:start_frame()
    for _, m, desc in modifierevent:unpack() do
        local e <close> = world:entity(m.eid, "modifier?in")
        if not e or not e.modifier then
            goto continue
        end
        local mf = e.modifier
        mf.continue = true
        mf.keep = desc.forwards
        mf.destroy = desc.destroy
        mf.init_srt = desc.init_srt
        if m.anim_eid then
            if desc.name then
                iani.play(m.anim_eid, desc)
            else
                local anim <close> = world:entity(m.anim_eid)
                ika.play(anim, desc)
            end
        end
        ::continue::
    end
end
function modifier_sys:update_modifier()
    local delta_time = timer.delta() * 0.001
    local to_remove = {}
    for e in w:select "modifier:in eid:in" do
        local rm = e.modifier:update(delta_time)
        if rm then
            to_remove[#to_remove + 1] = e.eid
        end
    end
    for _, eid in ipairs(to_remove) do
        imodifier.delete(auto_destroy_map[eid])
        auto_destroy_map[eid] = nil
    end
end


function modifier_sys:entity_ready()

end
function modifier_sys:exit()

end

function imodifier.delete(m)
    if not m then
        return
    end
    -- local e <close> = world:entity(m.eid, "modifier:in")
    -- local mf = e.modifier
    -- if mf.target then
    --     mf:reset()
    -- end
    w:remove(m.eid)
    if type(m.anim_eid) == "table" then
        world:remove_instance(m.anim_eid)
    else
        w:remove(m.anim_eid)
    end
end

function imodifier.set_target(m, target)
    if not m then
        return
    end
    local e <close> = world:entity(m.eid, "modifier:in")
    local mf = e.modifier
    if target == mf.target then
        return
    end
    local iv
    if mf.property then
        -- material
        if not target then
            return
        end
        local me <close> = world:entity(target, "material:in")
        local filename = me.material
        if not filename then
            return
        end
        filename = filename .. "/source.ant"
        local mtl = serialize.parse(filename, aio.readall(filename))
        if not mtl.properties[mf.property] then
            return
        end
        iv = math3d.ref(math3d.vector(mtl.properties[mf.property]))
    end
    if mf.target then
        mf:reset()
    end
    mf.init_value = iv
    mf.target = target
end

function imodifier.create_mtl_modifier(target, property, keyframes, keep, foreupdate)
    local function get_value(kfe, time)
        local e <close> = world:entity(kfe, "keyframe:in")
        local kfanim = e.keyframe
        return kfanim.play_state.current_value, kfanim.play_state.playing
    end

    local init_value
    if target then
        local e <close> = world:entity(target, "material:in")
        local filename = e.material .. "/source.ant"
        local mtl = serialize.parse(filename, aio.readall(filename))
        assert(mtl.properties[property])
        init_value = math3d.ref(math3d.vector(mtl.properties[property]))
    end

    local kfeid = ika.create(keyframes)

    local template = {
		policy = {
            "ant.scene|scene_object",
            "ant.modifier|modifier",
		},
		data = {
            scene = {},
            modifier = {
                target = target,
                continue = false,
                property = property,
                init_value = init_value,
                keep = keep,
                foreupdate = foreupdate,
                kfeid = kfeid,
                reset = function (self)
                    local e <close> = world:entity(self.target)
                    if not e then
                        return
                    end
                    imaterial.set_property(e, self.property, self.init_value)
                end,
                update = function(self, time)
                    if not self.target or (not self.foreupdate and not self.continue) then
                        return
                    end
                    local value, running = get_value(self.kfeid, time)
                    local apply_value = value and math3d.vector(value) or self.init_value
                    if not running and not self.keep and not self.foreupdate then
                        apply_value = self.init_value
                    end
                    local e <close> = world:entity(self.target)
                    if not e then
                        return
                    end
                    imaterial.set_property(e, self.property, apply_value)
                    self.continue = running
                end
            }
        }
    }
    return {
        eid = world:create_entity(template),
        anim_eid = kfeid
    }
end

local keyframes_cache = {}
function imodifier.clear_keyframes_cache()
    keyframes_cache = {}
end

function imodifier.keyframes_from_anim_data(anim_type, anim_data, frame_count, sample_ratio)
    local get_keyframe_value = function(type, clip, init)
        if type == "mtl" then
            local value = {}
            for _, v in ipairs(clip.value) do
                value[#value + 1] = v * clip.scale
            end
            return value
        elseif type == "srt" then
            local value = init and {init[1], init[2], init[3], init[4], init[5], init[6], init[7]} or {1, 0, 0, 0, 0, 0, 0}
            value[clip.rot_axis + 1] = clip.amplitude_rot
            if clip.direction < 4 then
                value[clip.direction + 4] = clip.amplitude_pos
            elseif clip.direction == 4 then--XY
                value[5] = clip.amplitude_pos
                value[6] = clip.amplitude_pos
            elseif clip.direction == 5 then--YZ
                value[6] = clip.amplitude_pos
                value[7] = clip.amplitude_pos
            elseif clip.direction == 6 then--XZ
                value[5] = clip.amplitude_pos
                value[7] = clip.amplitude_pos
            elseif clip.direction == 7 then--XYZ
                value[5] = clip.amplitude_pos
                value[6] = clip.amplitude_pos
                value[7] = clip.amplitude_pos
            end
            return value
        end
    end
    local keyframes = {}
    local init_value
    if anim_type == "srt" then
        init_value = {1, 0, 0, 0, 0, 0, 0}
    elseif anim_type == "mtl" then
        init_value = anim_data.init_value
    end
    local from = init_value
    local last_clip = anim_data.clips[1]
    for _, clip in ipairs(anim_data.clips) do
        if clip.range[1] == last_clip.range[2] + 1 then
            from = get_keyframe_value(anim_type, last_clip, anim_data.inherit[3] and keyframes[#keyframes].value or nil)
        else
            if clip.range[1] > 0 then
                keyframes[#keyframes + 1] = {time = ((clip == last_clip) and 0 or (last_clip.range[2] + 1) / sample_ratio), value = init_value}
            end
            from = init_value
        end
        keyframes[#keyframes + 1] = {time = clip.range[1] / sample_ratio, tween = clip.tween, value = from}
        local to = get_keyframe_value(anim_type, clip, anim_data.inherit[3] and from or nil)
        keyframes[#keyframes + 1] = {time = clip.range[2] / sample_ratio, tween = clip.tween, value = to}
        last_clip = clip
    end
    local endclip = anim_data.clips[#anim_data.clips]
    if endclip and endclip.range[2] < frame_count - 1 then
        keyframes[#keyframes + 1] = {time = (endclip.range[2] + 1) / sample_ratio, value = init_value}
        if frame_count > endclip.range[2] + 1 then
            keyframes[#keyframes + 1] = {time = frame_count / sample_ratio, value = init_value}
        end
    end
    return keyframes
end

function imodifier.create_modifier_from_file(target, group_id, path, anim_name, keep, foreupdate)
    local key = path .. anim_name
    if not keyframes_cache[key] then
        local anims = serialize.parse(path, aio.readall(path))
        local raw_anim
        if anim_name then
            for _, value in ipairs(anims) do
                if value.name == anim_name then
                    raw_anim = value
                    break
                end
            end
        end
        local anim_type = raw_anim.type
        local sample_ratio = raw_anim.sample_ratio
        local frame_count = raw_anim.sample_ratio * raw_anim.duration
        local keyframes
        local property
        for _, anim_data in ipairs(raw_anim.target_anims) do
            if #anim_data.clips < 1 then
                goto continue
            end
            if anim_type == "mtl" then
                property = anim_data.property_name
            end
            keyframes = imodifier.keyframes_from_anim_data(anim_type, anim_data, frame_count, sample_ratio)
            ::continue::
        end
        keyframes_cache[key] = {animtype = anim_type, keyframes = keyframes, property = property}
    end
    local kfc = keyframes_cache[key]
    if kfc.animtype == "srt" then
        return imodifier.create_srt_modifier(target, group_id, kfc.keyframes, keep, foreupdate)
    else
        return imodifier.create_mtl_modifier(target, kfc.property, kfc.keyframes, keep, foreupdate)
    end
end

function imodifier.create_srt_modifier(target, group_id, generator, keep, foreupdate)
    local anim_eid
    if type(generator) == "table" then
        anim_eid = ika.create(generator)
        local function get_value(kfe, time)
            local e <close> = world:entity(kfe, "keyframe:in")
            local kfanim = e.keyframe
            return kfanim.play_state.current_value, kfanim.play_state.playing
        end
        generator = function(time)
            local srt, running = get_value(anim_eid, time)
            srt = srt or {1, 0, 0, 0, 0, 0, 0}
            return math3d.matrix({s = srt[1],
                r = math3d.quaternion{math.rad(srt[2]), math.rad(srt[3]), math.rad(srt[4])},
                t = {srt[5], srt[6], srt[7]}}), running
        end
    end
    
	local template = {
        group = group_id,
		policy = {
            "ant.scene|scene_object",
            "ant.modifier|modifier",
		},
		data = {
            scene = {},
            modifier = {
                target = target,
                continue = false,
                keep = keep,
                foreupdate = foreupdate,
                reset = function (self)
                    local e <close> = world:entity(self.target)
                    if not e then
                        return
                    end
                    if not self.init_srt then
                        iom.set_srt_offset_matrix(e, mc.IDENTITY_MAT)
                    else
                        iom.set_rotation(e, math3d.quaternion(self.init_srt.r))
                        iom.set_position(e, math3d.vector(self.init_srt.t))
                    end
                end,
                update = function(self, time)
                    if not self.target or (not self.foreupdate and not self.continue) then
                        return
                    end
                    local value, running = generator(time)
                    local apply_value = value
                    if not running and not self.keep and not self.foreupdate then
                        apply_value = mc.IDENTITY_MAT
                    end
                    local e <close> = world:entity(self.target)
                    if not e then
                        return true
                    end
                    if not self.init_srt then
                        iom.set_srt_offset_matrix(e, apply_value)
                    else
                        iom.set_srt_matrix(e, apply_value)
                    end
                    self.continue = running
                    if not running and self.destroy then
                        return true
                    end
                end
            },
		},
    }
    return {
        eid = world:create_entity(template),
        anim_eid = anim_eid
    }
end

function imodifier.start(m, desc, auto_destroy)
    if not m then
        return
    end
    desc.destroy = true
    auto_destroy_map[m.eid] = m
    world:pub {"modifier", m, desc}
end

function imodifier.stop(m)
    if not m then
        return
    end
    local e <close> = world:entity(m.eid, "modifier:in")
    e.modifier.continue = false
end

local ivs = ecs.require "ant.render|visible_state"
function imodifier.create_bone_modifier(target, group_id, filename, bone_name)
    local anim_prefab = world:create_instance {
		prefab = filename,
        on_ready = function (instance)
            for _, eid in ipairs(instance.tag["*"]) do
                local e <close> = world:entity(eid, "anim_ctrl?in mesh?in")
                if e.anim_ctrl then
                    local path_list = {}
                    filename:gsub('[^|]*', function (wd) path_list[#path_list+1] = wd end)
                    if path_list[1] then
                        --xxx.glb
                        iani.load_events(eid, string.sub(path_list[1], 1, -5) .. ".event")
                    else
                        ---xxx.prefab
                        iani.load_events(eid, string.sub(filename, 1, -8) .. ".event")
                    end
                elseif e.mesh then
                    -- ivs.set_state(e, "main_view", false)
                    w:remove(eid)
                end
            end
        end
	}
    local modifier = imodifier.create_srt_modifier(target, group_id, function (time)
            for _, e in ipairs(anim_prefab.tag["*"]) do
                local anim <close> = world:entity(e, "animation?in anim_ctrl?in")
                if anim.animation and anim.anim_ctrl then
                    return anim.animation.models:joint(anim.animation.skeleton:joint_index(bone_name)), anim.anim_ctrl.play_state.play
                end
            end
        end)
    modifier.anim_eid = anim_prefab
    return modifier
end

return imodifier
