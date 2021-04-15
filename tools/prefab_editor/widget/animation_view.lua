local imgui     = require "imgui"
local math3d    = require "math3d"
local hierarchy = require "hierarchy"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local utils     = require "common.utils"
local fs        = require "filesystem"
local world
local icons
local iani
local prefab_mgr
local ies
local gizmo
local iom

local m = {}
local ozz_anims = {}
local current_eid
local imgui_message
local current_anim_name
local current_clip_name = "None"
local current_anim
local selected_frame = -1
local sample_ratio = 30.0
local animation_list = {

}
local anim_state = {
    duration = 0,
    current_time = 0,
    is_playing = false,
    anim_name = "",
    key_event = {},
    event_dirty = 0,
    clip_range_dirty = 0,
    selected_clip_index = 0,
    current_event_list = {}
}


local event_type = {
    "Effect", "Sound", "Collision", "Message"
}
local joint_list = {

}
local joints = {}

local current_joint
local current_event
local current_collider
local current_clip
local anim_group_eid = {}
local all_clips = {}
local all_groups = {}

local clip_index = 0
local group_index = 0

local function find_index(t, item)
    for i, c in ipairs(t) do
        if c == item then
            return i
        end
    end
end

local function anim_group_set_time(eid, t)
    local group_eid = anim_group_eid[ozz_anims[eid][current_anim_name].anim_obj]
    for _, anim_eid in ipairs(group_eid) do
        iani.set_time(anim_eid, t)
    end
end

local function anim_group_play(eid, ...)
    local group_eid = anim_group_eid[ozz_anims[eid][current_anim_name].anim_obj]
    for _, anim_eid in ipairs(group_eid) do
        iani.play(anim_eid, ...)
    end
end

local function anim_group_set_loop(eid, ...)
    local group_eid = anim_group_eid[ozz_anims[eid][current_anim_name].anim_obj]
    for _, anim_eid in ipairs(group_eid) do
        iani.set_loop(anim_eid, ...)
    end
end

local function anim_group_pause(eid, p)
    local group_eid = anim_group_eid[ozz_anims[eid][current_anim_name].anim_obj]
    for _, anim_eid in ipairs(group_eid) do
        iani.pause(anim_eid, p)
    end
end

local function set_current_anim(anim_name)
    if current_anim and current_anim.collider then
        for _, col in ipairs(current_anim.collider) do
            if col.collider then
                ies.set_state(col.eid, "visible", false)
            end
        end
    end
    current_anim = ozz_anims[current_eid][anim_name]
    if current_anim and current_anim.collider then
        for _, col in ipairs(current_anim.collider) do
            if col.collider then
                ies.set_state(col.eid, "visible", true)
            end
        end
    end
    current_anim_name = anim_name
    anim_state.anim_name = current_anim.name
    anim_state.key_event = current_anim.key_event
    anim_state.duration = current_anim.duration
    current_collider = nil
    current_event = nil
    
    anim_group_play(current_eid, anim_name, 0)
    anim_group_set_time(current_eid, 0)
    anim_group_pause(current_eid, true)
    -- if not iani.is_playing(current_eid) then
    --     anim_group_pause(current_eid, false)
    -- end
end

local default_collider_define = {
    ["sphere"]  = {{origin = {0, 0, 0, 1}, radius = 0.1}},
    ["box"]     = {{origin = {0, 0, 0, 1}, size = {0.05, 0.05, 0.05}}},
    ["capsule"] = {{origin = {0, 0, 0, 1}, height = 1.0, radius = 0.25}}
}

local collider_list = {}

local function get_collider(shape_type, def)
    collider_list[#collider_list + 1] = prefab_mgr:create("collider",
        {type = shape_type, define = def or utils.deep_copy(default_collider_define[shape_type]), parent = prefab_mgr.root, add_to_hierarchy = true})
    return #collider_list
end

local function from_runtime_event(runtime_event)
    local key_event = {}
    if runtime_event.event then
        for _, ev in ipairs(runtime_event.event) do
            for _, e in ipairs(ev.event_list) do
                e.name_ui = {text = e.name}
                if e.event_type == "Sound" or e.event_type == "Effect" then
                    e.rid_ui = {e.rid}
                    e.asset_path_ui = {text = e.asset_path}
                elseif e.event_type == "Collision" then
                    local col_def = e.collision.shape_def
                    local def
                    if col_def.shape_type == "sphere" then
                        def = {{origin = {0, 0, 0, 1}, radius = col_def.radius}}
                    elseif col_def.shape_type == "box" then
                        def = {{origin = {0, 0, 0, 1}, size = col_def.halfsize}}
                    elseif col_def.shape_type == "capsule" then
                        def = {{origin = {0, 0, 0, 1}, height = col_def.height, radius = col_def.radius}}
                    end
                    e.collision.eid_index = get_collider(col_def.shape_type, def)
                    e.collision.enable_ui = {e.collision.enable}
                    e.collision.shape_type = col_def.shape_type
                    iom.set_srt(collider_list[e.collision.eid_index], math3d.matrix{ s = world[collider_list[e.collision.eid_index]].transform.s, r = col_def.offset.rotate, t = col_def.offset.position })
                end
            end
            key_event[tostring(math.floor(ev.time * sample_ratio))] = ev.event_list
        end
    end
    return key_event
end

local function from_runtime_clip(runtime_clip)
    all_clips = {}
    all_groups = {}
    for _, anim in pairs(ozz_anims[current_eid]) do
        if type(anim) == "table" and anim.clips then
            anim.clips = {}
        end
    end
    for _, clip in ipairs(runtime_clip) do
        if clip.range then
            local start_frame = math.floor(clip.range[1] * sample_ratio)
            local end_frame = math.floor(clip.range[2] * sample_ratio)
            local new_clip = {
                anim_name = clip.anim_name,
                name = clip.name,
                range = {start_frame, end_frame},
                name_ui = {text = clip.name},
                range_ui = {start_frame, end_frame, speed = 1}
            }
            local anim_clips = ozz_anims[current_eid][clip.anim_name].clips
            anim_clips[#anim_clips + 1] = new_clip
            all_clips[#all_clips+1] = new_clip
        end
    end
    
    for _, clip in ipairs(runtime_clip) do
        if not clip.range then
            local subclips = {}
            for _, v in ipairs(clip.subclips) do
                subclips[#subclips + 1] = all_clips[v]
            end
            all_groups[#all_groups + 1] = {
                name = clip.name,
                clips = subclips,
                name_ui = {text = clip.name}
            }
        end
    end
    clip_index = #all_clips
    group_index = #all_groups
    -- for _, anim in pairs(ozz_anims[current_eid]) do
    --     if type(anim) == "table" and anim.clips then
    --         table.sort(anim.clips, function(a, b) return a.range[2] < b.range[1] end)
    --     end
    -- end

    -- table.sort(all_clips, function(a, b) return a.range[2] < b.range[1] end)
end

local function get_runtime_clips()
    if not world[current_eid].anim_clips then
        iani.set_clips(current_eid, {})
    end
    return world[current_eid].anim_clips
end

local function get_runtime_events()
    if not world[current_eid].keyframe_events or not world[current_eid].keyframe_events[current_anim_name] then
        iani.set_events(current_eid, current_anim_name, {})
    end
    return world[current_eid].keyframe_events[current_anim_name]
end

local function to_runtime_group(runtime_clips, group)
    local groupclips = {}
    for _, clip in ipairs(group.clips) do
        groupclips[#groupclips + 1] = find_index(runtime_clips, clip)
    end
    return {name = group.name, subclips = groupclips}
end

local function to_runtime_clip()
    local runtime_clips = {}
    for _, clip in ipairs(all_clips) do
        if clip.range[1] > 0 and clip.range[2] > 0 and clip.range[2] > clip.range[1] then
            runtime_clips[#runtime_clips + 1] = {anim_name = clip.anim_name, name = clip.name, range = {clip.range[1] / sample_ratio, clip.range[2] / sample_ratio}}
        end
    end
    for _, group in ipairs(all_groups) do
        runtime_clips[#runtime_clips + 1] = to_runtime_group(all_clips, group)
    end
    if #runtime_clips < 1  then return end
    iani.set_clips(current_eid, runtime_clips)
end

local function to_runtime_event()
    local runtime_event = get_runtime_events()
    local temp = {}
    for key, value in pairs(current_anim.key_event) do
        if #value > 0 then
            temp[#temp + 1] = tonumber(key)
        end
    end
    table.sort(temp, function(a, b) return a < b end)
    local event = {}
    for i, frame_idx in ipairs(temp) do
        event[#event + 1] = {
            time = frame_idx / sample_ratio,
            event_list = current_anim.key_event[tostring(frame_idx)]
        }
    end
    runtime_event.event = event
    runtime_event.collider = current_anim.collider
end

local function set_event_dirty(num)
    anim_state.event_dirty = num
    if num ~= 0 then
        to_runtime_event()
    end
end

local event_id = 1
local function add_event(et)
    local event_list = anim_state.current_event_list
    if #event_list >= event_id then
        event_id = event_id + 1
    end 
    local event_name = et..tostring(event_id)
    event_list[#event_list + 1] = {
        event_type = et,
        name = event_name,
        rid = (et == "Effect" or et == "Sound") and -1 or nil,
        asset_path = (et == "Effect" or et == "Sound") and "" or nil,
        link_info = (et == "Effect") and {
            slot_name = "",
            slot_eid = current_eid
        } or nil,
        name_ui = {text = event_name},
        rid_ui = {-1},
        asset_path_ui = (et == "Effect" or et == "Sound") and {text = ""} or nil,
        collision = (et == "Collision") and {
            eid_index = get_collider("sphere"),
            shape_type = "sphere",
            enable = true,
        } or nil
    }
    set_event_dirty(1)
end

local function delete_collider(collider)
    if not collider then return end
    local event_dirty
    for _, events in pairs(current_anim.key_event) do
        for i = #events, 1, -1 do
            if events[i] == collider then
                table.remove(events, i)
                event_dirty = true
            end
        end
    end
    for i = #current_anim.collider, 1, -1 do
        if current_anim.collider[i] == collider then
            table.remove(current_anim.collider, i)
        end
    end
    current_collider = nil
    if event_dirty then
        set_event_dirty(-1)
    else
        local runtime_event = get_runtime_events()
        runtime_event.collider = current_anim.collider
    end
end

local function delete_event(idx)
    if not idx then return end
    if anim_state.current_event_list[idx].collider then
        prefab_mgr:remove_entity(anim_state.current_event_list[idx].collider.eid)
        delete_collider(anim_state.current_event_list[idx].collider)
    end
    current_event = nil
    table.remove(anim_state.current_event_list, idx)
    set_event_dirty(1)
end

local function clear_event()
    current_anim.key_event[tostring(selected_frame)] = {}
    anim_state.current_event_list = current_anim.key_event[tostring(selected_frame)]
    set_event_dirty(1)
end

local shape_type = {
    "sphere","box","capsule"
}
local collider_type = {
    "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8"
}
local collider_id = 1
local function add_collider(ct)
    if not current_anim.collider then
        current_anim.collider = {}
    end
    if ct == "capsule" then return end

    if #current_anim.collider >= collider_id then
        collider_id = #current_anim.collider + 1
    end 
    
    local shape = {type = ct, define = utils.deep_copy(default_collider_define[ct])}
    local colname = "collider" .. collider_id
    current_anim.collider[#current_anim.collider + 1] = {
        hid = 0,
        name = colname,
        shape = shape,
        type = collider_type[1],
        slot_name = "",
        --
        eid = prefab_mgr:create("geometry", {type = "sphere"}),
        hid_ui = {0},
        name_ui = {text = colname},
        radius_ui = {0.025, speed = 0.01},
        height_ui = {0.025, speed = 0.01},
        halfsize_ui = {0.025, 0.025, 0.025, speed = 0.01}
    }
    collider_id = collider_id + 1
    local runtime_event = get_runtime_events()
    runtime_event.collider = current_anim.collider
end

local function show_events()
    if selected_frame >= 0 then
        imgui.cursor.SameLine()
        if imgui.widget.Button("AddEvent") then
            imgui.windows.OpenPopup("AddKeyEvent")
        end
    end

    if imgui.windows.BeginPopup("AddKeyEvent") then
        for _, et in ipairs(event_type) do
            if imgui.widget.MenuItem(et) then
                add_event(et)
            end
        end
        imgui.windows.EndPopup()
    end
    if #anim_state.current_event_list > 0 then
        imgui.cursor.SameLine()
        if imgui.widget.Button("ClearEvent") then
            clear_event()
        end
    end
    if anim_state.current_event_list then
        local delete_idx
        for idx, ke in ipairs(anim_state.current_event_list) do
            if imgui.widget.Selectable(ke.name, current_event and (current_event.name == ke.name)) then
                current_event = ke
                if current_event.collision and current_event.collision.collider then
                    gizmo:set_target(current_event.collision.collider.eid)
                end
            end
            if current_event and (current_event.name == ke.name) then
                if imgui.windows.BeginPopupContextItem(ke.name) then
                    if imgui.widget.Selectable("Delete", false) then
                        delete_idx = idx
                    end
                    imgui.windows.EndPopup()
                end
            end
        end
        delete_event(delete_idx)
    end
end
local slot_list = {}
local function show_current_event()
    if not current_event then return end
    imgui.widget.PropertyLabel("EventType")
    imgui.widget.Text(current_event.event_type)

    if current_event.event_type == "Effect" or current_event.event_type == "Sound" then
        imgui.widget.PropertyLabel("RID")
        if imgui.widget.DragInt("##RID", current_event.rid_ui) then
            current_event.rid = current_event.rid_ui[1]
        end
    end

    imgui.widget.PropertyLabel("Name")
    if imgui.widget.InputText("##Name", current_event.name_ui) then
        current_event.name = tostring(current_event.name_ui.text)
    end
    
    if current_event.event_type == "Collision" then
        local collision = current_event.collision
        imgui.widget.PropertyLabel("ShapeType")
        if imgui.widget.BeginCombo("##ShapeType", {collision.shape_type, flags = imgui.flags.Combo {}}) then
            for _, type in ipairs(shape_type) do
                if imgui.widget.Selectable(type, collision.shape_type == type) then
                    collision.shape_type = type
                    if collision.eid_index then
                        prefab_mgr:remove_entity(collider_list[collision.eid_index])
                        collider_list[collision.eid_index] = 0
                    end
                    collision.eid_index = get_collider(type)
                end
            end
            imgui.widget.EndCombo()
        end
        imgui.widget.PropertyLabel("Enable")
        if imgui.widget.Checkbox("##Enable", collision.enable_ui) then
            collision.enable = collision.enable_ui[1]
        end
        -- if collision.shape_type ~= "None" then
        --     if imgui.widget.TreeNode("Offset", imgui.flags.TreeNode { "DefaultOpen" }) then
        --         imgui.widget.PropertyLabel("Position")
        --         if imgui.widget.DragFloat("##Position", collision.offset_ui.position) then
        --             collision.offset.position = {collision.offset_ui.position[1], collision.offset_ui.position[2], collision.offset_ui.position[3]}
        --         end
        --         imgui.widget.PropertyLabel("Rotate")
        --         if imgui.widget.DragFloat("##Rotate", collision.offset_ui.rotate) then
        --             collision.offset.rotate = {collision.offset_ui.rotate[1], collision.offset_ui.rotate[2], collision.offset_ui.rotate[3]}
        --         end
        --         imgui.widget.TreePop()
        --     end
        -- end
    elseif current_event.event_type == "Sound" then
        if imgui.widget.Button("SelectSound") then
        end
        imgui.widget.Text("SoundPath : ")
    elseif current_event.event_type == "Effect" then
        if imgui.widget.Button("SelectEffect") then
            local path = uiutils.get_open_file_path("Prefab", ".prefab")
            if path then
                local global_data = require "common.global_data"
                local lfs         = require "filesystem.local"
                local rp = lfs.relative(lfs.path(path), global_data.project_root)
                local path = global_data.package_path .. tostring(rp)
                current_event.asset_path_ui.text = path
                current_event.asset_path = path
            end
        end
        imgui.widget.PropertyLabel("EffectPath")
        imgui.widget.InputText("##EffectPath", current_event.asset_path_ui)
        local slot_list = world[current_eid].slot_list
        if slot_list then
            imgui.widget.PropertyLabel("LinkSlot")
            if imgui.widget.BeginCombo("##LinkSlot", {current_event.link_info.slot_name, flags = imgui.flags.Combo {}}) then
                for name, eid in pairs(slot_list) do
                    if imgui.widget.Selectable(name, current_event.link_info.slot_name == name) then
                        current_event.link_info.slot_name = name
                        current_event.link_info.slot_eid = eid
                    end
                end
                imgui.widget.EndCombo()
            end
        end
    end
end

local function set_clips_dirty(update)
    anim_state.clip_range_dirty = 1
    if update then
        to_runtime_clip()
    end
end

local function update_collision()
    for _, shape in ipairs(collider_list) do
        if shape > 0 then
            ies.set_state(shape, "visible", false)
        end
    end

    for idx, ke in ipairs(anim_state.current_event_list) do
        if ke.collision and ke.collision.eid_index then
            ies.set_state(collider_list[ke.collision.eid_index], "visible", true)
        end
    end
end

local function on_move_keyframe(frame_idx, move_type)
    if not frame_idx or selected_frame == frame_idx then return end
    local old_selected_frame = selected_frame
    selected_frame = frame_idx
    local newkey = tostring(selected_frame)
    if move_type == 0 then
        local oldkey = tostring(old_selected_frame)
        current_anim.key_event[newkey] = current_anim.key_event[oldkey]
        current_anim.key_event[oldkey] = {}
        to_runtime_event()
    else
        if not current_anim.key_event[newkey] then
            current_anim.key_event[newkey] = {}
        end
        anim_state.current_event_list = current_anim.key_event[newkey]
        update_collision()
        current_event = nil
    end
end
local function min_max_range_value(clip_index)
    return 0, math.floor(current_anim.duration * sample_ratio) - 1
end

local function on_move_clip(move_type, current_clip_index, move_delta)
    local clips = current_anim.clips
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
    set_clips_dirty(true)
end

local current_event_file
local current_clip_file
local stringify     = import_package "ant.serialize".stringify
local widget_utils  = require "widget.utils"
local function save_event(filename)
    if not filename then
        filename = widget_utils.get_saveas_path("Event", ".event")
    end
    if not filename then return end
    local runtime_event = get_runtime_events()
    local serialize_data = {
        event = {}
    }
    for _, ev in ipairs(runtime_event.event) do
        local list = {}
        for _, ev in ipairs(ev.event_list) do
            local col_eid = ev.collision and collider_list[ev.collision.eid_index] or nil
            local col_def = {}
            if col_eid then
                local col = world[col_eid].collider
                col_def.offset = {position = math3d.totable(iom.get_position(col_eid)), rotation = math3d.totable(iom.get_rotation(col_eid))}
                if col.sphere then
                    col_def.shape_type = "sphere"
                    col_def.radius = col.sphere[1].radius
                elseif col.box then
                    col_def.shape_type = "box"
                    col_def.halfsize = col.box[1].size
                elseif col.capsule then
                    col_def.shape_type = "capsule"
                    col_def.radius = col.capsule[1].radius
                    col_def.height = col.capsule[1].height
                end
            end
            list[#list + 1] = {
                event_type = ev.event_type,
                name = ev.name,
                rid = ev.rid,
                collision = col_eid and {
                    shape_def = col_def,
                    enable = ev.collision.enable,
                } or nil
            }
        end
        serialize_data.event[#serialize_data.event + 1] = {
            time = ev.time,
            event_list = list
        }
    end
    utils.write_file(filename, stringify(serialize_data))
end

local function save_clip(filename)
    if not filename then
        filename = widget_utils.get_saveas_path("Clip", ".clip")
    end
    if not filename then return end
    if current_clip_file ~= filename then
        current_clip_file = filename
    end
    local runtime_clip = get_runtime_clips()
    utils.write_file(filename, stringify(runtime_clip))
end

local function show_clips()
    if imgui.widget.Button("NewClip") then
        local key = "Clip" .. clip_index
        clip_index = clip_index + 1
        local new_clip = {
            anim_name = current_anim_name,
            name = key,
            range = {-1, -1},
            name_ui = {text = key},
            range_ui = {-1, -1, speed = 1}
        }
        current_anim.clips[#current_anim.clips + 1] = new_clip
        table.sort(current_anim.clips, function(a, b)
            return a.range[2] < b.range[1]
        end)
        all_clips[#all_clips+1] = new_clip
        table.sort(all_clips, function(a, b)
            return a.range[2] < b.range[1]
        end)
        set_clips_dirty(true)
    end
    
    local delete_index
    local anim_name
    for i, cs in ipairs(all_clips) do
        if imgui.widget.Selectable(cs.name, current_clip and (current_clip.name == cs.name), 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
            current_clip = cs
            set_current_anim(cs.anim_name)
            anim_state.selected_clip_index = find_index(current_anim.clips, cs)
            if imgui.util.IsMouseDoubleClicked(0) then
                anim_group_play(current_eid, cs.name, 0)
                anim_group_set_loop(current_eid, false)
            end
        end
        if current_clip and (current_clip.name == cs.name) then
            if imgui.windows.BeginPopupContextItem(cs.name) then
                if imgui.widget.Selectable("Delete", false) then
                    delete_index = i
                end
                imgui.windows.EndPopup()
            end
        end
    end
    if delete_index then
        local anim_name = current_clip
        local delete_clip = all_clips[delete_index]
        if all_groups then
            for _, group in ipairs(all_groups) do
                local found = find_index(group.clips, delete_clip)
                if found then
                    table.remove(group.clips, found)
                end
            end
        end
        local found = find_index(current_anim.clips, delete_clip)
        if found then
            table.remove(current_anim.clips, found)
        end
        table.remove(all_clips, delete_index)
        current_clip = nil
        set_clips_dirty(true)
    end
end

local current_group

local function show_groups()
    if imgui.widget.Button("NewGroup") then
        local key = "Group" .. group_index
        group_index = group_index + 1
        all_groups[#all_groups + 1] = {
            name = key,
            name_ui = {text = key},
            clips ={}
        }
        set_clips_dirty(true)
    end
    local delete_group
    for i, gp in ipairs(all_groups) do
        if imgui.widget.Selectable(gp.name, current_group and (current_group.name == gp.name), 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
            current_group = gp
            if imgui.util.IsMouseDoubleClicked(0) then
                anim_group_play(current_eid, gp.name, 0)
                anim_group_set_loop(current_eid, false)
            end
        end
        if current_group and (current_group.name == gp.name) then
            if imgui.windows.BeginPopupContextItem(gp.name) then
                if imgui.widget.Selectable("Delete", false) then
                    delete_group = i
                end
                imgui.windows.EndPopup()
            end
        end
    end
    if delete_group then
        table.remove(all_groups, delete_group)
        current_group = nil
        set_clips_dirty(true)
    end
end

local function show_current_clip()
    if not current_clip then return end
    imgui.widget.PropertyLabel("AnimName")
    imgui.widget.Text(current_clip.anim_name)
    imgui.widget.PropertyLabel("ClipName")
    if imgui.widget.InputText("##ClipName", current_clip.name_ui) then
        current_clip.name = tostring(current_clip.name_ui.text)
    end
    imgui.widget.PropertyLabel("Range")
    --local clip_index = find_index(all_clips, current_clip)
    local min_value, max_value = min_max_range_value()
    local old_range = {current_clip.range_ui[1], current_clip.range_ui[2]}
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
        set_clips_dirty(true)
    end
end

local current_group_clip
local current_clip_label
local function show_current_group()
    if not current_group then return end
    imgui.widget.PropertyLabel("Name")
    if imgui.widget.InputText("##Name", current_group.name_ui) then
        current_group.name = tostring(current_group.name_ui.text)
    end
    if imgui.widget.Button("AddClip") then
        imgui.windows.OpenPopup("AddClipPop")
    end
    
    local function is_valid_range(ct)
        return ct.range[1] >= 0 and ct.range[2] > 0 and ct.range[2] >= ct.range[1]
    end

    if imgui.windows.BeginPopup("AddClipPop") then
        for _, clip in ipairs(all_clips) do
            if is_valid_range(clip) and imgui.widget.MenuItem(clip.name) then
                current_group.clips[#current_group.clips + 1] = clip
                set_clips_dirty(true)
            end
        end
        imgui.windows.EndPopup()
    end
    local delete_clip
    for i, cs in ipairs(current_group.clips) do
        local unique_prefix = tostring(i) .. "."
        local label = unique_prefix .. cs.name
        if imgui.widget.Selectable(label, current_group_clip and (current_clip_label == label)) then
            current_group_clip = cs
            current_clip_label = unique_prefix .. current_group_clip.name
        end
        if current_group_clip and (current_clip_label == label) then
            if imgui.windows.BeginPopupContextItem(label) then
                if imgui.widget.Selectable("Delete", false) then
                    delete_clip = i
                end
                imgui.windows.EndPopup()
            end
        end
    end
    if delete_clip then
        table.remove(current_group.clips, delete_clip)
        set_clips_dirty(true)
        current_clip_label = nil
    end
end

local function show_joints(root)
    local base_flags = imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((current_joint and (current_joint.name == root.name)) and imgui.flags.TreeNode{"Selected"} or 0)
    local flags = base_flags
    local has_child = true
    if #root.children == 0 then
        flags = base_flags | imgui.flags.TreeNode { "Leaf", "NoTreePushOnOpen" }
        has_child = false
    end
    local open = imgui.widget.TreeNode(root.name, flags)
    if imgui.util.IsItemClicked() then
        current_joint = root
    end
    if open and has_child then
        for _, joint in ipairs(root.children) do
            show_joints(joint)
        end
        imgui.widget.TreePop()
    end
end

local recreate_event
local anim_name = ""
local ui_anim_name = {text = ""}
local anim_path = ""
function m.show()
    if not current_eid or not world[current_eid] then return end
    if not recreate_event then
        recreate_event = world:sub {"EntityRecreate"}
    end
    for _, old, new in recreate_event:unpack() do
        for i, c in ipairs(collider_list) do
            if collider_list[i] == old then
                collider_list[i] = new
                break;
            end
        end
    end
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    for _ in uiutils.imgui_windows("Animation", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
    --if imgui.windows.Begin ("Animation", imgui.flags.Window {'AlwaysAutoResize'}) then
        if ozz_anims[current_eid] then
            if current_anim then
                anim_state.current_time = iani.get_time(current_eid)
                anim_state.is_playing = iani.is_playing(current_eid)
            end
            imgui.cursor.SameLine()
            local title = "New Animation"
            if imgui.widget.Button("Add") then
                anim_path = ""
                imgui.windows.OpenPopup(title)
            end
            local change, opened = imgui.windows.BeginPopupModal(title, imgui.flags.Window{"AlwaysAutoResize"})
            if change then
                imgui.widget.Text("Name : ")
                imgui.cursor.SameLine()
                if imgui.widget.InputText("##" .. "Name", ui_anim_name) then
                    anim_name = tostring(ui_anim_name.text)
                end
                imgui.widget.Text("Path : " .. anim_path)
                imgui.cursor.SameLine()
                local origin_name
                if imgui.widget.Button("...") then
                    local filename = uiutils.get_open_file_path("Animation", ".ozz")
                    if filename then
                        local vfs = require "vfs"
                        local path = fs.path(filename)
                        origin_name = path:stem():string()
                        anim_path = "/" .. vfs.virtualpath(path)
                    end
                end
                if #anim_name < 1 and #anim_path > 0 then
                    anim_name = origin_name
                end
                if imgui.widget.Button("  OK  ") then
                    if #anim_name > 0 and #anim_path > 0 then
                        local update = true
                        if world[current_eid].animation[anim_name] then
                            local confirm = {title = "Confirm", message = "animation ".. anim_name .. " exist, replace it ?"}
                            uiutils.confirm_dialog(confirm)
                            if confirm.answer and confirm.answer == 0 then
                                update = false
                            end
                        end
                        if update then
                            local template = hierarchy:get_template(current_eid)
                            template.template.data.animation[anim_name] = anim_path
                            world[current_eid].animation[anim_name] = anim_path
                        end
                    end
                    anim_name = ""
                    ui_anim_name.text = ""
                    imgui.windows.CloseCurrentPopup()
                end
                imgui.cursor.SameLine()
                if imgui.widget.Button("Cancel") then
                    anim_name = ""
                    ui_anim_name.text = ""
                    imgui.windows.CloseCurrentPopup()
                end
                imgui.windows.EndPopup()
            end

            imgui.cursor.SameLine()
            if imgui.widget.Button("Remove") then
                local template = hierarchy:get_template(current_eid)
                template.template.data.animation[current_anim_name] = nil
                world[current_eid].animation[current_anim_name] = nil
            end
            imgui.cursor.SameLine()
            imgui.cursor.PushItemWidth(150)
            if imgui.widget.BeginCombo("##AnimationList", {current_anim_name, flags = imgui.flags.Combo {}}) then
                for _, name in ipairs(animation_list) do
                    if imgui.widget.Selectable(name, current_anim_name == name) then
                        set_current_anim(name)
                        current_clip_name = "None"
                        current_clip = nil
                    end
                end
                imgui.widget.EndCombo()
            end
            imgui.cursor.PopItemWidth()
            imgui.cursor.SameLine()
            local icon = anim_state.is_playing and icons.ICON_PAUSE or icons.ICON_PLAY
            if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
                anim_state.is_playing = not anim_state.is_playing
                anim_group_pause(current_eid, not anim_state.is_playing)
            end
            imgui.cursor.SameLine()
            if imgui.widget.Button("LoadClip") then
                local path = widget_utils.get_open_file_path("Clip", ".clip")
                if path then
                    iani.set_clips(current_eid, path)
                    current_clip_file = path
                    from_runtime_clip(get_runtime_clips())
                    set_clips_dirty(false)
                end
            end
            if all_clips then
                imgui.cursor.SameLine()
                if imgui.widget.Button("SaveClip") then
                    save_clip(current_clip_file)
                end
                imgui.cursor.SameLine()
                if imgui.widget.Button("SaveAsClip") then
                    save_clip()
                end
            end
            imgui.cursor.SameLine()
            if imgui.widget.Button("LoadEvent") then
                local path = widget_utils.get_open_file_path("Event", ".event")
                if path then
                    for _, ev in pairs(current_anim.key_event) do
                        for _, e in ipairs(ev) do
                            if e.collision and e.collision.eid_index then
                                prefab_mgr:remove_entity(collider_list[e.collision.eid_index])
                            end
                        end
                    end
                    current_event_file = path
                    iani.set_events(current_eid, current_anim_name, path)
                    current_anim.key_event = from_runtime_event(get_runtime_events())
                    set_event_dirty(-1)
                end
            end
            imgui.cursor.SameLine()
            if imgui.widget.Button("SaveEvent") then
                save_event(current_event_file)
            end
            imgui.cursor.SameLine()
            if imgui.widget.Button("SaveAsEvent") then
                local filename = widget_utils.get_saveas_path("Prefab", ".prefab")
                if filename then
                    save_event(filename)
                end
            end
            imgui.cursor.SameLine()
            imgui.widget.Text(string.format("Selected Frame: %d Time: %.2f(s) Current Frame: %d Time: %.2f/%.2f(s)", selected_frame, selected_frame / 30, math.floor(anim_state.current_time * 30), anim_state.current_time, anim_state.duration))
            imgui_message = {}
            imgui.widget.Sequencer(ozz_anims[current_eid], anim_state, imgui_message)
            -- clear dirty flag
            anim_state.clip_range_dirty = 0
            set_event_dirty(0)
            --
            local move_type
            local new_frame_idx
            local move_delta
            for k, v in pairs(imgui_message) do
                if k == "pause" then
                    anim_group_pause(current_eid, true)
                    anim_group_set_time(current_eid, v)
                elseif k == "selected_frame" then
                    new_frame_idx = v
                elseif k == "move_type" then
                    move_type = v
                elseif k == "move_delta" then
                    move_delta = v
                end
            end
            on_move_keyframe(new_frame_idx, move_type)
            if move_type and move_type ~= 0 then
                on_move_clip(move_type, anim_state.selected_clip_index, move_delta)
            end
            imgui.cursor.Separator()
            if imgui.table.Begin("EventColumns", 7, imgui.flags.Table {'Resizable', 'ScrollY'}) then
                imgui.table.SetupColumn("Bones", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.SetupColumn("Event", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.SetupColumn("Event(Detail)", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.SetupColumn("Clip", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.SetupColumn("Clip(Detail)", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.SetupColumn("Group", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.SetupColumn("Group(Detail)", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.HeadersRow()

                imgui.table.NextColumn()
                local child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##show_joints", child_width, child_height, false)
                show_joints(joints[current_eid].root)
                imgui.windows.EndChild()

                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##show_events", child_width, child_height, false)
                show_events()
                imgui.windows.EndChild()

                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##show_current_event", child_width, child_height, false)
                show_current_event()
                imgui.windows.EndChild()
                
                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##show_clips", child_width, child_height, false)
                show_clips()
                imgui.windows.EndChild()

                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##show_current_clip", child_width, child_height, false)
                show_current_clip()
                imgui.windows.EndChild()

                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##show_groups", child_width, child_height, false)
                show_groups()
                imgui.windows.EndChild()
                
                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##show_current_group", child_width, child_height, false)
                show_current_group()
                imgui.windows.EndChild()

                imgui.table.End()
            end
        end
    end
end

function m.bind(eid)
    if not eid or not world[eid] or not world[eid].animation then return end
    if current_eid ~= eid then
        current_eid = eid
    end
    if not ozz_anims[eid] then
        animation_list = {}
        ozz_anims[eid] = {
            id = eid,
            birth = world[eid].animation_birth,
        }
        world[eid].anim_clips = all_clips
        local animations = world[eid].animation
        local parentNode = hierarchy:get_node(world[eid].parent)
        for key, anim in pairs(animations) do
            ozz_anims[eid][key] = {
                name = key,
                duration = anim._handle:duration(),
                key_event = from_runtime_event(world[eid].keyframe_events and world[eid].keyframe_events[key] or {}),
                clips = {},
                anim_obj = anim
            }
            animation_list[#animation_list + 1] = key
            --
            if not anim_group_eid[anim] then
                anim_group_eid[anim] = {}
            end
            
            for _, child in ipairs(parentNode.children) do
                local handle = world[child.eid].animation
                if handle and handle._handle == animations._handle then
                    if not find_index(anim_group_eid[anim], child.eid)  then
                        anim_group_eid[anim][#anim_group_eid[anim] + 1] = child.eid
                    end
                end
            end
        end
        table.sort(animation_list)
        set_current_anim(ozz_anims[eid].birth)
        joint_list = {
            {
                index = 0,
                name = "None",
                children = {}
            }
        }
        joints[eid] = {root = nil, joint_map = {}}
        local ske = world[eid].skeleton._handle
        local function construct(current_joints, ske, joint_idx)
            if current_joints.joint_map[joint_idx] then
                return current_joints.joint_map[joint_idx]
            end
            local new_joint = {
                index = joint_idx,
                name = ske:joint_name(joint_idx),
                children = {}
            }
            current_joints.joint_map[joint_idx] = new_joint
            local parent_idx = ske:parent(joint_idx)
            if parent_idx > 0 then
                new_joint.parent = current_joints.joint_map[parent_idx] or construct(current_joints, ske, ske:parent(parent_idx))
                table.insert(current_joints.joint_map[parent_idx].children, new_joint)
            else
                current_joints.root = new_joint
            end
        end
        for i=1, #ske do
            construct(joints[eid], ske, i)
        end
        local function setup_joint_list(joint)
            joint_list[#joint_list + 1] = joint
            for _, child_joint in ipairs(joint.children) do
                setup_joint_list(child_joint)
            end
        end
        setup_joint_list(joints[eid].root)
        world[eid].joint_list = joint_list
        hierarchy:update_slot_list()
    end
end

function m.add_animation(anim_name)

end

function m.get_current_joint()
    return current_joint and current_joint.index or 0
end

return function(w, am)
    world = w
    icons = require "common.icons"(am)
    iani = world:interface "ant.animation|animation"
    ies = world:interface "ant.scene|ientity_state"
    iom = world:interface "ant.objcontroller|obj_motion"
    prefab_mgr = require "prefab_manager"(world)
    gizmo = require "gizmo.gizmo"(world)
    return m
end