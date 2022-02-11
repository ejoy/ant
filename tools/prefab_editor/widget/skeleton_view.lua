local ecs = ...
local world = ecs.world
local w = world.w
local iani      = ecs.import.interface "ant.animation|ianimation"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local hierarchy = require "hierarchy_edit"
local imgui     = require "imgui"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local joint_utils  = require "widget.joint_utils"
local utils     = require "common.utils"
local widget_utils  = require "widget.utils"
local stringify     = import_package "ant.serialize".stringify
local animation = require "hierarchy".animation
local skeleton = require "hierarchy".skeleton
local math3d        = require "math3d"
local asset_mgr = import_package "ant.asset"
local icons     = require "common.icons"(asset_mgr)
local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util
local m = {}
local file_path = ""
local joints_map
local joints_list
local current_skeleton
local joint_scale = 0.2
local sample_ratio = 50.0
local anim_e = {}
local current_joint
local joint_pose = {}
local allanims = {}
local current_anim
local anim_name_list = {}
local TYPE_LINEAR <const> = 1
local TYPE_REBOUND <const> = 2
local TYPE_SHAKE <const> = 2
local anim_type_name = {
    "Linear",
    "Rebound",
    "Shake"
}
local TWEEN_LINEAR <const> = 1
local TWEEN_CUBIC_IN <const> = 2
local TWEEN_CUBIC_Out <const> = 3
local TWEEN_CUBIC_InOut <const> = 4
local TWEEN_BOUNCE_IN <const> = 5
local TWEEN_BOUNCE_OUT <const> = 6
local TWEEN_BOUNCE_INOUT <const> = 7
local tween_type_name = {
    "Linear",
    "CubicIn",
    "CubicOut",
    "CubicInOut",
    "BounceIn",
    "BounceOut",
    "BounceInOut",
}
local DIR_X <const> = 1
local DIR_Y <const> = 2
local DIR_Z <const> = 3
local DIR_XY <const> = 4
local DIR_YZ <const> = 5
local DIR_XZ <const> = 6
local DIR_XYZ <const> = 7
local DirName = {
    "X",
    "Y",
    "Z",
    "XY",
    "YZ",
    "XZ",
    "XYZ",
}
local Dir = {
    math3d.ref(math3d.vector{1,0,0}),
    math3d.ref(math3d.vector{0,1,0}),
    math3d.ref(math3d.vector{0,0,1}),
    math3d.ref(math3d.normalize(math3d.vector{1,1,0})),
    math3d.ref(math3d.normalize(math3d.vector{0,1,1})),
    math3d.ref(math3d.normalize(math3d.vector{1,0,1})),
    math3d.ref(math3d.normalize(math3d.vector{1,1,1})),
}


local function bounce_time(time)
    if time < 1 / 2.75 then
        return 7.5625 * time * time
    elseif time < 2 / 2.75 then
        time = time - 1.5 / 2.75
        return 7.5625 * time * time + 0.75
    
    elseif time < 2.5 / 2.75 then
        time = time - 2.25 / 2.75
        return 7.5625 * time * time + 0.9375
    end
    time = time - 2.625 / 2.75
    return 7.5625 * time * time + 0.984375
end
local tween_func = {
    function (time) return time end,
    function (time) return time * time * time end,
    function (time)
        time = time - 1
        return (time * time * time + 1)
    end,
    function (time)
        time = time * 2
        if time < 1 then
            return 0.5 * time * time * time
        end
        time = time - 2;
        return 0.5 * (time * time * time + 2)
    end,
    function (time) return 1 - bounce_time(1 - time) end,
    function (time) return bounce_time(time) end,
    function (time)
        local newT = 0
        if time < 0.5 then
            time = time * 2;
            newT = (1 - bounce_time(1 - time)) * 0.5
        else
            newT = bounce_time(time * 2 - 1) * 0.5 + 0.5
        end
        return newT
    end,
}

local function update_animation()
    local function push_anim_key(raw_anim, joint_name, clips)
        local poseMat = joint_pose[joint_name]--math3d.inverse(joint_pose[joint_name])
        for _, clip in ipairs(clips) do
            if clip.range[1] >= 0 and clip.range[2] >= 0 then
                local frame_to_time = 1.0 / sample_ratio
                local duration = clip.range[2] - clip.range[1]
                local subdiv = clip.repeat_count
                if clip.type == TYPE_REBOUND then
                    subdiv = 2 * subdiv
                elseif clip.type == TYPE_SHAKE then
                    subdiv = 4 * subdiv
                end
                local step = (duration / subdiv) * frame_to_time
                local time = clip.range[1] * frame_to_time
                local localMat = math3d.matrix{s = 1, r = mc.IDENTITY_QUAT, t = mc.ZERO}
                local from_s, from_r, from_t = math3d.srt(math3d.mul(poseMat, localMat))
                local to_rot = {0,clip.amplitude_rot,0}
                if clip.rot_axis == DIR_X then
                    to_rot = {clip.amplitude_rot,0,0}
                elseif clip.rot_axis == DIR_Z then
                    to_rot = {0,0,clip.amplitude_rot}
                end
                localMat = math3d.matrix{s = 1, r = math3d.quaternion{math.rad(to_rot[1]), math.rad(to_rot[2]), math.rad(to_rot[3])}, t = math3d.mul(Dir[clip.direction], clip.amplitude_pos)}
                local to_s, to_r, to_t = math3d.srt(math3d.mul(poseMat, localMat))
                localMat = math3d.matrix{s = 1, r = math3d.quaternion{math.rad(-to_rot[1]), math.rad(-to_rot[2]), math.rad(-to_rot[3])}, t = math3d.mul(Dir[clip.direction], -clip.amplitude_pos)}
                local to_s2, to_r2, to_t2 = math3d.srt(math3d.mul(poseMat, localMat))
                if clip.type == TYPE_LINEAR then
                    for i = 1, clip.repeat_count, 1 do
                        raw_anim:push_prekey(joint_name, time, from_s, from_r, from_t)
                        time = time + step
                        raw_anim:push_prekey(joint_name,time,to_s, to_r, to_t)
                        time = time + frame_to_time
                    end
                else
                    raw_anim:push_prekey(joint_name, time, from_s, from_r, from_t)
                    time = time + step
                    for i = 1, clip.repeat_count, 1 do
                        raw_anim:push_prekey(joint_name, time, to_s, to_r, to_t)
                        if clip.type == TYPE_REBOUND then
                            time = (i == clip.repeat_count) and (clip.range[2] * frame_to_time) or (time + step)
                            raw_anim:push_prekey(joint_name, time, from_s, from_r, from_t)
                            time = time + step
                        elseif clip.type == TYPE_SHAKE then
                            time = time + step * 2
                            raw_anim:push_prekey(joint_name, time, to_s2, to_r2, to_t2)
                            time = time + step * 2
                        end
                    end
                    if clip.type == TYPE_SHAKE then
                        raw_anim:push_prekey(joint_name, clip.range[2] * frame_to_time, from_s, from_r, from_t)
                    end
                end
                
            end
        end
    end
    local runtim_anim = current_anim.runtime_anim
    for _, value in ipairs(current_anim.joint_anims) do
        local joint = joint_utils:get_joint_by_name(current_skeleton, value.joint_name)
        if not joint then
            assert(false)
        end
        local ra = runtim_anim.raw_animation
        ra:clear_prekey(joint.name)
        push_anim_key(ra, joint.name, value.clips)
    end
    runtim_anim._handle = runtim_anim.raw_animation:build()
end

local function min_max_range_value(clips, clip_index)
    local min = 0
    local max = math.ceil(current_anim.duration * sample_ratio) - 1
    if clip_index < #clips then
        max = clips[clip_index + 1].range[1] - 1
    end
    if clip_index > 1 and clip_index <= #clips then
        min = clips[clip_index - 1].range[2] + 1
    end
    return min, max
end

local function on_move_clip(move_type, current_clip_index, move_delta)
    local anim = current_anim.joint_anims[current_anim.selected_layer_index]
    local clips = anim.clips
    if current_clip_index <= 0 or current_clip_index > #clips then return end
    local clip = clips[current_clip_index]
    if not clip then return end
    local min_value, max_value = min_max_range_value(clips, current_clip_index)
    if move_type == 1 then
        local new_value = clip.range[1] + move_delta
        if new_value < 0 then
            new_value = 0
        end
        if new_value >= clip.range[2] then
            new_value = clip.range[2] - 1
        end
        clip.range[1] = new_value
        clip.range_ui[1] = clip.range[1]
    elseif move_type == 2 then
        local new_value = clip.range[2] + move_delta
        if new_value <= clip.range[1] then
            new_value = clip.range[1] + 1
        end
        if new_value > max_value then
            new_value = max_value
        end
        clip.range[2] = new_value
        clip.range_ui[2] = clip.range[2]
    elseif move_type == 3 then
        local new_value1 = clip.range[1] + move_delta
        local new_value2 = clip.range[2] + move_delta
        if new_value1 >= min_value and new_value2 <= max_value then
            clip.range[1] = new_value1
            clip.range[2] = new_value2
            clip.range_ui[1] = clip.range[1]
            clip.range_ui[2] = clip.range[2]
        end
    end
    current_anim.dirty_layer = current_anim.selected_layer_index
    update_animation()
end
local function clip_exist(clips, name)
    for _, v in ipairs(clips) do
        if v.name == name then
            return true
        end
    end
end

local function find_anim_by_name(name)
    for index, value in ipairs(current_anim.joint_anims) do
        if name == value.joint_name then
            return index
        end
    end
end

local function find_greater_clip(current, clips, pos)
    local find
    for index, value in ipairs(clips) do
        if index ~= current then
            if pos >= value.range[1] and pos <= value.range[2] then
                find = index
                break
            end
        end
    end
    if not find then
        for index, value in ipairs(clips) do
            if index ~= current then
                if pos < value.range[1] then
                    return index
                end
            end
        end
        return 0
    else
        return -1
    end
end

local function is_index_valid(index)
    if current_anim.selected_layer_index > 0 then
        local clips = current_anim.joint_anims[current_anim.selected_layer_index].clips
        for _, clip in ipairs(clips) do
            if (index >= clip.range[1] and index <= clip.range[2]) then
                return false
            end
        end
    end
    return index >= 0 and index <= math.ceil(current_anim.duration * sample_ratio) - 1
end

local new_clip_pop = false
local start_frame_ui = {0, speed = 1, min = 0}
local new_range_start = 0
local new_range_end = 1
local function get_or_create_joint_anim(joint)
    if not current_anim then
        return
    end
    for _, value in ipairs(current_anim.joint_anims) do
        if joint.name == value.joint_name then
            return value;
        end
    end
    current_anim.joint_anims[#current_anim.joint_anims + 1] = {
        joint_name = joint.name,
        clips = {}
    }
    return current_anim.joint_anims[#current_anim.joint_anims]
end
local function create_clip()
    if not new_clip_pop or not current_joint then
        return
    end
    local title = "New Clip"
    if not imgui.windows.IsPopupOpen(title) then
        imgui.windows.OpenPopup(title)
    end

    local change, opened = imgui.windows.BeginPopupModal(title, imgui.flags.Window{"AlwaysAutoResize", "NoClosed"})
    if change then
        imgui.widget.Text("StartFrame:")
        imgui.cursor.SameLine()
        if imgui.widget.DragInt("##StartFrame", start_frame_ui) then
            if start_frame_ui[1] < 0 then
                start_frame_ui[1] = 0
            end
            new_range_start = start_frame_ui[1]
            new_range_end = new_range_start + 1
        end
        if is_index_valid(new_range_start) and is_index_valid(new_range_end) then
            if imgui.widget.Button "Create" then
                local anim = get_or_create_joint_anim(current_joint)
                local clips = anim.clips
                local new_clip = {
                    range = {new_range_start, new_range_end},
                    range_ui = {new_range_start, new_range_end, speed = 1},
                    type = TYPE_LINEAR,
                    tween = TWEEN_LINEAR,
                    repeat_count = 1,
                    random_amplitude = false,
                    direction = 2,
                    rot_axis = 2,
                    amplitude_pos = 0,
                    amplitude_rot = 0,
                    repeat_ui = {1, speed = 1, min = 1, max = 20},
                    random_amplitude_ui = { false },
                    amplitude_pos_ui = {0, speed = 0.1},
                    amplitude_rot_ui = {0, speed = 1},
                }
                clips[#clips + 1] = new_clip
                table.sort(clips, function(a, b) return a.range[2] < b.range[1] end)
                for index, value in ipairs(clips) do
                    if new_clip == value then
                        current_anim.selected_clip_index = index
                        break
                    end
                end
                local index, _ = find_anim_by_name(current_joint.name)
                current_anim.selected_layer_index = index
                current_anim.dirty_layer = -1
                new_clip_pop = false
            end
        else
            imgui.widget.Text("Invalid start range!")
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button "Cancel" then
            new_clip_pop = false
        end
        imgui.windows.EndPopup()
    end
end
local function show_current_joint()
    if not current_anim then return end
    imgui.widget.PropertyLabel("FrameCount:")
    if imgui.widget.DragInt("##FrameCount", current_anim.frame_count_ui) then
        current_anim.frame_count = current_anim.frame_count_ui[1]
        local d = current_anim.frame_count / sample_ratio
        current_anim.runtime_anim._duration = d
        current_anim.duration = d
        current_anim.runtime_anim.raw_animation:setup(current_skeleton._handle, d)
        current_anim.runtime_anim._handle = current_anim.runtime_anim.raw_animation:build()
        current_anim.dirty = true
    end
    if not current_joint then return end
    imgui.widget.Text("Joint: "..current_joint.name)
    imgui.cursor.SameLine()
    if imgui.widget.Button("NewClip") then
        new_clip_pop = true
    end
    create_clip()
    if current_anim.selected_layer_index < 1 then
        return
    end
    local anim_layer = current_anim.joint_anims[current_anim.selected_layer_index]
    local clips = anim_layer.clips

    if current_anim.selected_clip_index < 1 then
        return
    else
        imgui.cursor.SameLine()
        imgui.widget.Text("        ")
        imgui.cursor.SameLine()
        if imgui.widget.Button("DelClip") then
            table.remove(clips, current_anim.selected_clip_index)
            current_anim.selected_clip_index = 0
            return
        end
    end

    local current_clip = clips[current_anim.selected_clip_index]
    if not current_clip then return end
    imgui.cursor.Separator()
    imgui.widget.PropertyLabel("FrameRange")
    local old_range = {current_clip.range_ui[1], current_clip.range_ui[2]}
    local dirty = false
    if imgui.widget.DragInt("##Range", current_clip.range_ui) then
        local range_ui = current_clip.range_ui
        local head = false
        if old_range[1] ~= range_ui[1] then
            head = true
            local find = find_greater_clip(current_anim.selected_clip_index, clips, range_ui[1])
            if find < 0 then
                range_ui[1] = old_range[1]
            else
                if find > 0 then
                    local max = clips[find].range[1] - 1
                    if range_ui[2] < 0 or range_ui[2] > max then
                        range_ui[2] = max
                    end
                else
                    if range_ui[2] < 0 then
                        range_ui[2] = current_anim.frame_count - 1
                    end
                end
            end
        elseif old_range[2] ~= range_ui[2] then
            local find = find_greater_clip(current_anim.selected_clip_index, clips, range_ui[2])
            if find < 0 then
                range_ui[2] = old_range[2]
            else
                local left_index = find - 1
                if find > 1 and left_index ~= current_anim.selected_clip_index then
                    local min = clips[left_index].range[2] + 1
                    if range_ui[1] < min then
                        range_ui[1] = min
                    end
                else
                    if range_ui[1] < 0 then
                        range_ui[1] = 0
                    end
                end
            end
        end
        if head then
            if range_ui[1] >= range_ui[2] then
                range_ui[1] = range_ui[2] - 1
            elseif range_ui[1] < 0 then
                range_ui[1] = 0
            end
        else
            if range_ui[2] <= range_ui[1] then
                range_ui[2] = range_ui[1] + 1
            elseif range_ui[2] >= current_anim.frame_count then
                range_ui[2] = current_anim.frame_count - 1
            end
        end
        current_clip.range = {range_ui[1], range_ui[2]}
        current_anim.dirty_layer = current_anim.selected_layer_index
        dirty = true
    end
    imgui.widget.PropertyLabel("TweenType")
    if imgui.widget.BeginCombo("##TweenType", {tween_type_name[current_clip.tween], flags = imgui.flags.Combo {}}) then
        for i, type in ipairs(tween_type_name) do
            if imgui.widget.Selectable(type, current_clip.tween == i) then
                current_clip.tween = i
                dirty = true
            end
        end
        imgui.widget.EndCombo()
    end

    imgui.widget.PropertyLabel("AnimationType")
    if imgui.widget.BeginCombo("##AnimationType", {anim_type_name[current_clip.type], flags = imgui.flags.Combo {}}) then
        for i, type in ipairs(anim_type_name) do
            if imgui.widget.Selectable(type, current_clip.type == i) then
                current_clip.type = i
                dirty = true
            end
        end
        imgui.widget.EndCombo()
    end
    imgui.widget.PropertyLabel("Repeat")
    if imgui.widget.DragInt("##Repeat", current_clip.repeat_ui) then
        current_clip.repeat_count = current_clip.repeat_ui[1]
        dirty = true
    end
    -- imgui.widget.PropertyLabel("Random")
    -- if imgui.widget.Checkbox("##Random", anim.random_amplitude_ui) then
    --     anim.random_amplitude = anim.random_amplitude_ui[1]
    --     dirty = true
    -- end
    imgui.widget.PropertyLabel("Direction")
    if imgui.widget.BeginCombo("##Direction", {DirName[current_clip.direction], flags = imgui.flags.Combo {}}) then
        for i, type in ipairs(DirName) do
            if imgui.widget.Selectable(type, current_clip.direction == i) then
                current_clip.direction = i
                dirty = true
            end
        end
        imgui.widget.EndCombo()
    end

    imgui.widget.PropertyLabel("AmplitudePos")
    local ui_data = current_clip.amplitude_pos_ui
    if imgui.widget.DragFloat("##AmplitudePos", ui_data) then
        current_clip.amplitude_pos = ui_data[1]
        dirty = true
    end

    imgui.widget.PropertyLabel("RotAxis")
    if imgui.widget.BeginCombo("##RotAxis", {DirName[current_clip.rot_axis], flags = imgui.flags.Combo {}}) then
        for i = 1, 3 do
            if imgui.widget.Selectable(DirName[i], current_clip.rot_axis == i) then
                current_clip.rot_axis = i
                dirty = true
            end
        end
        imgui.widget.EndCombo()
    end
    imgui.widget.PropertyLabel("AmplitudeRot")
    ui_data = current_clip.amplitude_rot_ui
    if imgui.widget.DragFloat("##AmplitudeRot", ui_data) then
        current_clip.amplitude_rot = ui_data[1]
        dirty = true
    end
    if dirty then
        update_animation()
    end
end

local function anim_play(anim_state, play)
    for _, e in ipairs(anim_e) do
        iom.set_position(hierarchy:get_node(hierarchy:get_node(e).parent).parent, {0.0,0.0,0.0})
        play(e, anim_state)
    end
end

local function anim_pause(p)
    for _, e in ipairs(anim_e) do
        iani.pause(e, p)
    end
end

local function anim_set_loop(...)
    for _, e in ipairs(anim_e) do
        iani.set_loop(e, ...)
    end
end

local function anim_set_time(t)
    for _, e in ipairs(anim_e) do
        iani.set_time(e, t)
    end
end
local anim_name = ""
local anim_duration = 30
local anim_name_ui = {text = ""}
local duration_ui = {30, speed = 1, min = 1}
local new_anim_widget = false

local function create_animation(name, duration, joint_anims)
    if allanims[name] then
        local msg = name .. " has existed!"
        widget_utils.message_box({title = "Create Animation Error", info = msg})
    else
        local td = duration / sample_ratio
        local new_anim = {
            raw_animation = animation.new_raw_animation(),
            _duration = td,
            _sampling_context = animation.new_sampling_context(1)
        }
        new_anim.raw_animation:setup(current_skeleton._handle, td)
        for _, ae in ipairs(anim_e) do
            ae.animation[name] = new_anim
        end
        local edit_anim = {
            name = name,
            dirty = true,
            dirty_layer = -1,-- [1...n]: dirty index, 0: no dirty, -1: all dirty
            duration = td,
            frame_count = duration,
            frame_count_ui = {duration, speed = 1},
            is_playing = false,
            selected_layer_index = -1,
            selected_frame = -1,
            current_frame = 0,
            clip_range_dirty = 0,
            selected_clip_index = 0,
            joint_anims = joint_anims or {},
            runtime_anim = new_anim
        }
        allanims[name] = edit_anim
        current_anim = edit_anim
        anim_name_list[#anim_name_list + 1] = name
        table.sort(anim_name_list)
    end
end

function m.new()
    if not new_anim_widget then return end
    local title = "New Animation"
    if not imgui.windows.IsPopupOpen(title) then
        imgui.windows.OpenPopup(title)
    end

    local change, opened = imgui.windows.BeginPopupModal(title, imgui.flags.Window{"AlwaysAutoResize", "NoClosed"})
    if change then
        imgui.widget.Text("Name:")
        imgui.cursor.SameLine()
        if imgui.widget.InputText("##Name", anim_name_ui) then
            anim_name = tostring(anim_name_ui.text)
        end
        imgui.widget.Text("Duration:")
        imgui.cursor.SameLine()
        if imgui.widget.DragInt("##Duration", duration_ui) then
            if duration_ui[1] < 1 then
                duration_ui[1] = 1
            end
            anim_duration = duration_ui[1]
        end
        if imgui.widget.Button "OK" then
            new_anim_widget = false
            if anim_name ~= "" then
                create_animation(anim_name, anim_duration)
            else
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button "Cancel" then
            new_anim_widget = false
        end
        imgui.windows.EndPopup()
    end
end

--local ui_loop = {false}
local ui_loop = {true}
function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    for _ in uiutils.imgui_windows("Skeleton", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        if current_skeleton then
            if imgui.widget.Button("New") then
                new_anim_widget = true
            end
            imgui.cursor.SameLine()
        end
        m.new()
        if imgui.widget.Button("Load") then
            local anim_filename = uiutils.get_open_file_path("Load Animation", "anim")
            if anim_filename then
                m.load(anim_filename)
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Save") then
            m.save(file_path)
        end
        if current_anim then
            imgui.cursor.SameLine()
            imgui.cursor.PushItemWidth(150)
            if imgui.widget.BeginCombo("##AnimList", {current_anim.name, flags = imgui.flags.Combo {}}) then
                for _, name in ipairs(anim_name_list) do
                    if imgui.widget.Selectable(name, current_anim.name == name) then
                        current_anim.selected_layer_index = 0
                        current_anim.selected_clip_index = 0
                        current_anim = allanims[name]
                        current_anim.selected_layer_index = 0
                        current_anim.selected_clip_index = 0
                    end
                end
                imgui.widget.EndCombo()
            end
            imgui.cursor.PopItemWidth()
            imgui.cursor.SameLine()
            if #anim_e > 0 then
                current_anim.is_playing = iani.is_playing(anim_e[1])
                if current_anim.is_playing then
                    current_anim.current_frame = math.floor(iani.get_time(anim_e[1]) * sample_ratio)
                end
            end
            local icon = current_anim.is_playing and icons.ICON_PAUSE or icons.ICON_PLAY
            if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
                if current_anim.is_playing then
                    anim_pause(true)
                else
                    anim_play({name = current_anim.name, loop = ui_loop[1], manual = false}, iani.play)
                end
            end
            imgui.cursor.SameLine()
            if imgui.widget.Checkbox("loop", ui_loop) then
                anim_set_loop(ui_loop[1])
            end

            imgui.cursor.SameLine()
            local current_time = #anim_e > 0 and iani.get_time(anim_e[1]) or 0
            imgui.widget.Text(string.format("Selected Frame: %d Time: %.2f(s) Current Frame: %d/%d Time: %.2f/%.2f(s)", current_anim.selected_frame, current_anim.selected_frame / sample_ratio, math.floor(current_time * sample_ratio), math.floor(current_anim.duration * sample_ratio), current_time, current_anim.duration))
        end
        if imgui.table.Begin("SkeletonColumns", 3, imgui.flags.Table {'Resizable', 'ScrollY'}) then
            imgui.table.SetupColumn("Joints", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
            imgui.table.SetupColumn("Detail", imgui.flags.TableColumn {'WidthStretch'}, 1.5)
            imgui.table.SetupColumn("AnimationLayer", imgui.flags.TableColumn {'WidthStretch'}, 6.5)
            imgui.table.HeadersRow()

            imgui.table.NextColumn()
            local child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##show_skeleton", child_width, child_height, false)
            if joints_map then
                joint_utils:show_joints(joints_map.root)
                current_joint = joint_utils.current_joint
                if current_joint and current_anim then
                    local layer_index = find_anim_by_name(current_joint.name)
                    if layer_index then
                        if current_anim.selected_layer_index ~= layer_index then
                            current_anim.selected_layer_index = layer_index
                            current_anim.selected_clip_index = 1
                            current_anim.dirty = true
                        end
                    else
                        current_anim.selected_clip_index = -1
                    end
                end
            end
            imgui.windows.EndChild()

            imgui.table.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##show_bone", child_width, child_height, false)
            show_current_joint()
            imgui.windows.EndChild()

            imgui.table.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##show_layers", child_width, child_height, false)

            if current_anim then
                local imgui_message = {}
                imgui.widget.SimpleSequencer(current_anim, imgui_message)
                current_anim.dirty = false
                current_anim.clip_range_dirty = 0
                current_anim.dirty_layer = 0
                local move_type
                local move_delta
                for k, v in pairs(imgui_message) do
                    if k == "pause" then
                        anim_pause(true)
                        current_anim.current_frame = v
                        anim_set_time(v / sample_ratio)
                    elseif k == "selected_frame" then
                        current_anim.selected_frame = v
                    elseif k == "selected_clip_index" then
                        current_anim.selected_clip_index = v
                    elseif k == "selected_layer_index" then
                        current_anim.selected_layer_index = v
                        if v > 0 and v <= #current_anim.joint_anims then
                            joint_utils:set_current_joint(current_skeleton, current_anim.joint_anims[v].joint_name)
                        end
                    elseif k == "move_type" then
                        move_type = v
                    elseif k == "move_delta" then
                        move_delta = v
                    end
                end

                if move_type and move_type ~= 0 then
                    on_move_clip(move_type, current_anim.selected_clip_index, move_delta)
                end
            end
            imgui.windows.EndChild()

            imgui.table.End()
        end
    end
end
function m.save(path)
    if not current_anim then return end
    local filename
    if not path then
        filename = widget_utils.get_saveas_path("Save Animation", "anim")
        if not filename then return end
    else
        filename = path
    end
    local joint_anims = utils.deep_copy(current_anim.joint_anims)
    for _, value in ipairs(joint_anims) do
        value.range_ui = nil
        for _, clip in ipairs(value.clips) do
            clip.repeat_ui = nil
            clip.random_amplitude_ui = nil
            clip.amplitude_pos_ui = nil
            clip.amplitude_rot_ui = nil
        end
    end
    utils.write_file(filename, stringify({name = current_anim.name, duration = current_anim.duration, joint_anims = joint_anims}))
    if file_path ~= filename then
        file_path = filename
    end
end
local fs        = require "filesystem"
local datalist  = require "datalist"
function m.load(path)
    if fs.exists(fs.path(path)) then
        local path = fs.path(path):localpath()
        local f = assert(fs.open(path))
        local data = f:read "a"
        f:close()
        local anim = datalist.parse(data)
        for _, value in ipairs(anim.joint_anims) do
            for _, clip in ipairs(value.clips) do
                clip.range_ui = {clip.range[1], clip.range[2], speed = 1}
                clip.repeat_ui = {clip.repeat_count, speed = 1, min = 1, max = 20}
                clip.random_amplitude_ui = {clip.random_amplitude}
                clip.amplitude_pos_ui = {clip.amplitude_pos, speed = 0.1}
                clip.amplitude_rot_ui = {clip.amplitude_rot, speed = 1}
            end
            
            local joint = joint_utils:get_joint_by_name(current_skeleton, value.joint_name)
            if not joint then
                assert(false)
            end
        end
        create_animation(anim.name, math.floor(anim.duration * sample_ratio), anim.joint_anims)
        update_animation()
        file_path = path:string()
    end

end
local ifs		= ecs.import.interface "ant.scene|ifilter_state"
local imaterial	= ecs.import.interface "ant.asset|imaterial"
local ldrtohdr <const> = 1--12000
local bone_color = {0.2 * ldrtohdr, 0.2 * ldrtohdr, 1 * ldrtohdr, 0.5}
local bone_highlight_color = {1.0 * ldrtohdr, 0.2 * ldrtohdr, 0.2 * ldrtohdr, 0.5}
local function create_bone_entity(joint_name)
    local template = {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            reference = true,
            scene = {srt = {s = joint_scale}},
            filter_state = "main_view|selectable",
            material = "/pkg/tools.prefab_editor/res/materials/joint.material",
            mesh = "/pkg/tools.prefab_editor/res/meshes/joint.meshbin",
            name = joint_name,
            on_ready = function(e)
				if imaterial.has_property(e, "u_basecolor_factor") then
					imaterial.set_property(e, "u_basecolor_factor", bone_color)
				end
				ifs.set_state(e, "auxgeom", true)
			end
        }
    }
    return ecs.create_entity(template)
end
local first_select = true
function m.bind(e)
    if not e then
        return
    end
    w:sync("skeleton?in", e)
    if not e.skeleton then
        return
    end
    if #anim_e == 0 then
        for ske_e in w:select "reference:in skeleton:in animation:in" do
            if ske_e.skeleton == e.skeleton then
                anim_e[#anim_e + 1] = ske_e.reference
            end
        end
    end
    current_skeleton = e.skeleton
    if not joint_utils.on_select_joint then
        joint_utils.on_select_joint = function(old, new)
            if first_select then
                --TODO: remove this
                for _, joint in ipairs(joints_list) do
                    if joint.mesh then
                        imaterial.set_property(joint.mesh, "u_basecolor_factor", bone_color)
                    end
                end
                first_select = false
            end
            if old then
                imaterial.set_property(old.mesh, "u_basecolor_factor", bone_color) 
            end
            if new then
                imaterial.set_property(new.mesh, "u_basecolor_factor", bone_highlight_color)
            end
        end
    end
    if not joint_utils.update_joint_pose then
        joint_utils.update_joint_pose = function()
            if not joints_list then
                return
            end
            local pose_result
            for e in w:select "skeleton:in pose_result:in" do
                if current_skeleton == e.skeleton then
                    pose_result = e.pose_result
                    break
                end
            end
            if pose_result then
                for _, joint in ipairs(joints_list) do
                    if joint.mesh and joint.mesh.render_object then
                        local srt = pose_result:joint(joint.index)
                        if not joint_pose[joint.name] then
                            joint_pose[joint.name] = math3d.ref(srt)
                        end
                        iom.set_srt_matrix(joint.mesh, math3d.mul(mc.R2L_MAT, srt))
                        iom.set_scale(joint.mesh, joint_scale)
                    end
                end
            end
        end
    end
    joints_map, joints_list = joint_utils:get_joints(e)
    for _, joint in ipairs(joints_list) do
        if not joint.mesh then
            joint.mesh = create_bone_entity(joint.name)
        end
    end
end

return m