local ecs = ...
local world = ecs.world
local w = world.w

local iani      = ecs.import.interface "ant.animation|animation"
local ies       = ecs.import.interface "ant.scene|ientity_state"
local iom       = ecs.import.interface "ant.objcontroller|obj_motion"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local prefab_mgr = ecs.require "prefab_manager"
local gizmo     = ecs.require "gizmo.gizmo"
local asset_mgr = import_package "ant.asset"
local icons     = require "common.icons"(asset_mgr)
local logger    = require "widget.log"
local imgui     = require "imgui"
local math3d    = require "math3d"
local hierarchy = require "hierarchy_edit"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local utils     = require "common.utils"
local vfs       = require "vfs"
local access    = require "vfs.repoaccess"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local datalist  = require "datalist"
local rc        = import_package "ant.compile_resource"
local global_data = require "common.global_data"

local m = {}
local edit_anims = {}
local current_e
local imgui_message
local current_anim
local sample_ratio = 50.0

local anim_state = {
    duration = 0,
    selected_frame = -1,
    current_frame = 0,
    is_playing = false,
    anim_name = "",
    key_event = {},
    event_dirty = 0,
    clip_range_dirty = 0,
    selected_clip_index = 0,
    current_event_list = {}
}

local ui_loop = {false}

local event_type = {
    "Effect", "Sound", "Collision", "Message", "Move"
}
local joint_list = {

}
local joints = {}

local current_joint
local current_event
local current_collider
local current_clip
local anim_group_eid = {}
local anim_clips = {}
local all_clips = {}
local all_groups = {}
local all_collision = {}

local clip_index = 0
local group_index = 0

local function find_index(t, item)
    for i, c in ipairs(t) do
        if c == item then
            return i
        end
    end
end

local function get_runtime_animations(e)
    w:sync("animation:in", e)
    return e.animation
end

local function get_anim_group_eid(eid, name)
    local anims = get_runtime_animations(eid)
    return anim_group_eid[anims[name]]
end

local function anim_group_set_clips(eid, clips)
    local group_eid = get_anim_group_eid(eid, current_anim.name)
    if not group_eid then return end
    for _, anim_eid in ipairs(group_eid) do
        iani.set_clips(anim_eid, clips)
    end
end
local function anim_group_set_time(e, t)
    local group_e = get_anim_group_eid(e, current_anim.name)
    if not group_e then return end
    for _, anim_e in ipairs(group_e) do
        iani.set_time(anim_e, t)
    end
end

local function anim_group_stop_effect(eid)
    local group_eid = get_anim_group_eid(eid, current_anim.name)
    if not group_eid then return end
    for _, anim_eid in ipairs(group_eid) do
        iani.stop_effect(anim_eid)
    end
end

local function anim_play(e, anim_state, play)
    local group_e = get_anim_group_eid(e, current_anim.name)
    if not group_e then return end
    for _, anim_e in ipairs(group_e) do
        iom.set_position(hierarchy:get_node(hierarchy:get_node(anim_e).parent).parent, {0.0,0.0,0.0})
        play(anim_e, anim_state)
    end
end

local function anim_group_set_loop(eid, ...)
    local group_eid = get_anim_group_eid(eid, current_anim.name)
    if not group_eid then return end
    for _, anim_eid in ipairs(group_eid) do
        iani.set_loop(anim_eid, ...)
    end
end

local function anim_group_delete(eid, anim_name)
    local group_eid = get_anim_group_eid(eid, anim_name)
    if not group_eid then return end
    for _, anim_eid in ipairs(group_eid) do
        local template = hierarchy:get_template(anim_eid)
        local animation_map = template.template.data.animation
        animation_map[anim_name] = nil
        local anims = get_runtime_animations(anim_eid)
        anims[anim_name] = nil
        if template.template.data.animation_birth == anim_name then
            template.template.data.animation_birth = next(animation_map) or ""
        end
        if edit_anims[anim_eid] then
            local name_idx = find_index(edit_anims[anim_eid].name_list, anim_name)
            table.remove(edit_anims[anim_eid].name_list, name_idx)
        end
    end
end

local function anim_group_pause(eid, p)
    local group_eid = get_anim_group_eid(eid, current_anim.name)
    for _, anim_eid in ipairs(group_eid) do
        iani.pause(anim_eid, p)
    end
end

local widget_utils  = require "widget.utils"

local function set_current_anim(anim_name)
    if not edit_anims[current_e][anim_name] then
        local msg = anim_name .. " not exist."
        logger.error({tag = "Editor", message = msg})
        widget_utils.message_box({title = "AnimationError", info = msg})
        return false
    end

    if current_anim and current_anim.collider then
        for _, col in ipairs(current_anim.collider) do
            if col.collider then
                ies.set_state(col.eid, "visible", false)
            end
        end
    end
    current_anim = edit_anims[current_e][anim_name]
    if current_anim.collider then
        for _, col in ipairs(current_anim.collider) do
            if col.collider then
                ies.set_state(col.eid, "visible", true)
            end
        end
    end
    anim_state.anim_name = current_anim.name
    anim_state.key_event = current_clip and current_clip.key_event or {}
    anim_state.duration = current_anim.duration
    current_collider = nil
    current_event = nil
    
    anim_play(current_e, {name = anim_name, loop = ui_loop[1], manual = false}, iani.play)
    anim_group_set_time(current_e, 0)
    anim_group_pause(current_e, not anim_state.is_playing)
    -- if not iani.is_playing(current_e) then
    --     anim_group_pause(current_e, false)
    -- end
    return true
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
    for _, ev in ipairs(runtime_event) do
        for _, e in ipairs(ev.event_list) do
            e.name_ui = {text = e.name}
            if e.event_type == "Sound" or e.event_type == "Effect" then
                e.asset_path_ui = {text = e.asset_path}
                if e.link_info and e.link_info.slot_name ~= '' then
                    e.link_info.slot_eid = hierarchy.slot_list[e.link_info.slot_name]
                end
                if e.event_type == "Effect" then
                    e.breakable = e.breakable or false
                    e.life_time = e.life_time or 2
                    e.breakable_ui = {e.breakable}
                    e.life_time_ui = {e.life_time, speed = 0.02, min = 0, max = 100}
                end
            elseif e.event_type == "Move" then
                e.move = e.move or {0.0, 0.0, 0.0}
                e.move_ui = e.move and {e.move[1], e.move[2], e.move[3]} or {0.0, 0.0, 0.0}
            elseif e.event_type == "Collision" then
                e.collision.tid = e.collision.tid or -1
                e.collision.tid_ui = {e.collision.tid}
                e.collision.enable_ui = {e.collision.enable}
                e.collision.shape_type = e.collision.shape_type
            elseif e.event_type == "Message" then
                e.msg_content = e.msg_content or ""
                e.msg_content_ui = {text = e.msg_content}
            end
        end
        key_event[tostring(math.floor(ev.time * sample_ratio))] = ev.event_list
    end
    return key_event
end

local function from_runtime_clip(runtime_clip)
    all_clips = {}
    all_groups = {}
    for _, clip in ipairs(runtime_clip) do
        if clip.range then
            local start_frame = math.floor(clip.range[1] * sample_ratio)
            local end_frame = math.floor(clip.range[2] * sample_ratio)
            local new_clip = {
                anim_name = clip.anim_name,
                name = clip.name,
                speed = clip.speed or 1.0,
                range = {start_frame, end_frame},
                key_event = from_runtime_event(clip.key_event),
                name_ui = {text = clip.name, flags = imgui.flags.InputText{"EnterReturnsTrue"}},
                range_ui = {start_frame, end_frame, speed = 1},
                speed_ui = {clip.speed or 1.0, speed = 0.02, min = 0.01, max = 100}
            }
            local clips = anim_clips[clip.anim_name] or {}
            clips[#clips + 1] = new_clip
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
                group = true,
                clips = subclips,
                name_ui = {text = clip.name, flags = imgui.flags.InputText{"EnterReturnsTrue"}}
            }
        end
    end
    table.sort(all_groups, function(a, b) return string.lower(tostring(a.name)) < string.lower(tostring(b.name)) end)
    table.sort(all_clips, function(a, b) return string.lower(tostring(a.name)) < string.lower(tostring(b.name)) end)
    clip_index = #all_clips
    group_index = #all_groups
end

local function get_runtime_clips()
    if not current_e then return end
    w:sync("_animation:in", current_e)
    return current_e._animation.anim_clips
end

local function get_runtime_events()
    if not current_clip then return end;
    return current_clip.key_event
end

local function to_runtime_group(runtime_clips, group)
    local groupclips = {}
    for _, clip in ipairs(group.clips) do
        groupclips[#groupclips + 1] = find_index(runtime_clips, clip)
    end
    return {name = group.name, group = true, subclips = groupclips}
end

local function do_to_runtime_event(evs)
    local list = {}
    for _, ev in ipairs(evs) do
        local col_eid = ev.collision and ev.collision.col_eid or -1
        list[#list + 1] = {
            event_type = ev.event_type,
            name = ev.name,
            asset_path = ev.asset_path,
            breakable = ev.breakable,
            life_time = ev.life_time,
            move = ev.move,
            msg_content = ev.msg_content,
            link_info = ev.link_info and {slot_name = ev.link_info.slot_name, slot_eid = ev.link_info.slot_eid and (ev.link_info.slot_eid > 0 and ev.link_info.slot_eid or nil) or nil },
            collision = (col_eid ~= -1) and {
                col_eid = col_eid,
                name = world[col_eid].name,
                shape_type = ev.collision.shape_type,
                position = ev.collision.position,
                size = ev.collision.size,
                enable = ev.collision.enable,
                tid = ev.collision.tid,
            } or nil
        }
    end
    return list
end

local function to_runtime_event(key_event)
    local temp = {}
    for key, value in pairs(key_event) do
        if #value > 0 then
            temp[#temp + 1] = tonumber(key)
        end
    end
    table.sort(temp, function(a, b) return a < b end)
    local event = {}
    for i, frame_idx in ipairs(temp) do
        event[#event + 1] = {
            time = frame_idx / sample_ratio,
            event_list = do_to_runtime_event(key_event[tostring(frame_idx)])
        }
    end
    return event
    --runtime_event.collider = current_clip.collider
end

local function to_runtime_clip()
    local runtime_clips = {}
    for _, clip in ipairs(all_clips) do
        if clip.range[1] >= 0 and clip.range[2] >= clip.range[1] then
            runtime_clips[#runtime_clips + 1] = {
                anim_name = clip.anim_name,
                name = clip.name,
                range = {clip.range[1] / sample_ratio, clip.range[2] / sample_ratio},
                speed = clip.speed or 1.0,
                key_event = to_runtime_event(clip.key_event)
            }
        end
    end
    for _, group in ipairs(all_groups) do
        runtime_clips[#runtime_clips + 1] = to_runtime_group(all_clips, group)
    end
    if #runtime_clips < 1  then return end
    if current_e then
        anim_group_set_clips(current_e, runtime_clips)
    end
end

local function set_event_dirty(num)
    anim_state.event_dirty = num
    if num ~= 0 then
        to_runtime_clip()
    end
end

local event_id = 1
local function add_event(et)
    if not current_clip then return end
    event_id = event_id + 1
    local event_name = et..tostring(event_id)
    local new_event = {
        event_type = et,
        name = event_name,
        asset_path = (et == "Effect" or et == "Sound") and "" or nil,
        link_info = (et == "Effect") and {
            slot_name = "",
            slot_eid = nil,
        } or nil,
        breakable = (et == "Effect") and false or nil,
        breakable_ui = (et == "Effect") and {false} or nil,
        life_time = (et == "Effect") and 2 or nil,
        life_time_ui = (et == "Effect") and { 2, speed = 0.02, min = 0, max = 100} or nil,
        move = (et == "Move") and {0.0, 0.0, 0.0} or nil,
        move_ui = (et == "Move") and {0.0, 0.0, 0.0} or nil,
        name_ui = {text = event_name},
        msg_content = (et == "Message") and "" or nil,
        msg_content_ui = (et == "Message") and {text = ""} or nil,
        asset_path_ui = (et == "Effect" or et == "Sound") and {text = ""} or nil,
        collision = (et == "Collision") and {
            tid = -1,
            tid_ui = {-1},
            col_eid = -1,
            shape_type = "None",
            enable = true,
            enable_ui = {true}
        } or nil
    }
    current_event = new_event
    local event_list = anim_state.current_event_list
    event_list[#event_list + 1] = new_event
    set_event_dirty(1)
end

local function delete_collider(collider)
    if not collider then return end
    local event_dirty
    for _, events in pairs(current_clip.key_event) do
        for i = #events, 1, -1 do
            if events[i] == collider then
                table.remove(events, i)
                event_dirty = true
            end
        end
    end
    for i = #current_clip.collider, 1, -1 do
        if current_clip.collider[i] == collider then
            table.remove(current_clip.collider, i)
        end
    end
    current_collider = nil
    if event_dirty then
        set_event_dirty(-1)
    else
        local runtime_event = get_runtime_events()
        runtime_event.collider = current_clip.collider
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
    current_clip.key_event[tostring(anim_state.selected_frame)] = {}
    anim_state.current_event_list = current_clip.key_event[tostring(anim_state.selected_frame)]
    set_event_dirty(1)
end

local shape_type = {
    "sphere","box"
}

local function show_events()
    if anim_state.selected_frame >= 0 and current_clip then
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
                if current_event.collision and current_event.collision.col_eid and current_event.collision.col_eid ~= -1 then
                    gizmo:set_target(current_event.collision.col_eid)
                    world:pub {"UpdateAABB", current_event.collision.col_eid}
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

local function do_record(collision, eid)
    w:sync("collider?in", eid)
    if not eid.collider then
        return
    end
    local tp = math3d.totable(iom.get_position(eid))
    collision.position = {tp[1], tp[2], tp[3]}
    local scale = math3d.totable(iom.get_scale(eid))
    local factor = eid.collider.sphere and 100 or 200
    collision.size = {scale[1] / factor, scale[2] / factor, scale[3] / factor}
end

local function show_current_event()
    if not current_event then return end
    imgui.widget.PropertyLabel("EventType")
    imgui.widget.Text(current_event.event_type)

    local dirty
    imgui.widget.PropertyLabel("EventName")
    if imgui.widget.InputText("##EventName", current_event.name_ui) then
        current_event.name = tostring(current_event.name_ui.text)
        dirty = true
    end
    
    if current_event.event_type == "Collision" then
        local collision = current_event.collision
        local collider_list = hierarchy.collider_list
        if collider_list and collision then
            imgui.widget.PropertyLabel("Collider")
            local col_name = "None"
            if collision.col_eid and collision.col_eid ~= -1 and world[collision.col_eid] then
                col_name = world[collision.col_eid].name
            end
            if imgui.widget.BeginCombo("##Collider", {col_name, flags = imgui.flags.Combo {}}) then
                for name, eid in pairs(collider_list) do
                    if imgui.widget.Selectable(name, col_name == name) then
                        collision.col_eid = eid
                        if eid == -1 then
                            collision.shape_type = "None"
                        else
                            w:sync("collider:in", eid)
                            collision.shape_type = eid.collider.sphere and "sphere" or "box"
                            do_record(collision, eid)
                        end
                        dirty = true
                    end
                end
                imgui.widget.EndCombo()
            end
        end
        imgui.widget.PropertyLabel("Enable")
        if imgui.widget.Checkbox("##Enable", collision.enable_ui) then
            collision.enable = collision.enable_ui[1]
            dirty = true
        end
        imgui.widget.PropertyLabel("TID")
        if imgui.widget.DragInt("##TID", collision.tid_ui) then
            collision.tid = collision.tid_ui[1]
            dirty = true
        end
    elseif current_event.event_type == "Sound" then
        if imgui.widget.Button("SelectSound") then
        end
        imgui.widget.Text("SoundPath : ")
    elseif current_event.event_type == "Effect" then
        if imgui.widget.Button("SelectEffect") then
            local path = uiutils.get_open_file_path("Prefab", "prefab")
            if path then
                local lfs         = require "filesystem.local"
                local rp = lfs.relative(lfs.path(path), global_data.project_root)
                local path = (global_data.package_path and global_data.package_path or global_data.editor_package_path) .. tostring(rp)
                current_event.asset_path_ui.text = path
                current_event.asset_path = path
                dirty = true
            end
        end
        imgui.widget.PropertyLabel("EffectPath")
        imgui.widget.InputText("##EffectPath", current_event.asset_path_ui)
        local slot_list = hierarchy.slot_list
        if slot_list then
            imgui.widget.PropertyLabel("LinkSlot")
            if imgui.widget.BeginCombo("##LinkSlot", {current_event.link_info.slot_name, flags = imgui.flags.Combo {}}) then
                for name, eid in pairs(slot_list) do
                    if imgui.widget.Selectable(name, current_event.link_info.slot_name == name) then
                        current_event.link_info.slot_name = name
                        current_event.link_info.slot_eid = eid
                        dirty = true
                    end
                end
                imgui.widget.EndCombo()
            end
        end
        imgui.widget.PropertyLabel("Breakable")
        if imgui.widget.Checkbox("##Breakable", current_event.breakable_ui) then
            current_event.breakable = current_event.breakable_ui[1]
            dirty = true
        end
        imgui.widget.PropertyLabel("LifeTime")
        if imgui.widget.DragFloat("##LifeTime", current_event.life_time_ui) then
            current_event.life_time = current_event.life_time_ui[1]
            dirty = true
        end
    elseif current_event.event_type == "Move" then
        imgui.widget.PropertyLabel("Move")
        if imgui.widget.DragFloat("##Move", current_event.move_ui) then
            current_event.move = {current_event.move_ui[1], current_event.move_ui[2], current_event.move_ui[3]}
            dirty = true
        end
    elseif current_event.event_type == "Message" then
        imgui.widget.PropertyLabel("Content")
        if imgui.widget.InputText("##Content", current_event.msg_content_ui) then
            current_event.msg_content = tostring(current_event.msg_content_ui.text)
            dirty = true
        end
    end
    if dirty then
        set_event_dirty(1)
    end
end

local function set_clips_dirty(update)
    anim_state.clip_range_dirty = 1
    if update then
        to_runtime_clip()
    end
end

function m.on_remove_entity(eid)
    local dirty = false
    for _, clip in ipairs(all_clips) do
        if clip.key_event then
            for _, ke in pairs(clip.key_event) do
                for _, e in ipairs(ke) do
                    if e.collision and e.collision.col_eid and e.collision.col_eid == eid then
                        e.collision.col_eid = -1
                        e.collision.shape_type = "None"
                        e.collision.position = nil
                        e.collision.size = nil
                        e.collision.enable = false
                        dirty = true
                    end
                end
            end
        end
    end
    if dirty then
        set_event_dirty(-1)
    end
end

function m.record_collision(eid)
    for idx, ke in ipairs(anim_state.current_event_list) do
        if ke.collision and ke.collision.col_eid == eid then
            do_record(ke.collision, eid)
        end
    end
end

local function update_collision()
    for idx, ke in ipairs(anim_state.current_event_list) do
        if ke.collision and ke.collision.col_eid and ke.collision.col_eid ~= -1 then
            local eid = ke.collision.col_eid
            iom.set_position(eid, ke.collision.position)
            w:sync("collider?in", eid)
            local factor = eid.collider.sphere and 100 or 200
            iom.set_scale(eid, {ke.collision.size[1] * factor, ke.collision.size[2] * factor, ke.collision.size[3] * factor})
            if eid == gizmo.target_eid then
                gizmo:update()
                world:pub {"UpdateAABB", eid}
            end
        end
    end
end

local function on_move_keyframe(frame_idx, move_type)
    if not frame_idx or anim_state.selected_frame == frame_idx then return end
    local old_selected_frame = anim_state.selected_frame
    anim_state.selected_frame = frame_idx
    if not current_clip or not current_clip.key_event then return end
    local newkey = tostring(anim_state.selected_frame)
    if move_type == 0 then
        local oldkey = tostring(old_selected_frame)
        current_clip.key_event[newkey] = current_clip.key_event[oldkey]
        current_clip.key_event[oldkey] = {}
        to_runtime_clip()
    else
        if not current_clip.key_event[newkey] then
            current_clip.key_event[newkey] = {}
        end
        anim_state.current_event_list = current_clip.key_event[newkey]
        update_collision()
        current_event = nil
    end
end
local function min_max_range_value(clip_index)
    return 0, math.ceil(current_anim.duration * sample_ratio) - 1
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


local function get_clips_filename()
    local prefab_filename = prefab_mgr:get_current_filename()
    return string.sub(prefab_filename, 1, -8) .. ".clips"
end

function m.save_clip(path)
    to_runtime_clip()
    local clips = get_runtime_clips()
    if not clips then return end
    
    local clip_filename = path
    if not clip_filename then
        clip_filename = get_clips_filename()
    end
    
    local copy_clips = utils.deep_copy(clips)
    for _, clip in ipairs(copy_clips) do
        if clip.key_event then
            for _, key_ev in ipairs(clip.key_event) do
                for _, ev in ipairs(key_ev.event_list) do
                    if ev.effect then
                        world:prefab_event(ev.effect, "remove", "*")
                        ev.effect = nil
                    end
                    if ev.link_info and ev.link_info.slot_eid then
                        ev.link_info.slot_eid = nil
                    end
                    if ev.collision and ev.collision.col_eid then
                        if ev.collision.col_eid ~= -1 then
                            local rc = imaterial.get_property(ev.collision.col_eid, "u_color")
                            local color = math3d.totable(rc.value)
                            ev.collision.color = {color[1],color[2],color[3],color[4]}
                            ev.collision.tag = world[ev.collision.col_eid].tag
                        end
                        ev.collision.col_eid = nil
                    end

                end
            end
        end
    end
    utils.write_file(clip_filename, stringify(copy_clips))
    copy_clips.slot_list = {}
    for k, v in pairs(hierarchy.slot_list) do
        if v > 0 then
            local ts = math3d.totable(iom.get_scale(v))
            local tr = math3d.totable(iom.get_rotation(v))
            local tp = math3d.totable(iom.get_position(v))
            copy_clips.slot_list[#copy_clips.slot_list + 1] = {tag = k, name = world[v].name, scale = {ts[1], ts[2], ts[3]}, rotate = {tr[1], tr[2], tr[3], tr[4]}, position = {tp[1], tp[2], tp[3]}}
        end
    end
    utils.write_file(string.sub(clip_filename, 1, -7) .. ".lua", "return " .. utils.table_to_string(copy_clips))
end

local function set_current_clip(clip)
    if current_clip == clip then return end
    
    anim_group_stop_effect(current_e)

    if clip then
        if not set_current_anim(clip.anim_name) then
            return
        end
        anim_state.selected_clip_index = find_index(current_anim.clips, clip)
        clip.name_ui.text = clip.name
    end
    current_clip = clip
    anim_state.current_event_list = {}
    current_event = nil
    anim_state.selected_frame = -1
end

local function show_clips()
    imgui.widget.PropertyLabel(" ")
    if imgui.widget.Button("NewClip") then
        local key = "Clip" .. clip_index
        clip_index = clip_index + 1
        local new_clip = {
            anim_name = current_anim.name,
            name = key,
            range = {-1, -1},
            speed = 1.0,
            key_event = {},
            name_ui = {text = key, flags = imgui.flags.InputText{"EnterReturnsTrue"}},
            speed_ui = {1.0, speed = 0.02, min = 0.01, max = 100},
            range_ui = {-1, -1, speed = 1}
        }
        current_anim.clips[#current_anim.clips + 1] = new_clip
        table.sort(current_anim.clips, function(a, b) return a.range[2] < b.range[1] end)
        all_clips[#all_clips+1] = new_clip
        --table.sort(all_clips, function(a, b) return a.range[2] < b.range[1] end)
        table.sort(all_clips, function(a, b) return string.lower(tostring(a.name)) < string.lower(tostring(b.name)) end)
        set_current_clip(new_clip)
        set_clips_dirty(true)
    end
    local delete_index
    local anim_name
    for i, cs in ipairs(all_clips) do
        if imgui.widget.Selectable(cs.name, current_clip and (current_clip.name == cs.name), 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
            set_current_clip(cs)
            if imgui.util.IsMouseDoubleClicked(0) then
                anim_play(current_e, {name = cs.name, loop = ui_loop[1], manual = false}, iani.play_clip)
                anim_group_set_loop(current_e, ui_loop[1])
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
        set_current_clip(nil)
        set_clips_dirty(true)
    end
end

local current_group

local function show_groups()
    imgui.widget.PropertyLabel(" ")
    if imgui.widget.Button("NewGroup") then
        local key = "Group" .. group_index
        group_index = group_index + 1
        all_groups[#all_groups + 1] = {
            name = key,
            group = true,
            name_ui = {text = key, flags = imgui.flags.InputText{"EnterReturnsTrue"}},
            clips ={}
        }
        table.sort(all_groups, function(a, b) return string.lower(tostring(a.name)) < string.lower(tostring(b.name)) end)
        set_clips_dirty(true)
    end
    local delete_group
    for i, gp in ipairs(all_groups) do
        if imgui.widget.Selectable(gp.name, current_group and (current_group.name == gp.name), 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
            gp.name_ui.text = gp.name
            current_group = gp
            if imgui.util.IsMouseDoubleClicked(0) then
                anim_play(current_e, {name = gp.name, loop = ui_loop[1], manual = false}, iani.play_group)
                anim_group_set_loop(current_e, ui_loop[1])
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

local function clip_exist(name)
    for _, v in ipairs(all_clips) do
        if v.name == name then
            return true
        end
    end
end
local function group_exist(name)
    for _, v in ipairs(all_groups) do
        if v.name == name then
            return true
        end
    end
end
local function show_current_clip()
    if not current_clip then return end
    imgui.widget.PropertyLabel("AnimName")
    imgui.widget.Text(current_clip.anim_name)
    imgui.widget.PropertyLabel("ClipName")
    if imgui.widget.InputText("##ClipName", current_clip.name_ui) then
        local new_name = tostring(current_clip.name_ui.text)
        if clip_exist(new_name) then
            widget_utils.message_box({title = "NameError", info = "clip " .. new_name .. " existed!"})
            current_clip.name_ui.text = current_clip.name
        else
            current_clip.name = new_name
            set_clips_dirty(true)
        end
    end

    imgui.widget.PropertyLabel("Speed")
    if imgui.widget.DragFloat("##Speed", current_clip.speed_ui) then
        current_clip.speed = current_clip.speed_ui[1]
        set_clips_dirty(true)
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
        local new_name = tostring(current_group.name_ui.text)
        if group_exist(new_name) then
            widget_utils.message_box({title = "NameError", info = "group " .. new_name .. " existed!"})
            current_group.name_ui.text = current_group.name
        else
            current_group.name = new_name
            set_clips_dirty(true)
        end
    end
    if imgui.widget.Button("AddClip") then
        imgui.windows.OpenPopup("AddClipPop")
    end
    
    if imgui.windows.BeginPopup("AddClipPop") then
        for _, clip in ipairs(all_clips) do
            if imgui.widget.MenuItem(clip.name) then
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
            set_current_clip(cs)
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

function m.clear()
    current_e = nil
    current_anim = nil
    all_clips = {}
    all_groups = {}
    anim_group_eid = {}
    current_collider = nil
    current_event = nil
    current_joint = nil
    current_clip = nil
end

local anim_name = ""
local ui_anim_name = {text = ""}
local anim_path = ""
local external_anim_list = {}
local current_external_anim
local anim_glb_path = ""

local function clear_add_animation_cache()
    anim_name = ""
    ui_anim_name.text = ""
    anim_glb_path = ""
    external_anim_list = {}
    current_external_anim = nil
end

function m.show()
    if not current_e then return end
    local reload = false
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    for _ in uiutils.imgui_windows("Animation", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
    --if imgui.windows.Begin ("Animation", imgui.flags.Window {'AlwaysAutoResize'}) then
        if edit_anims[current_e] then
            if current_anim then
                anim_state.is_playing = iani.is_playing(current_e)
                if anim_state.is_playing then
                    anim_state.current_frame = math.floor(iani.get_time(current_e) * sample_ratio)
                end
            end
            imgui.cursor.SameLine()
            local title = "Add Animation"
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
                imgui.widget.Text("Path : " .. anim_glb_path)
                imgui.cursor.SameLine()
                local origin_name
                if imgui.widget.Button("...") then
                    local glb_filename = uiutils.get_open_file_path("Animation", "glb")
                    if glb_filename then
                        external_anim_list = {}
                        current_external_anim = nil
                        local vfs = require "vfs"
                        anim_glb_path = "/" .. access.virtualpath(global_data.repo, fs.path(glb_filename))
                        rc.compile(anim_glb_path)
                        local external_path = rc.compile(anim_glb_path .. "|animations")
                        for path in fs.pairs(external_path) do
                            if path:equal_extension ".ozz" then
                                local filename = path:filename():string()
                                if filename ~= "skeleton.ozz" then
                                    external_anim_list[#external_anim_list + 1] = filename
                                end
                            end
                        end
                    end
                end
                if #external_anim_list > 0 then
                    imgui.cursor.Separator()
                    for _, external_anim in ipairs(external_anim_list) do
                        if imgui.widget.Selectable(external_anim, current_external_anim and (current_external_anim == external_anim), 0, 0, imgui.flags.Selectable {"DontClosePopups"}) then
                            current_external_anim = external_anim
                            anim_path = anim_glb_path .. "|animations/" .. external_anim
                            if #anim_name < 1 then
                                anim_name = fs.path(anim_path):stem():string()
                            end
                        end
                    end
                end
                imgui.cursor.Separator()
                if imgui.widget.Button("  OK  ") then
                    if #anim_name > 0 and #anim_path > 0 then
                        local update = true
                        local anims = get_runtime_animations(current_e)
                        if anims[anim_name] then
                            local confirm = {title = "Confirm", message = "animation ".. anim_name .. " exist, replace it ?"}
                            uiutils.confirm_dialog(confirm)
                            if confirm.answer and confirm.answer == 0 then
                                update = false
                            end
                        end
                        if update then
                            local group_eid = get_anim_group_eid(current_e, current_anim.name)
                            --TODO: set for group eid
                            for _, eid in ipairs(group_eid) do
                                local template = hierarchy:get_template(eid)
                                template.template.data.animation[anim_name] = anim_path
                                w:sync("animation:in", eid)
                                eid.animation[anim_name] = anim_path
                            end
                            --TODO:reload
                            reload = true
                        end
                    end
                    clear_add_animation_cache()
                    imgui.windows.CloseCurrentPopup()
                end
                imgui.cursor.SameLine()
                if imgui.widget.Button("Cancel") then
                    clear_add_animation_cache()
                    imgui.windows.CloseCurrentPopup()
                end
                imgui.windows.EndPopup()
            end

            imgui.cursor.SameLine()
            if imgui.widget.Button("Remove") then
                anim_group_delete(current_e, current_anim.name)
                local nextanim = edit_anims[current_e].name_list[1]
                if nextanim then
                    set_current_anim(nextanim)
                    set_current_clip(nil)
                end
                reload = true
            end
            imgui.cursor.SameLine()
            imgui.cursor.PushItemWidth(150)
            if imgui.widget.BeginCombo("##AnimationList", {current_anim.name, flags = imgui.flags.Combo {}}) then
                for _, name in ipairs(edit_anims[current_e].name_list) do
                    if imgui.widget.Selectable(name, current_anim.name == name) then
                        set_current_anim(name)
                        set_current_clip(nil)
                    end
                end
                imgui.widget.EndCombo()
            end
            imgui.cursor.PopItemWidth()
            imgui.cursor.SameLine()
            local icon = anim_state.is_playing and icons.ICON_PAUSE or icons.ICON_PLAY
            if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
                if anim_state.is_playing then
                    anim_group_pause(current_e, true)
                else
                    anim_play(current_e, {name = current_anim.name, loop = ui_loop[1], manual = false}, iani.play)
                end
            end
            imgui.cursor.SameLine()
            if imgui.widget.Checkbox("loop", ui_loop) then
                anim_group_set_loop(current_e, ui_loop[1])
            end
            if all_clips then
                imgui.cursor.SameLine()
                if imgui.widget.Button("SaveClip") then
                    m.save_clip()
                end
            end
            imgui.cursor.SameLine()
            local current_time = iani.get_time(current_e)
            imgui.widget.Text(string.format("Selected Frame: %d Time: %.2f(s) Current Frame: %d Time: %.2f/%.2f(s)", anim_state.selected_frame, anim_state.selected_frame / sample_ratio, math.floor(current_time * sample_ratio), current_time, anim_state.duration))
            imgui_message = {}
            imgui.widget.Sequencer(edit_anims[current_e], anim_state, imgui_message)
            -- clear dirty flag
            anim_state.clip_range_dirty = 0
            set_event_dirty(0)
            --
            local move_type
            local new_frame_idx
            local move_delta
            for k, v in pairs(imgui_message) do
                if k == "pause" then
                    anim_group_pause(current_e, true)
                    anim_state.current_frame = v
                    anim_group_set_time(current_e, v / sample_ratio)
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
                show_joints(joints[current_e].root)
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
    if reload then
        prefab_mgr:save_prefab()
        prefab_mgr:reload()
    end
end

local function construct_joints(e)
    joint_list = {{ index = 0, name = "None", children = {}}}
    joints[e] = {root = nil, joint_map = {}}
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
    
    w:sync("skeleton:in", e)
    local ske = e.skeleton._handle
    if not ske then return end
    for i=1, #ske do
        construct(joints[e], ske, i)
    end
    local function setup_joint_list(joint)
        joint_list[#joint_list + 1] = joint
        for _, child_joint in ipairs(joint.children) do
            setup_joint_list(child_joint)
        end
    end
    setup_joint_list(joints[e].root)
    e._animation.joint_list = joint_list
    hierarchy:update_slot_list(world)
end

function m.load_clips()
    if #all_clips == 0 then
        local clips_filename = get_clips_filename();
        if fs.exists(fs.path(clips_filename)) then
            local path = fs.path(clips_filename):localpath()
            local f = assert(fs.open(path))
            local data = f:read "a"
            f:close()
            local clips = datalist.parse(data)
            for _, clip in ipairs(clips) do
                if clip.key_event then
                    for _, ke in pairs(clip.key_event) do
                        for _, e in ipairs(ke.event_list) do
                            if e.collision and e.collision.shape_type ~= "None" then
                                if not hierarchy.collider_list or not hierarchy.collider_list[e.collision.name] then
                                    local eid = prefab_mgr:create("collider", {tag = e.collision.tag, type = e.collision.shape_type, define = utils.deep_copy(default_collider_define[e.collision.shape_type]), parent = prefab_mgr.root, add_to_hierarchy = true})
                                    eid.name = e.collision.name
                                    eid.tag = e.collision.tag
                                    w:sync("name:out", eid)
                                    w:sync("tag:out", eid)
                                    imaterial.set_property(eid, "u_color", e.collision.color or {1.0,0.5,0.5,0.8})
                                    hierarchy:update_collider_list(world)
                                end
                                e.collision.col_eid = hierarchy.collider_list[e.collision.name]
                                e.collision.name = nil
                            end
                        end
                    end
                end
            end
            hierarchy:update_slot_list(world)
            from_runtime_clip(clips)
            set_event_dirty(-1)
        end
    end
    to_runtime_clip()
end

local function construct_edit_animations(e)
    w:sync("animation_birth:in", e)
    if not e.scene then
        w:sync("scene:in", e)
    end
    edit_anims[e] = {
        id          = e.scene.id,
        name_list   = {},
        birth       = e.animation_birth,
    }
    local edit_anim = edit_anims[e]
    local animations = get_runtime_animations(e)
    local parentNode = hierarchy:get_node(hierarchy:get_node(e).parent)
    for key, anim in pairs(animations) do
        if not anim_clips[key] then
            anim_clips[key] = {}
        end
        edit_anim[key] = {
            name = key,
            duration = anim._handle:duration(),
            clips = anim_clips[key]
        }
        edit_anim.name_list[#edit_anim.name_list + 1] = key
        if not anim_group_eid[anim] then
            anim_group_eid[anim] = {}
        end
        
        for _, child in ipairs(parentNode.children) do
            local handle = get_runtime_animations(child.eid)
            if handle and handle._handle == animations._handle then
                if not find_index(anim_group_eid[anim], child.eid)  then
                    anim_group_eid[anim][#anim_group_eid[anim] + 1] = child.eid
                end
            end
        end
    end
    table.sort(edit_anim.name_list)
    set_current_anim(edit_anim.birth)
    m.load_clips()
    construct_joints(e)
end

function m.bind(e)
    if not e then
        --current_e = e
        return
    end
    w:sync("animation?in", e)
    if not e.animation then
        return
    end
    if current_e ~= e then
        current_e = e
    end
    if not edit_anims[e] then
        construct_edit_animations(e)
    end
end

function m.get_current_joint()
    return current_joint and current_joint.index or 0
end

return m