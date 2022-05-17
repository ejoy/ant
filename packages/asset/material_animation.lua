local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"
local imaterial = ecs.import.interface "ant.asset|imaterial"

-- material animation
local ima = ecs.interface "imaterial_animation"
function ima.create(name, property, frames)
    return ecs.create_entity{
        policy = {
            "ant.asset|material_animation",
            "ant.general|name",
        },
        data = {
            material_animation = {
				property = property,
				frames = frames or {},
				play_state = {}
            },
            name = name or "noname"
        }
    }
end

function ima.add(e, time_ms, value, idx)
    local frames = e.material_animation.frames
	idx = idx or #frames+1
	table.insert(frames, idx, {
        value	 	= value,
        time 		= time_ms,	--ms
    })
end

function ima.remove(e, idx)
    idx = idx or #e.material_animation.frames
    table.remove(e.material_animation.frames, idx)
end

function ima.clear(e)
    e.material_animation.frames = {}
end

function ima.stop(e)
	local ps = e.material_animation.play_state
    if ps.target_e then
		imaterial.set_property(world:entity(ps.target_e), e.material_animation.property, ps.restore_value)
		ps.target_e = nil
		ps.playing = false
	end
end

function ima.play(e, target, loop)
	if not world:entity(target).render_object then
		return
	end
	ima.stop(e)
	if ALREADY_LOG == nil then
		log.warn("Could not get property from material, need code change")
		ALREADY_LOG = true
		return 
	end
	
	local pro = imaterial.get_property(world:entity(target), e.material_animation.property)
	if not pro then
		return
	end
	local ps = e.material_animation.play_state
	ps.target_e = target
	ps.loop = loop
	ps.current_time = 0
	ps.playing = true
	ps.restore_value = (type(pro.value) == "userdata") and math3d.totable(pro.value) or pro.value
end

local ma_sys = ecs.system "material_animation_system"
function ma_sys:component_init()
    -- for e in w:select "INIT material_animation:in" do
    --     e.material_animation.play_state = {
    --         current_time = 0,
    --         target_e = nil,
	-- 		loop = false,
	-- 		playing = false
    --     }
    -- end
end

local timer = ecs.import.interface "ant.timer|itimer"

local function step_material_anim(mat_anim, delta_time)
	local frames = mat_anim.frames
	if #frames < 2 then return end

	local play_state = mat_anim.play_state
	local lerp = function (v0, v1, f)
		if type(v0) == "table" then
			local count = #v0
			local ret = {}
			for i = 1, count do
				ret[#ret + 1] = v0[i] + (v1[i] - v0[i]) * f
			end
			return ret
		else
			return v0 + (v1 - v0) * f
		end
	end
	local function get_value(time)
		local frame_count = #frames
		for i = 1, frame_count do
			if time < frames[i].time then
				local factor = math.min((time - frames[i-1].time) / (frames[i].time - frames[i-1].time), 1.0)
				return lerp(frames[i-1].value, frames[i].value, factor), false
			elseif i == frame_count then
				return frames[i].value, true
			end
		end
	end

	local value, last = get_value(play_state.current_time)
	imaterial.set_property(world:entity(play_state.target_e), mat_anim.property, value)
	play_state.current_time = play_state.current_time + delta_time
	if last then
		if play_state.loop then
			play_state.current_time = 0
		else
			play_state.playing = false
			imaterial.set_property(world:entity(play_state.target_e), mat_anim.property, play_state.restore_value)
			play_state.target_e = nil
		end
	end
end

function ma_sys.data_changed()
	local delta_time = timer.delta()
	for e in w:select "material_animation:in" do
		local ma = e.material_animation
		if ma.play_state.playing then
			step_material_anim(ma, delta_time)
		end
	end
end