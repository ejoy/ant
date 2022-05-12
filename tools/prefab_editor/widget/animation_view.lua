local ecs = ...
local world = ecs.world

local iaudio    = ecs.import.interface "ant.audio|audio_interface"
local iani      = ecs.import.interface "ant.animation|ianimation"
local ies       = ecs.import.interface "ant.scene|ifilter_state"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local skeleton_view = ecs.require "widget.skeleton_view"
local prefab_mgr = ecs.require "prefab_manager"
local gizmo     = ecs.require "gizmo.gizmo"
local asset_mgr = import_package "ant.asset"
local icons     = require "common.icons"(asset_mgr)
local logger    = require "widget.log"(asset_mgr)
local imgui     = require "imgui"
local math3d    = require "math3d"
local hierarchy = require "hierarchy_edit"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local joint_utils = require "widget.joint_utils"
local utils     = require "common.utils"
local access    = require "vfs.repoaccess"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local datalist  = require "datalist"
local global_data = require "common.global_data"

local m = {}
local edit_anims
local imgui_message
local current_anim
local sample_ratio = 50.0
local joint_map = {}
local joint_list = {}
local anim_state = {
    duration = 0,
    selected_frame = -1,
    current_frame = 0,
    is_playing = false,
    anim_name = "",
    key_event = {},
    event_dirty = 0,
    selected_clip_index = 0,
    current_event_list = {}
}

local ui_loop = {false}

local event_type = {
    "Effect", "Sound", "Collision", "Message", "Move"
}

local current_event
local current_clip
local anim_eid_group = {}
local anim_key_event = {}
local function find_index(t, item)
    for i, c in ipairs(t) do
        if c == item then
            return i
        end
    end
end

local function do_to_runtime_event(evs)
    local list = {}
    for _, ev in ipairs(evs) do
        local col_eid = ev.collision and ev.collision.col_eid or -1
        list[#list + 1] = {
            event_type = ev.event_type,
            name = ev.name,
            asset_path = ev.asset_path,
            sound_event = ev.sound_event,
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

local function to_runtime_event(ke)
    local temp = {}
    for key, value in pairs(ke) do
        if #value > 0 then
            temp[#temp + 1] = tonumber(key)
        end
    end
    table.sort(temp, function(a, b) return a < b end)
    local event = {}
    for i, frame_idx in ipairs(temp) do
        event[#event + 1] = {
            time = frame_idx / sample_ratio,
            event_list = do_to_runtime_event(ke[tostring(frame_idx)])
        }
    end
    return event
    --runtime_event.collider = current_clip.collider
end

local function get_runtime_animations(eid)
    return world:entity(eid).animation
end

local function get_anim_group_eid(eid, name)
    local anims = get_runtime_animations(eid)
    return anim_eid_group[anims[name]]
end

local function anim_group_set_time(eid, t)
    iani.set_time(eid, t)
end

local function anim_play(state, play)
    state.key_event = to_runtime_event(anim_key_event)
    for _, anim_e in ipairs(current_anim.eid_list) do
        iom.set_position(world:entity(hierarchy:get_node(hierarchy:get_node(anim_e).parent).parent), {0.0,0.0,0.0})
        play(anim_e, state)
    end
end

local function anim_group_set_loop(eid, ...)
    iani.set_loop(eid, ...)
end

local function anim_group_delete(anim_name)
    for _, anim_eid in ipairs(current_anim.eid_list) do
        local template = hierarchy:get_template(anim_eid)
        local animation_map = template.template.data.animation
        animation_map[anim_name] = nil
        local anims = get_runtime_animations(anim_eid)
        anims[anim_name] = nil
        if template.template.data.animation_birth == anim_name then
            template.template.data.animation_birth = next(animation_map) or ""
        end
    end
    local name_idx = find_index(edit_anims.name_list, anim_name)
    table.remove(edit_anims.name_list, name_idx)
end

local function anim_group_pause(eid, p)
    iani.pause(eid, p)
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
    local ke = {}
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
        ke[tostring(math.floor(ev.time * sample_ratio))] = ev.event_list
    end
    return ke
end

local function get_runtime_events()
    if not current_clip then return end;
    return current_clip.key_event
end

local function set_event_dirty(num)
    anim_state.event_dirty = num
end

local widget_utils  = require "widget.utils"

local function set_current_anim(anim_name)
    local anim = edit_anims[anim_name]
    if not anim then
        local msg = anim_name .. " not exist."
        logger.error({tag = "Editor", message = msg})
        widget_utils.message_box({title = "AnimationError", info = msg})
        return false
    end
    
    if current_anim == anim then return false end

    if current_anim and current_anim.collider then
        for _, col in ipairs(current_anim.collider) do
            if col.collider then
                ies.set_state(world:entity(col.eid), "visible", false)
            end
        end
    end
    current_anim = anim
    if current_anim.collider then
        for _, col in ipairs(current_anim.collider) do
            if col.collider then
                ies.set_state(world:entity(col.eid), "visible", true)
            end
        end
    end
    anim_state.anim_name = current_anim.name
    anim_state.key_event = current_anim.key_event
    anim_key_event = current_anim.key_event
    anim_state.duration = current_anim.duration
    current_event = nil
    
    anim_play({name = anim_name, loop = ui_loop[1], manual = false}, iani.play)
    anim_group_set_time(anim.eid_list[1], 0)
    anim_group_pause(anim.eid_list[1], not anim_state.is_playing)
    set_event_dirty(-1)
    return true
end


local event_id = 1

local function add_event(et)
    --if not current_clip then return end
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
        sound_event = (et == "Sound") and "" or nil,
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
    local key = tostring(anim_state.selected_frame)
    if not anim_key_event[key] then
        anim_key_event[key] = {}
        anim_state.current_event_list = anim_key_event[key]
    end
    local event_list = anim_key_event[key]--anim_state.current_event_list
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
    anim_key_event[tostring(anim_state.selected_frame)] = {}
    anim_state.current_event_list = anim_key_event[tostring(anim_state.selected_frame)]
    set_event_dirty(1)
end

local shape_type = {
    "sphere","box"
}

local function show_events()
    if anim_state.selected_frame >= 0 then -- and current_clip then
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
    if not world:entity(eid).collider then
        return
    end
    local tp = math3d.totable(iom.get_position(world:entity(eid)))
    collision.position = {tp[1], tp[2], tp[3]}
    local scale = math3d.totable(iom.get_scale(world:entity(eid)))
    local factor = world:entity(eid).collider.sphere and 100 or 200
    collision.size = {scale[1] / factor, scale[2] / factor, scale[3] / factor}
end

local sound_event_list = {}

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
                            collision.shape_type = world:entity(eid).collider.sphere and "sphere" or "box"
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
        if imgui.widget.Button("SelectBank") then
            local path = uiutils.get_open_file_path("Bank", "bank")
            if path then
                local rp = lfs.relative(lfs.path(path), global_data.project_root)
                local fullpath = (global_data.package_path and global_data.package_path or global_data.editor_package_path) .. tostring(rp)
                local bank = iaudio.load_bank(fullpath)
                if not bank then
                    print("LoadBank Faied. :", fullpath)
                end
                local bankname = fullpath:sub(1, -5) .. "strings.bank"
                local bank_string = iaudio.load_bank(bankname)
                if not bank_string then
                    print("LoadBank Faied. :", bankname)
                end
                local event_list = iaudio.get_event_list(bank)
                sound_event_list = {}
                for _, v in ipairs(event_list) do
                    sound_event_list[#sound_event_list + 1] = iaudio.get_event_name(v)
                end
                current_event.asset_path_ui.text = fullpath
                current_event.asset_path = fullpath
                dirty = true
            end
        end
        imgui.widget.Text("BankPath : " .. current_event.asset_path)
        imgui.widget.Text("SoundEvent : " .. current_event.sound_event)
        imgui.cursor.Separator();
        for _, se in ipairs(sound_event_list) do
            if imgui.widget.Selectable(se, current_event.sound_event == se, 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                current_event.sound_event = se
                if (imgui.util.IsMouseDoubleClicked(0)) then
                    iaudio.play(se)
                end
            end
        end
    elseif current_event.event_type == "Effect" then
        if imgui.widget.Button("SelectEffect") then
            local rpath = uiutils.get_open_file_path("Effect", "efk")
            if rpath then
                local pkgpath = access.virtualpath(global_data.repo, fs.path(rpath))
                current_event.asset_path_ui.text = pkgpath
                current_event.asset_path = pkgpath
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

function m.on_remove_entity(eid)
    local dirty = false
    -- for _, clip in ipairs(all_clips) do
    --     if clip.key_event then
    --         for _, ke in pairs(clip.key_event) do
    --             for _, e in ipairs(ke) do
    --                 if e.collision and e.collision.col_eid and e.collision.col_eid == eid then
    --                     e.collision.col_eid = -1
    --                     e.collision.shape_type = "None"
    --                     e.collision.position = nil
    --                     e.collision.size = nil
    --                     e.collision.enable = false
    --                     dirty = true
    --                 end
    --             end
    --         end
    --     end
    -- end
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
            local e = world:entity(eid)
            iom.set_position(e, ke.collision.position)
            local factor = e.collider.sphere and 100 or 200
            iom.set_scale(e, {ke.collision.size[1] * factor, ke.collision.size[2] * factor, ke.collision.size[3] * factor})
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
    local ke = anim_key_event[tostring(frame_idx)]
    anim_state.current_event_list = ke and ke or {}
    --if not current_clip or not current_clip.key_event then return end
    local newkey = tostring(anim_state.selected_frame)
    if move_type == 0 then
        local oldkey = tostring(old_selected_frame)
        anim_key_event[newkey] = anim_key_event[oldkey]
        anim_key_event[oldkey] = {}
    else
        if not anim_key_event[newkey] then
            anim_key_event[newkey] = {}
        end
        anim_state.current_event_list = anim_key_event[newkey]
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
    return string.sub(prefab_filename, 1, -8) .. ".event"
end

function m.save_keyevent(filename)
    local revent = to_runtime_event(anim_key_event)
    if #revent < 1 then
        return
    end
    local prefab_filename = filename or prefab_mgr:get_current_filename():sub(1, -8) .. ".event"
    utils.write_file(prefab_filename, stringify(revent))
end

function m.clear()
    current_anim = nil
    anim_eid_group = {}
    current_event = nil
    current_clip = nil
    edit_anims = nil
    skeleton_view.clear()
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

local ui_showskeleton = {false}
local function show_skeleton(b)
    local _, joints_list = joint_utils:get_joints()
    if not joints_list then
        return
    end
    for _, joint in ipairs(joints_list) do
        if joint.mesh then
            ies.set_state(world:entity(joint.mesh), "main_view", b)
        end
    end
end

function m.show()
    if not current_anim then return end
    local anim_e = current_anim.eid_list[1]
    if not anim_e then return end
    local reload = false
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    for _ in uiutils.imgui_windows("Animation", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        if current_anim then
            anim_state.is_playing = iani.is_playing(anim_e)
            if anim_state.is_playing then
                anim_state.current_frame = math.floor(iani.get_time(anim_e) * sample_ratio)
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
            if imgui.widget.InputText("##Name", ui_anim_name) then
                anim_name = tostring(ui_anim_name.text)
            end
            imgui.widget.Text("Path : " .. anim_glb_path)
            imgui.cursor.SameLine()
            local origin_name
            if imgui.widget.Button("...") then
                local localpath = uiutils.get_open_file_path("Animation", "anim")
                if localpath then
                    anim_path = access.virtualpath(global_data.repo, fs.path(localpath))
                end
                -- local glb_filename = uiutils.get_open_file_path("Animation", "glb")
                -- if glb_filename then
                --     external_anim_list = {}
                --     current_external_anim = nil
                --     anim_glb_path = "/" .. access.virtualpath(global_data.repo, fs.path(glb_filename))
                --     rc.compile(anim_glb_path)
                --     local external_path = rc.compile(anim_glb_path .. "|animations")
                --     for path in fs.pairs(external_path) do
                --         if path:equal_extension ".ozz" then
                --             local filename = path:filename():string()
                --             if filename ~= "skeleton.ozz" then
                --                 external_anim_list[#external_anim_list + 1] = filename
                --             end
                --         end
                --     end
                -- end
            end
            -- if #external_anim_list > 0 then
            --     imgui.cursor.Separator()
            --     for _, external_anim in ipairs(external_anim_list) do
            --         if imgui.widget.Selectable(external_anim, current_external_anim and (current_external_anim == external_anim), 0, 0, imgui.flags.Selectable {"DontClosePopups"}) then
            --             current_external_anim = external_anim
            --             anim_path = anim_glb_path .. "|animations/" .. external_anim
            --             if #anim_name < 1 then
            --                 anim_name = fs.path(anim_path):stem():string()
            --             end
            --         end
            --     end
            -- end
            imgui.cursor.Separator()
            if imgui.widget.Button("  OK  ") then
                if #anim_name > 0 and #anim_path > 0 then
                    local update = true
                    local anims = get_runtime_animations(anim_e)
                    if anims[anim_name] then
                        local confirm = {title = "Confirm", message = "animation ".. anim_name .. " exist, replace it ?"}
                        uiutils.confirm_dialog(confirm)
                        if confirm.answer and confirm.answer == 0 then
                            update = false
                        end
                    end
                    if update then
                        local group_eid = get_anim_group_eid(anim_e, current_anim.name)
                        --TODO: set for group eid
                        for _, eid in ipairs(group_eid) do
                            local template = hierarchy:get_template(eid)
                            template.template.data.animation[anim_name] = anim_path
                            world:entity(eid).animation[anim_name] = anim_path
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
            anim_group_delete(current_anim.name)
            local nextanim = edit_anims.name_list[1]
            if nextanim then
                set_current_anim(nextanim)
            end
            reload = true
        end
        imgui.cursor.SameLine()
        imgui.cursor.PushItemWidth(150)
        if imgui.widget.BeginCombo("##AnimationList", {current_anim.name, flags = imgui.flags.Combo {}}) then
            for _, name in ipairs(edit_anims.name_list) do
                if imgui.widget.Selectable(name, current_anim.name == name) then
                    set_current_anim(name)
                end
            end
            imgui.widget.EndCombo()
        end
        imgui.cursor.PopItemWidth()
        imgui.cursor.SameLine()
        local icon = anim_state.is_playing and icons.ICON_PAUSE or icons.ICON_PLAY
        if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
            if anim_state.is_playing then
                anim_group_pause(anim_e, true)
            else
                anim_play({name = current_anim.name, loop = ui_loop[1], manual = false}, iani.play)
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("loop", ui_loop) then
            anim_group_set_loop(anim_e, ui_loop[1])
        end
        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("showskeleton", ui_showskeleton) then
            show_skeleton(ui_showskeleton[1])
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("SaveEvent") then
            m.save_keyevent()
        end
        imgui.cursor.SameLine()
        local current_time = iani.get_time(anim_e)
        imgui.widget.Text(string.format("Selected Frame: %d Time: %.2f(s) Current Frame: %d/%d Time: %.2f/%.2f(s)", anim_state.selected_frame, anim_state.selected_frame / sample_ratio, math.floor(current_time * sample_ratio), math.floor(anim_state.duration * sample_ratio), current_time, anim_state.duration))
        imgui_message = {}
        imgui.widget.Sequencer(edit_anims, anim_state, imgui_message)
        -- clear dirty flag
        set_event_dirty(0)
        --
        local move_type
        local new_frame_idx
        local move_delta
        for k, v in pairs(imgui_message) do
            if k == "pause" then
                if anim_state.current_frame ~= v then
                    anim_group_pause(anim_e, true)
                    anim_state.current_frame = v
                    anim_group_set_time(anim_e, v / sample_ratio)   
                end
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
        if imgui.table.Begin("EventColumns", 3, imgui.flags.Table {'Resizable', 'ScrollY'}) then
            imgui.table.SetupColumn("Bones", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
            imgui.table.SetupColumn("Event", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
            imgui.table.SetupColumn("Event(Detail)", imgui.flags.TableColumn {'WidthStretch'}, 2.0)
            imgui.table.HeadersRow()

            imgui.table.NextColumn()
            local child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##show_joints", child_width, child_height, false)
            joint_utils:show_joints(joint_map.root)
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

            imgui.table.End()
        end
    end
    if reload then
        prefab_mgr:save_prefab()
        prefab_mgr:reload()
    end
end

function m.load_events(filename)
    local path = string.sub(filename, 1, -6) .. ".event"
    local f = fs.open(fs.path(path))
    if not f then
        return
    end
    local data = f:read "a"
    f:close()
    local events = datalist.parse(data)
    hierarchy:update_slot_list(world)
    for _, evs in pairs(events) do
        for _, ev in ipairs(evs.event_list) do
            if ev.link_info then
                local slot_eid = hierarchy.slot_list[ev.link_info.slot_name]
                if slot_eid then
                    ev.link_info.slot_eid = slot_eid
                else
                    ev.link_info.slot_name = ""
                end
            end
        end
    end
    return events
end

function m.on_prefab_load(entities)
    local editanims = { name_list = {} }
    local skeleton
    for _, eid in ipairs(entities) do
        local e = world:entity(eid)
        local animations = e.animation
        if not editanims.birth and e.animation_birth then
            editanims.birth = e.animation_birth
        end
        if not skeleton and e.skeleton then
            skeleton = e.skeleton
        end
        if animations then
            for key, anim in pairs(animations) do
                if not editanims[key] then
                    local events = m.load_events(tostring(anim))
                    editanims[key] = {
                        name = key,
                        duration = anim._handle:duration(),
                        key_event = events and from_runtime_event(events) or {},
                        eid_list = {}
                    }
                    editanims.name_list[#editanims.name_list + 1] = key
                end
                local edit_anim = editanims[key]
                edit_anim.eid_list[#edit_anim.eid_list + 1] = eid
            end
        end
    end
    if #editanims.name_list > 0 then
        edit_anims = editanims
        table.sort(edit_anims.name_list)
        set_current_anim(edit_anims.birth)
        skeleton_view.init(skeleton)
        joint_map, joint_list = joint_utils:get_joints()
    end
end

return m