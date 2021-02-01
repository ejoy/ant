local imgui     = require "imgui"
local math3d    = require "math3d"
local hierarchy = require "hierarchy"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local utils     = require "common.utils"
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

local function find_index(t, item)
    for i, c in ipairs(t) do
        if c == item then
            return i
        end
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
end


local function from_runtime_event(runtime_event)
    local key_event = {}
    if runtime_event.collider then
        local ske = world[current_eid].skeleton._handle
        for _, col in ipairs(runtime_event.collider) do
            col.hid_ui = {col.hid}
            col.name_ui = {text = col.name}
            if col.shape.type == "box" then
                col.halfsize_ui = {col.shape.define.size[1], col.shape.define.size[2], col.shape.define.size[3], speed = 0.01}
            elseif col.shape.type == "sphere" or shape.type == "capsule" then
                col.radius_ui = {col.shape.define.radius, speed = 0.01}
                if col.shape.type == "capsule" then
                    col.height_ui = {col.shape.define.height, speed = 0.01}
                end
            end
        end
        current_anim.collider = runtime_event.collider
    end
    if runtime_event.event then
        for _, ev in ipairs(runtime_event.event) do
            for _, e in ipairs(ev.event_list) do
                e.name_ui = {text = e.name}
                if e.event_type == "Sound" or e.event_type == "Effect" then
                    e.rid_ui = {e.rid}
                    e.asset_path_ui = {text = e.asset_path}
                elseif e.event_type == "Collision" then
                    e.collision.enable_ui = {e.collision.enable}
                    e.collision.offset_ui = {
                        position = {e.collision.offset.position[1],e.collision.offset.position[2],e.collision.offset.position[3],speed = 0.01},
                        rotate = {e.collision.offset.rotate[1],e.collision.offset.rotate[2],e.collision.offset.rotate[3],speed = 0.01}
                    }
                end
            end
            key_event[tostring(math.floor(ev.time * sample_ratio))] = ev.event_list
        end
    end
    return key_event
end

local function from_runtime_clip(runtime_clip)
    local clips = {}
    local groups = {}
    for _, clip in ipairs(runtime_clip) do
        if clip.range then
            local start_frame = math.floor(clip.range[1] * sample_ratio)
            local end_frame = math.floor(clip.range[2] * sample_ratio)
            clips[#clips + 1] = {
                name = clip.name,
                range = {start_frame, end_frame},
                name_ui = {text = clip.name},
                range_ui = {start_frame, end_frame, speed = 1}
            }
        end
        table.sort(clips, function(a, b) return a.range[2] < b.range[1] end)
    end
    for _, clip in ipairs(runtime_clip) do
        if not clip.range then
            local subclips = {}
            for _, v in ipairs(clip.subclips) do
                subclips[#subclips + 1] = clips[v]
            end
            groups[#groups + 1] = {
                name = clip.name,
                clips = subclips,
                name_ui = {text = clip.name}
            }
        end
    end
    return clips, groups
end

local function get_runtime_clips()
    if not world[current_eid].anim_clips or not world[current_eid].anim_clips[current_anim_name] then
        iani.set_clips(current_eid, current_anim_name, {})
    end
    return world[current_eid].anim_clips[current_anim_name]
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
    for _, clip in ipairs(current_anim.clips) do
        if clip.range[1] > 0 and clip.range[2] > 0 and clip.range[2] > clip.range[1] then
            runtime_clips[#runtime_clips + 1] = {name = clip.name, range = {clip.range[1] / sample_ratio, clip.range[2] / sample_ratio}}
        end
    end
    if current_anim.groups then
        for _, group in ipairs(current_anim.groups) do
            runtime_clips[#runtime_clips + 1] = to_runtime_group(current_anim.clips, group)
        end
    end
    if #runtime_clips < 1  then return end
    iani.set_clips(current_eid, current_anim_name, runtime_clips)
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

local default_collider_define = {
    ["sphere"]  = {origin = {0, 0, 0, 1}, radius = 0.05},
    ["box"]     = {origin = {0, 0, 0, 1}, size = {0.05, 0.05, 0.05}},
    ["capsule"] = {origin = {0, 0, 0, 1}, height = 1.0, radius = 0.25}
}
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
            collider = current_collider,
            offset = {position = {0,0,0}, rotate = {0,0,0}},
            enable = false,
            enable_ui = {false},
            offset_ui = {position = {0,0,0,speed = 0.01}, rotate = {0,0,0,speed = 0.01}},
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
        eid = prefab_mgr:create("collider", shape),
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

    if current_event.event_type == "Collision" and current_anim.collider then
        local collision = current_event.collision
        imgui.widget.PropertyLabel("Collider")
        if imgui.widget.BeginCombo("##Collider", {collision.collider and collision.collider.name or "", flags = imgui.flags.Combo {}}) then
            for idx, col in ipairs(current_anim.collider) do
                if imgui.widget.Selectable(col.name, collision.collider and (collision.collider.name == col.name)) then
                    collision.collider = col
                    gizmo:set_target(col.eid)
                end
            end
            imgui.widget.EndCombo()
        end
        imgui.widget.PropertyLabel("Enable")
        if imgui.widget.Checkbox("##Enable", collision.enable_ui) then
            collision.enable = collision.enable_ui[1]
        end
        if collision.collider then
            if imgui.widget.TreeNode("Offset", imgui.flags.TreeNode { "DefaultOpen" }) then
                imgui.widget.PropertyLabel("Position")
                if imgui.widget.DragFloat("##Position", collision.offset_ui.position) then
                    collision.offset.position = {collision.offset_ui.position[1], collision.offset_ui.position[2], collision.offset_ui.position[3]}
                end
                imgui.widget.PropertyLabel("Rotate")
                if imgui.widget.DragFloat("##Rotate", collision.offset_ui.rotate) then
                    collision.offset.rotate = {collision.offset_ui.rotate[1], collision.offset_ui.rotate[2], collision.offset_ui.rotate[3]}
                end
                imgui.widget.TreePop()
            end
        end
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
        current_event = nil
    end
end
local function min_max_range_value(clip_index)
    return 0, math.floor(current_anim.duration * sample_ratio) - 1
end

local function on_move_clip(move_type, current_clip_index, move_delta)
    local clip
    if current_clip_index then
        clip = current_anim.clips[current_clip_index]
    end
    if not clip then return end
    local min_value, max_value = min_max_range_value(current_clip_index)
    if move_type == 1 then
        local new_value = clip.range[1] + move_delta
        --if new_value >= min_value and new_value < clip.range[2] then
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
            list[#list + 1] = {
                event_type = ev.event_type,
                name = ev.name,
                rid = ev.rid,
                collision = ev.collision and {
                    collider_index = find_index(current_anim.collider, ev.collision.collider) or 0,
                    offset = ev.collision.offset,
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
    local runtime_clip = get_runtime_clips()
    utils.write_file(filename, stringify(runtime_clip))
end

function m.on_collider_update(eid)
    if not current_event or not current_event.collision then return end
    if current_event.collision.collider.eid == eid then
        local pos = math3d.totable(iom.get_position(eid))
        local rot = math3d.totable(iom.get_rotation(eid))
        current_event.collision.offset.position = pos
        current_event.collision.offset.rotate = rot
        current_event.collision.offset_ui.position[1] = pos[1]
        current_event.collision.offset_ui.position[2] = pos[2]
        current_event.collision.offset_ui.position[3] = pos[3]
        current_event.collision.offset_ui.rotate[1] = rot[1]
        current_event.collision.offset_ui.rotate[2] = rot[2]
        current_event.collision.offset_ui.rotate[3] = rot[3]
    end
end

local clip_index = 0
local function show_clips()
    if imgui.widget.Button("NewClip") then
        if not current_anim.clips then
            current_anim.clips = {}
        end
        local key = "Clip" .. clip_index
        current_anim.clips[#current_anim.clips + 1] = {
            name = key,
            range = {-1, -1},
            name_ui = {text = key},
            range_ui = {-1, -1, speed = 1}
        }
        clip_index = clip_index + 1
        table.sort(current_anim.clips, function(a, b)
            return a.range[2] < b.range[1]
        end)
        set_clips_dirty(true)
    end
    
    if not current_anim.clips then return end

    local delete_clip
    for i, cs in ipairs(current_anim.clips) do
        if imgui.widget.Selectable(cs.name, current_clip and (current_clip.name == cs.name)) then
            current_clip = cs
        end
        if current_clip and (current_clip.name == cs.name) then
            if imgui.windows.BeginPopupContextItem(cs.name) then
                if imgui.widget.Selectable("Delete", false) then
                    delete_clip = i
                end
                imgui.windows.EndPopup()
            end
        end
    end
    if delete_clip then
        if current_anim.groups then
            for _, group in ipairs(current_anim.groups) do
                local found = find_index(group.clips, current_anim.clips[delete_clip])
                if found then
                    table.remove(group.clips, found)
                end
            end
        end
        table.remove(current_anim.clips, delete_clip)
        current_clip = nil
        set_clips_dirty(true)
    end
end

local current_group
local group_index = 0
local function show_groups()
    if imgui.widget.Button("NewGroup") then
        if not current_anim.groups then
            current_anim.groups = {}
        end
        local key = "Group" .. group_index
        current_anim.groups[#current_anim.groups + 1] = {
            name = key,
            name_ui = {text = key},
            clips ={}
        }
        group_index = group_index + 1
        set_clips_dirty(true)
    end
    if not current_anim.groups then return end
    local delete_group
    for i, gp in ipairs(current_anim.groups) do
        if imgui.widget.Selectable(gp.name, current_group and (current_group.name == gp.name)) then
            current_group = gp
            --iani.play(current_eid, current_anim_name, 0, to_runtime_group(get_runtime_clips(), gp))
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
        table.remove(current_anim.groups, delete_group)
        current_group = nil
        set_clips_dirty(true)
    end
end

local function show_current_clip()
    if not current_clip or not current_anim.clips then return end
    imgui.widget.PropertyLabel("Name")
    if imgui.widget.InputText("##Name", current_clip.name_ui) then
        current_clip.name = tostring(current_clip.name_ui.text)
    end
    imgui.widget.PropertyLabel("Range")
    local clip_index = find_index(current_anim.clips, current_clip)
    local min_value, max_value = min_max_range_value()
    if imgui.widget.DragInt("##Range", current_clip.range_ui) then
        if current_clip.range_ui[1] < min_value then
            current_clip.range_ui[1] = min_value
        elseif current_clip.range_ui[1] >= current_clip.range_ui[2] then
            current_clip.range_ui[1] = current_clip.range_ui[2]
        end
        if current_clip.range_ui[2] > max_value then
            current_clip.range_ui[2] = max_value
        elseif current_clip.range_ui[2] <= current_clip.range_ui[1] then
            current_clip.range_ui[2] = current_clip.range_ui[1]
        end
        current_clip.range = {current_clip.range_ui[1], current_clip.range_ui[2]}
        set_clips_dirty(true)
    end
end

local current_group_clip
local function show_current_group()
    if not current_group or not current_anim.groups then return end
    imgui.widget.PropertyLabel("Name")
    if imgui.widget.InputText("##Name", current_group.name_ui) then
        current_group.name = tostring(current_group.name_ui.text)
    end
    if imgui.widget.Button("AddClip") then
        imgui.windows.OpenPopup("AddClipPop")
    end
    
    local function is_valid_range(ct)
        return ct.range[1] >= 0 and ct.range[2] > 0 and ct.range[2] > ct.range[1]
    end

    if imgui.windows.BeginPopup("AddClipPop") then
        for _, ct in ipairs(current_anim.clips) do
            if is_valid_range(ct) and ct.range[1] >= 0 and not find_index(current_group.clips, ct) and imgui.widget.MenuItem(ct.name) then
                current_group.clips[#current_group.clips + 1] = ct
                table.sort(current_group.clips, function(a, b) return a.range[2] < b.range[1] end)
                set_clips_dirty(true)
            end
        end
        imgui.windows.EndPopup()
    end
    local delete_clip
    for i, cs in ipairs(current_group.clips) do
        if imgui.widget.Selectable(cs.name, current_group_clip and (current_group_clip.name == cs.name)) then
            current_group_clip = cs
        end
        if current_group_clip and (current_group_clip.name == cs.name) then
            if imgui.windows.BeginPopupContextItem(cs.name) then
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

function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    for _ in uiutils.imgui_windows("Animation", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
    --if imgui.windows.Begin ("Animation", imgui.flags.Window {'AlwaysAutoResize'}) then
        if current_eid and ozz_anims[current_eid] then
            if current_anim then
                anim_state.current_time = current_anim.ozz_anim:get_time()
                anim_state.is_playing = current_anim.ozz_anim:is_playing()
            end
            imgui.cursor.PushItemWidth(150)
            if imgui.widget.BeginCombo("##AnimationList", {current_anim_name, flags = imgui.flags.Combo {}}) then
                for _, name in ipairs(animation_list) do
                    if imgui.widget.Selectable(name, current_anim_name == name) then
                        set_current_anim(name)
                        --
                        iani.set_time(current_eid, 0)
                        local ozz_anim = current_anim.ozz_anim
                        if not ozz_anim:is_playing() then
                            ozz_anim:pause(false)
                        end
                        iani.play(current_eid, name, 0)
                        current_clip_name = "None"
                        current_clip = nil
                    end
                end
                imgui.widget.EndCombo()
            end
            imgui.cursor.SameLine()
            if imgui.widget.BeginCombo("##ClipList", {current_clip_name, flags = imgui.flags.Combo {}}) then
                local default = "None"
                if imgui.widget.Selectable(default, current_clip_name == default) then
                    current_clip_name = default
                    iani.play(current_eid, current_anim_name, 0)
                end
                if current_anim.clips then
                    for _, clip in ipairs(current_anim.clips) do
                        if imgui.widget.Selectable(clip.name, current_clip_name == clip.name) then
                            current_clip_name = clip.name
                            iani.play(current_eid, current_anim_name, 0, current_clip_name)
                        end
                    end
                    if current_anim.groups then
                        for _, group in ipairs(current_anim.groups) do
                            if imgui.widget.Selectable(group.name, current_clip_name == group.name) then
                                current_clip_name = group.name
                                iani.play(current_eid, current_anim_name, 0, current_clip_name)
                            end
                        end
                    end
                end
                imgui.widget.EndCombo()
            end
            imgui.cursor.PopItemWidth()
            imgui.cursor.SameLine()
            local icon = anim_state.is_playing and icons.ICON_PAUSE or icons.ICON_PLAY
            if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
                anim_state.is_playing = not anim_state.is_playing
                iani.pause(current_eid, not anim_state.is_playing)
            end
            imgui.cursor.SameLine()
            if imgui.widget.Button("LoadClip") then
                local path = widget_utils.get_open_file_path("Clip", ".clip")
                if path then
                    iani.set_clips(current_eid, current_anim_name, path)
                    current_clip_file = path
                    current_anim.clips, current_anim.groups = from_runtime_clip(get_runtime_clips())
                    set_clips_dirty(false)
                end
            end
            if current_anim.clips then
                imgui.cursor.SameLine()
                if imgui.widget.Button("SaveClip") then
                    save_clip(current_clip_file)
                end
            end
            imgui.cursor.SameLine()
            if imgui.widget.Button("LoadEvent") then
                local path = widget_utils.get_open_file_path("Event", ".event")
                if path then
                    iani.set_events(current_eid, current_anim_name, path)
                    current_event_file = path
                    current_anim.key_event = from_runtime_event(get_runtime_events())
                    for i, col in ipairs(current_anim.collider) do
                        col.eid = prefab_mgr:create("collider", col.shape)
                    end
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
            local current_clip_index
            local move_delta
            for k, v in pairs(imgui_message) do
                if k == "pause" then
                    current_anim.ozz_anim:pause(true)
                    current_anim.ozz_anim:set_time(v)
                elseif k == "selected_frame" then
                    new_frame_idx = v
                elseif k == "move_type" then
                    move_type = v
                elseif k == "current_clip_index" then
                    current_clip_index = v
                elseif k == "move_delta" then
                    move_delta = v
                end
            end
            on_move_keyframe(new_frame_idx, move_type)
            if move_type and move_type ~= 0 then
                on_move_clip(move_type, current_clip_index, move_delta)
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
            birth = world[eid].animation_birth
        }
        local animation = world[eid].animation
        for key, anim in pairs(animation) do
            ozz_anims[eid][key] = {
                name = key,
                duration = anim._handle:duration(),
                ozz_anim = anim._handle,
                key_event = from_runtime_event(world[eid].keyframe_events and world[eid].keyframe_events[key] or {})
            }
            animation_list[#animation_list + 1] = key
        end
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