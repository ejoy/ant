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
local animation = require "hierarchy".animation
local skeleton = require "hierarchy".skeleton
local math3d        = require "math3d"
local asset_mgr = import_package "ant.asset"
local icons     = require "common.icons"(asset_mgr)
local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util
local m = {}
local file_path = ""
local joints
local current_skeleton
local joint_anim = {
    dirty = true,
    dirty_layer = -1,-- [1...n]: dirty index, 0: no dirty, -1: all dirty
    duration = 1.6,
    is_playing = false,
    selected_layer_index = -1,
    selected_frame = -1,
    current_frame = 0,
    clip_range_dirty = 0,
    selected_clip_index = 0,
    anims = {}
}
local anim_e = {}
local allclips = {}
local current_joint
local sample_ratio = 50.0

local anim_name = "baked_anim"
local allanims = {}
local current_anim

local function update_animation(joint_name)
    local joint = joint_utils:get_joint_by_name(current_skeleton, joint_name)
    if not joint then
        assert(false)
    end
    if not allclips[joint] then
        return
    end
    local total_frames = joint_anim.duration * sample_ratio
    local function push_anim_key(anim, jointname, clips)
        for _, clip in ipairs(clips) do
            local from_pos = clip.from.pos
            local from_rot = clip.from.rot
            local time = (clip.range[1] / total_frames) * joint_anim.duration
            anim:push_prekey(
                jointname,
                time, -- time [0, duration]
                mc.ONE, -- scale
                math3d.quaternion{math.rad(from_rot[1]), math.rad(from_rot[2]), math.rad(from_rot[3])},
                math3d.vector({from_pos[1], from_pos[2], from_pos[3]}) -- translation
            )
            print(jointname, time, from_pos[1], from_pos[2], from_pos[3])
            local to_pos = clip.to.pos
            local to_rot = clip.to.rot
            time = (clip.range[2] / total_frames) * joint_anim.duration
            anim:push_prekey(
                jointname,
                time, -- time [0, duration]
                mc.ONE, -- scale
                math3d.quaternion{math.rad(to_rot[1]), math.rad(to_rot[2]), math.rad(to_rot[3])},
                math3d.vector({to_pos[1], to_pos[2], to_pos[3]}) -- translation
            )
            print(jointname, time, to_pos[1], to_pos[2], to_pos[3])
        end
    end
    -- for joint, clips in pairs(allclips) do
    --     push_anim_key(current_anim.raw_animation, joint.name, clips)
    -- end
    
    current_anim.raw_animation:clear_prekey(joint.name)
    local clips = allclips[joint]
    push_anim_key(current_anim.raw_animation, joint.name, clips)
    current_anim._handle = current_anim.raw_animation:build()
end

local function min_max_range_value(clip_index)
    return 0, math.ceil(joint_anim.duration * sample_ratio) - 1
end

local function on_move_clip(move_type, current_clip_index, move_delta)
    local anim = joint_anim.anims[joint_anim.selected_layer_index]
    local clips = anim.clips
    if current_clip_index <= 0 or current_clip_index > #clips then return end
    local clip = clips[current_clip_index]
    if not clip then return end
    local min_value, max_value = min_max_range_value(current_clip_index)
    if move_type == 1 then
        local new_value = clip.range[1] + move_delta
        if new_value < 0 then
            new_value = 0
        end
        if new_value > clip.range[2] then
            new_value = clip.range[2]
        end
        clip.range[1] = new_value
        clip.range_ui[1] = clip.range[1]
    elseif move_type == 2 then
        local new_value = clip.range[2] + move_delta
        if new_value < clip.range[1] then
            new_value = clip.range[1]
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
    --set_clips_dirty(true)
    joint_anim.dirty_layer = joint_anim.selected_layer_index
    update_animation(anim.joint_name)
end
local function clip_exist(clips, name)
    for _, v in ipairs(clips) do
        if v.name == name then
            return true
        end
    end
end

local function find_anim_by_name(name)
    for index, value in ipairs(joint_anim.anims) do
        if name == value.joint_name then
            return index
        end
    end
end

local function show_current_joint()
    if not current_joint then return end
    imgui.widget.Text("Joint: "..current_joint.name)
    imgui.cursor.Separator();
    if imgui.widget.Button("NewClip") then
        local clips = allclips[current_joint]
        if not clips then
            clips = {}
            allclips[current_joint] = clips
            joint_anim.anims[#joint_anim.anims + 1] = {
                joint_name = current_joint.name,
                clips = clips
            }
        end
        local new_clip = {
            from = {pos = {0,0,0}, rot = {0,0,0}},
            from_ui = {pos= {0,0,0, speed = 0.1}, rot = {0,0,0, speed = 0.1}},
            to = {pos = {0,35,0}, rot = {0,0,0}},
            to_ui = {pos= {0,35,0, speed = 0.1}, rot = {0,0,0, speed = 0.1}},
            range = {20, 50},
            range_ui = {20, 50, speed = 1}
        }
        clips[#clips + 1] = new_clip
        joint_anim.selected_clip_index = #clips
        table.sort(clips, function(a, b) return a.range[2] < b.range[1] end)
        -- set_clips_dirty(true)
        local index, _ = find_anim_by_name(current_joint.name)
        joint_anim.selected_layer_index = index
        joint_anim.dirty_layer = -1
    end

    if joint_anim.selected_layer_index < 1 or joint_anim.selected_clip_index < 1  then
        return
    end
    local anim = joint_anim.anims[joint_anim.selected_layer_index]
    local clips = anim.clips
    local current_clip = clips[joint_anim.selected_clip_index]
    if not current_clip then return end
    
    imgui.cursor.Separator();
    imgui.widget.PropertyLabel("FrameRange")
    --local clip_index = find_index(all_clips, current_clip)
    local min_value, max_value = min_max_range_value()
    local old_range = {current_clip.range_ui[1], current_clip.range_ui[2]}
    local dirty = false
    if imgui.widget.DragInt("##Range", current_clip.range_ui) then
        local range_ui = current_clip.range_ui
        if old_range[1] ~= range_ui[1] then
            if range_ui[1] < min_value then
                range_ui[1] = min_value
            elseif range_ui[1] > range_ui[2] then
                range_ui[1] = range_ui[2]
            end
        elseif old_range[2] ~= range_ui[2] then
            if range_ui[2] > max_value  then
                range_ui[2] = max_value
            elseif range_ui[2] < range_ui[1]  then
                range_ui[2] = range_ui[1]
            end
        end
        current_clip.range = {range_ui[1], range_ui[2]}
        --set_clips_dirty(true)
        joint_anim.dirty_layer = joint_anim.selected_layer_index
        dirty = true
    end
    imgui.widget.PropertyLabel("Position")
    imgui.cursor.NewLine()
    imgui.widget.PropertyLabel("  From")
    local ui_data = current_clip.from_ui.pos
    if imgui.widget.DragFloat("##posfrom", ui_data) then
        current_clip.from.pos = {ui_data[1], ui_data[2], ui_data[3]}
        dirty = true
    end
    imgui.widget.PropertyLabel("  To")
    ui_data = current_clip.to_ui.pos
    if imgui.widget.DragFloat("##posto", ui_data) then
        current_clip.to.pos = {ui_data[1], ui_data[2], ui_data[3]}
        dirty = true
    end
    imgui.widget.PropertyLabel("Rotation")
    imgui.cursor.NewLine()
    imgui.widget.PropertyLabel("  From")
    ui_data = current_clip.from_ui.rot
    if imgui.widget.DragFloat("##rotfrom", ui_data) then
        current_clip.from.rot = {ui_data[1], ui_data[2], ui_data[3]}
        dirty = true
    end
    imgui.widget.PropertyLabel("  To")
    if imgui.widget.DragFloat("##rotto", ui_data) then
        current_clip.to.rot = {ui_data[1], ui_data[2], ui_data[3]}
        dirty = true
    end
    if dirty then
        update_animation(anim.joint_name)
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

--local ui_loop = {false}
local ui_loop = {true}
function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    for _ in uiutils.imgui_windows("Skeleton", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        if imgui.widget.Button("Load") then
            m.load()
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Save") then
            m.save()
        end
        imgui.cursor.SameLine()
        if #anim_e > 0 then
            joint_anim.is_playing = iani.is_playing(anim_e[1])
            if joint_anim.is_playing then
                joint_anim.current_frame = math.floor(iani.get_time(anim_e[1]) * sample_ratio)
            end
        end
        local icon = joint_anim.is_playing and icons.ICON_PAUSE or icons.ICON_PLAY
        if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
            if joint_anim.is_playing then
                anim_pause(true)
            else
                anim_play({name = anim_name, loop = ui_loop[1], manual = false}, iani.play)
                -- for i = 1, 20 do
                --     local poseresult = animation.new_pose_result(#current_skeleton._handle)
                --     poseresult:setup(current_skeleton._handle)
                --     poseresult:do_sample(current_anim._sampling_context, current_anim._handle, (i - 1) / 20.0, 0)
                --     poseresult:fetch_result()

                --     for i = 1, poseresult:count() do
                --         local s, r, t = math3d.srt(poseresult:joint(i))
                --         print(("joint %d:"):format(i), table.concat(math3d.tovalue(t), ","))
                --     end
                -- end
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("loop", ui_loop) then
            anim_set_loop(ui_loop[1])
        end
        imgui.cursor.SameLine()
        local current_time = #anim_e > 0 and iani.get_time(anim_e[1]) or 0
        imgui.widget.Text(string.format("Selected Frame: %d Time: %.2f(s) Current Frame: %d/%d Time: %.2f/%.2f(s)", joint_anim.selected_frame, joint_anim.selected_frame / sample_ratio, math.floor(current_time * sample_ratio), math.floor(joint_anim.duration * sample_ratio), current_time, joint_anim.duration))
        
        if imgui.table.Begin("SkeletonColumns", 3, imgui.flags.Table {'Resizable', 'ScrollY'}) then
            imgui.table.SetupColumn("Joints", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
            imgui.table.SetupColumn("Detail", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
            imgui.table.SetupColumn("AnimationLayer", imgui.flags.TableColumn {'WidthStretch'}, 6.0)
            imgui.table.HeadersRow()

            imgui.table.NextColumn()
            local child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##show_skeleton", child_width, child_height, false)
            if joints then
                joint_utils:show_joints(joints.root)
                current_joint = joint_utils.current_joint
                if current_joint then
                    local layer_index = find_anim_by_name(current_joint.name)
                    if layer_index then
                        if joint_anim.selected_layer_index ~= layer_index then
                            joint_anim.selected_layer_index = layer_index
                            joint_anim.selected_clip_index = 1
                            joint_anim.dirty = true
                        end
                    else
                        joint_anim.selected_clip_index = -1
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

            local imgui_message = {}
            imgui.widget.SimpleSequencer(joint_anim, imgui_message)
            joint_anim.dirty = false
            joint_anim.clip_range_dirty = 0
            joint_anim.dirty_layer = 0
            local move_type
            local new_frame_idx
            local move_delta
            for k, v in pairs(imgui_message) do
                if k == "pause" then
                    joint_anim.current_frame = v
                elseif k == "selected_frame" then
                    joint_anim.selected_frame = v
                elseif k == "selected_clip_index" then
                    joint_anim.selected_clip_index = v
                elseif k == "selected_layer_index" then
                    joint_anim.selected_layer_index = v
                    if v > 0 and v <= #joint_anim.anims then
                        joint_utils:set_current_joint(current_skeleton, joint_anim.anims[v].joint_name)
                    end
                elseif k == "move_type" then
                    move_type = v
                elseif k == "move_delta" then
                    move_delta = v
                end
            end

            if move_type and move_type ~= 0 then
                on_move_clip(move_type, joint_anim.selected_clip_index, move_delta)
            end

            imgui.windows.EndChild()

            imgui.table.End()
        end
    end
end

local utils         = require "common.utils"
local widget_utils  = require "widget.utils"
local stringify     = import_package "ant.serialize".stringify
function m.save(path)
    local filename
    if not path then
        filename = widget_utils.get_saveas_path("Prefab", "prefab")
        if not filename then return end
    end
    local anims = utils.deep_copy(joint_anim.anims)
    for index, value in ipairs(anims) do
        value.from_ui = nil
        value.to_ui = nil
        value.range_ui = nil
    end
    utils.write_file(filename, stringify({duration = joint_anim.duration, anims = anims}))
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
        for _, value in ipairs(anim.clips) do
            local pos = value.from.pos
            local rot = value.from.rot
            value.from_ui = {pos= {pos[1],pos[2],pos[3], speed = 0.1}, rot = {rot[1],rot[2],rot[3], speed = 0.1}}
            pos = value.to.pos
            rot = value.to.rot
            value.to_ui = {pos= {pos[1],pos[2],pos[3], speed = 0.1}, rot = {rot[1],rot[2],rot[3], speed = 0.1}}
            value.range_ui = {value.range[1],value.range[2], -1, speed = 1}
            local joint = joint_utils:get_joint_by_name(current_skeleton, value.joint_name)
            if not joint then
                assert(false)
            end
            allclips[joint] = value
            joint_anim.anims[#joint_anim.anims + 1] = {
                joint_name = joint.name,
                clips = value
            }
        end
        joint_anim.dirty = true
        joint_anim.dirty_layer = -1
        joint_anim.duration = anim.duration
        joint_anim.is_playing = false
        joint_anim.selected_layer_index = -1
        joint_anim.selected_frame = -1
        joint_anim.current_frame = 0
        joint_anim.clip_range_dirty = 0
        joint_anim.selected_clip_index = 0
        --current_anim.raw_animation:setup(current_skeleton._handle, anim.duration)
    end

end

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
    if not allanims.baked_anim then
        local new_anim = {
            raw_animation = animation.new_raw_animation(),
            _duration = joint_anim.duration,
            _sampling_context = animation.new_sampling_context(1)
        }
        new_anim.raw_animation:setup(current_skeleton._handle, joint_anim.duration)
        current_anim = new_anim
        allanims.baked_anim = new_anim
        for _, e in ipairs(anim_e) do
            e.animation["baked_anim"] = new_anim
        end
    end
    
    joints = joint_utils:get_joints(e)
end

return m