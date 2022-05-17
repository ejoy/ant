local ecs = ...
local world = ecs.world
local w = world.w
local iani      = ecs.import.interface "ant.animation|ianimation"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local ies       = ecs.import.interface "ant.scene|ifilter_state"
local hierarchy = require "hierarchy_edit"
local imgui     = require "imgui"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local joint_utils  = require "widget.joint_utils"
local utils     = require "common.utils"
local widget_utils  = require "widget.utils"
local stringify     = import_package "ant.serialize".stringify
local animation = require "hierarchy".animation
local math3d        = require "math3d"
local asset_mgr = import_package "ant.asset"
local icons     = require "common.icons"(asset_mgr)
local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util
local m = {}
local file_path
local joints_map
local joints_list
local current_skeleton
local joint_scale = 0.25
local sample_ratio = 50.0
local anim_e = {}
local current_joint
local allanims = {}
local current_anim
local anim_name_list = {}
local anim_type_name = {
    "Linear",
    "Rebound",
    "Shake"
}
local tween_type_name = {
    "Linear",
    "CubicIn",
    "CubicOut",
    "CubicInOut",
    "BounceIn",
    "BounceOut",
    "BounceInOut",
}
local dir_name = {
    "X",
    "Y",
    "Z",
    "XY",
    "YZ",
    "XZ",
    "XYZ",
}
local function update_animation()
    local runtime_anim = current_anim.runtime_anim
    runtime_anim._handle = iani.build_animation(current_skeleton._handle, runtime_anim.raw_animation, current_anim.joint_anims, sample_ratio)
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
    if not current_anim then return end
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
                    type = 1,
                    tween = 1,
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
local function max_range_value()
    if not current_anim then return 1 end
    local max_value = 1
    for _, joint_anim in ipairs(current_anim.joint_anims) do
        local clips = joint_anim.clips
        if #clips > 0 then
            if max_value < clips[#clips].range[2] then
                max_value = clips[#clips].range[2]
            end
        end
    end
    return max_value
end
local function show_current_joint()
    if not current_anim then return end
    imgui.widget.PropertyLabel("FrameCount:")
    if imgui.widget.DragInt("##FrameCount", current_anim.frame_count_ui) then
        if current_anim.frame_count_ui[1] < max_range_value() + 1 then
            current_anim.frame_count_ui[1] = max_range_value() + 1
        end
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
            current_anim.dirty_layer = -1
            update_animation()
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
    if imgui.widget.BeginCombo("##Direction", {dir_name[current_clip.direction], flags = imgui.flags.Combo {}}) then
        for i, type in ipairs(dir_name) do
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
    if imgui.widget.BeginCombo("##RotAxis", {dir_name[current_clip.rot_axis], flags = imgui.flags.Combo {}}) then
        for i = 1, 3 do
            if imgui.widget.Selectable(dir_name[i], current_clip.rot_axis == i) then
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
        iom.set_position(world:entity(hierarchy:get_node(hierarchy:get_node(e).parent).parent), {0.0,0.0,0.0})
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
            world:entity(ae).animation[name] = new_anim
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

local ui_loop = {true}
function m.clear()
    if current_skeleton and current_joint then
        joint_utils:set_current_joint(current_skeleton, nil)
    end
    anim_e = {}
    allanims = {}
    current_skeleton = nil
    current_anim = nil
    current_joint = nil
    if joints_list then
        for _, joint in ipairs(joints_list) do
            if joint.mesh then
                world:remove_entity(joint.mesh)
            end
            joint.mesh = nil
        end
    end
    joint_utils.on_select_joint = nil
    joint_utils.update_joint_pose = nil
end
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
            if joints_map and current_skeleton then
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
        for _, clip in ipairs(value.clips) do
            clip.range_ui = nil
            clip.repeat_ui = nil
            clip.random_amplitude_ui = nil
            clip.amplitude_pos_ui = nil
            clip.amplitude_rot_ui = nil
        end
    end
    utils.write_file(filename, stringify({name = current_anim.name, duration = current_anim.duration, joint_anims = joint_anims, sample_ratio = sample_ratio, skeleton = tostring(current_skeleton)}))
    if file_path ~= filename then
        file_path = filename
    end
end
local fs        = require "filesystem"
local datalist  = require "datalist"
function m.load(path)
    if not current_skeleton then
        return
    end
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
        sample_ratio = anim.sample_ratio
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
            scene = {srt = {s = joint_scale}},
            filter_state = "main_view|selectable",
            material = "/pkg/tools.prefab_editor/res/materials/joint.material",
            mesh = "/pkg/tools.prefab_editor/res/meshes/joint.meshbin",
            name = joint_name,
            on_ready = function(e)
                w:sync("render_object:in", e)
				imaterial.set_property(e, "u_basecolor_factor", math3d.vector(bone_color))
				ifs.set_state(e, "auxgeom", true)
                w:sync("render_object_update:out", e)
                ies.set_state(e, "main_view", false)
			end
        }
    }
    return ecs.create_entity(template)
end

function m.init(skeleton)
    if #anim_e == 0 then
        for ske_e in w:select "id:in skeleton:in animation:in" do
            if ske_e.skeleton == skeleton then
                anim_e[#anim_e + 1] = ske_e.id
            end
        end
    end
    if not current_skeleton then
        current_skeleton = skeleton
    end
    if not joint_utils.on_select_joint then
        joint_utils.on_select_joint = function(old, new)
            if old and old.mesh then
                imaterial.set_property(world:entity(old.mesh), "u_basecolor_factor", bone_color) 
            end
            if new then
                imaterial.set_property(world:entity(new.mesh), "u_basecolor_factor", bone_highlight_color)
                if current_anim then
                    local layer_index = find_anim_by_name(new.name) or 0
                    if layer_index ~= 0 then
                        if #current_anim.joint_anims[layer_index].clips > 0 then
                            current_anim.selected_clip_index = 1
                        end
                    end
                    current_anim.selected_layer_index = layer_index
                    current_anim.dirty = true
                end
            end
        end
    end
    if not joint_utils.update_joint_pose then
        joint_utils.update_joint_pose = function(root_mat)
            if not joints_list then
                return
            end
            local pose_result
            for ee in w:select "skeleton:in pose_result:in" do
                if current_skeleton == ee.skeleton then
                    pose_result = ee.pose_result
                    break
                end
            end
            if pose_result then
                for _, joint in ipairs(joints_list) do
                    if joint.mesh then
                        local mesh_e = world:entity(joint.mesh)
                        if mesh_e then
                            iom.set_srt_matrix(mesh_e, math3d.mul(root_mat, math3d.mul(mc.R2L_MAT, pose_result:joint(joint.index))))
                            iom.set_scale(mesh_e, joint_scale)
                        end
                    end
                end
            end
        end
    end
    joints_map, joints_list = joint_utils:get_joints(skeleton)
    for _, joint in ipairs(joints_list) do
        if not joint.mesh then
            joint.mesh = create_bone_entity(joint.name)
        end
    end
end

return m