local ecs = ...
local world = ecs.world
local iani      = ecs.require "ant.anim_ctrl|state_machine"
local ivs       = ecs.require "ant.render|visible_state"
local keyframe_view = ecs.require "widget.keyframe_view"
local prefab_mgr = ecs.require "prefab_manager"
local assetmgr = import_package "ant.asset"
local icons     = require "common.icons"
local logger    = require "widget.log"
local imgui     = require "imgui"
local imguiWidgets = require "imgui.widgets"
local hierarchy = require "hierarchy_edit"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local joint_utils = require "widget.joint_utils"
local utils     = require "common.utils"
local global_data = require "common.global_data"
local access    = global_data.repo_access
local faicons   = require "common.fa_icons"
local fmod      = require "fmod"

local edit_timeline
local timeline_eid
local timeline_playing = false
local m = {}
local edit_anims
local anim_eid
local imgui_message
local current_anim
local sample_ratio = 30.0
local joint_map = {}
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
local birth_anim = {false}
local ui_loop = {false}
local ui_speed = {1, min = 0.1, max = 10, speed = 0.1}
local ui_timeline_duration = {1, min = 1, max = 300, speed = 1}
local event_type = {"Animation", "Effect", "Sound", "Message"}

local current_event
local current_clip
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
        list[#list + 1] = {
            event_type  = ev.event_type,
            name        = ev.name,
            asset_path  = ev.asset_path,
            sound_event = ev.sound_event,
            breakable   = ev.breakable,
            life_time   = ev.life_time,
            move        = ev.move,
            msg_content = ev.msg_content,
            link_info   = ev.link_info and {slot_name = ev.link_info.slot_name, slot_eid = ev.link_info.slot_eid and (ev.link_info.slot_eid > 0 and ev.link_info.slot_eid or nil) or nil },
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
    for _, frame_idx in ipairs(temp) do
        event[#event + 1] = {
            time = frame_idx / sample_ratio,
            tick = edit_timeline and frame_idx or nil,
            event_list = do_to_runtime_event(ke[tostring(frame_idx)])
        }
    end
    return event
end

local function anim_group_delete(anim_name)
    local info = hierarchy:get_node_info(anim_eid)
    local tdata = info.template.data
    local animation_map = tdata.animation
    animation_map[anim_name] = nil
    local e <close> = world:entity(anim_eid, "animation:in")
    e.animation.ozz.animations[anim_name] = nil
    prefab_mgr:on_patch_animation(anim_eid, anim_name)
    if tdata.animation_birth == anim_name then
        tdata.animation_birth = next(animation_map) or ""
    end
    local name_idx = find_index(edit_anims.name_list, anim_name)
    if name_idx then
        table.remove(edit_anims.name_list, name_idx)
    end
end

local function from_runtime_event(runtime_event)
    local ke = {}
    for _, ev in ipairs(runtime_event) do
        for _, e in ipairs(ev.event_list) do
            e.name_ui = {text = e.name}
            if e.event_type == "Sound" or e.event_type == "Effect" or e.event_type == "Animation" then
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
    if not current_clip then
        return
    end
    return current_clip.key_event
end

local function set_event_dirty(num)
    if not edit_timeline then
        local e <close> = world:entity(anim_eid, "anim_ctrl:in")
        iani.stop_effect(anim_eid)
        e.anim_ctrl.keyframe_events[current_anim.name] = to_runtime_event(anim_key_event)
    end
    anim_state.event_dirty = num
end

local widget_utils  = require "widget.utils"

local function set_current_anim(anim_name)
    if anim_name == "" then
        return
    end
    local anim = edit_anims[anim_name]
    if not anim then
        local msg = anim_name .. " not exist."
        logger.error({tag = "Editor", message = msg})
        widget_utils.message_box({title = "AnimationError", info = msg})
        return false
    end

    if current_anim == anim then
        return false
    end
    local tpl = hierarchy:get_node_info(anim_eid).template
    birth_anim[1] = (anim_name == tpl.data.animation_birth)

    if current_anim and current_anim.collider then
        for _, col in ipairs(current_anim.collider) do
            if col.collider then
                local e <close> = world:entity(col.eid)
                ivs.set_state(e, "visible", false)
            end
        end
    end
    current_anim = anim
    if current_anim.collider then
        for _, col in ipairs(current_anim.collider) do
            if col.collider then
                local e <close> = world:entity(col.eid)
                ivs.set_state(e, "visible", true)
            end
        end
    end
    anim_state.anim_name = current_anim.name
    anim_state.key_event = current_anim.key_event
    anim_key_event = current_anim.key_event
    anim_state.duration = current_anim.duration
    current_event = nil
    
    iani.play(anim_eid, {name = anim_name, loop = ui_loop[1], speed = ui_speed[1], manual = false})
    iani.set_time(anim_eid, 0)
    iani.pause(anim_eid, not anim_state.is_playing)
    set_event_dirty(-1)
    return true
end

local event_id = 1

local function add_event(et)
    --if not current_clip then return end
    event_id = event_id + 1
    local event_name = et..tostring(event_id)
    local new_event = {
        event_type      = et,
        name            = event_name,
        asset_path      = (et == "Effect" or et == "Sound") and "" or nil,
        link_info       = (et == "Effect") and {
            slot_name = "",
            slot_eid = nil,
        } or nil,
        sound_event     = (et == "Sound") and "" or nil,
        breakable       = (et == "Effect") and false or nil,
        breakable_ui    = (et == "Effect") and {false} or nil,
        life_time       = (et == "Effect") and 2 or nil,
        life_time_ui    = (et == "Effect") and { 2, speed = 0.02, min = 0, max = 100} or nil,
        move            = (et == "Move") and {0.0, 0.0, 0.0} or nil,
        move_ui         = (et == "Move") and {0.0, 0.0, 0.0} or nil,
        name_ui         = {text = event_name},
        msg_content     = (et == "Message") and "" or nil,
        msg_content_ui  = (et == "Message") and {text = ""} or nil,
        asset_path_ui   = (et == "Effect" or et == "Sound") and {text = ""} or nil
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

local function show_events()
    if anim_state.selected_frame >= 0 then -- and current_clip then
        imgui.cursor.SameLine()
        if imgui.widget.Button(faicons.ICON_FA_SQUARE_PLUS.." AddEvent") then
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

local sound_event_name_list = {}
local sound_event_list = {}
local bank_path
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
    if current_event.event_type == "Animation" then
        if imgui.widget.Button("SelectAnimation") then
            local rpath = uiutils.get_open_file_path("Animation", "anim|ozz")
            if rpath then
                local pkgpath = access.virtualpath(global_data.repo, rpath)
                assert(pkgpath)
                current_event.asset_path_ui.text = pkgpath
                current_event.asset_path = pkgpath
                dirty = true
            end
        end
        imgui.widget.PropertyLabel("AnimationPath")
        imgui.widget.InputText("##AnimationPath", current_event.asset_path_ui)
    elseif current_event.event_type == "Sound" then
        if not bank_path and imgui.widget.Button("SelectBankPath") then
            local filename = uiutils.get_open_file_path("Bank", "bank")
            if filename then
                bank_path = filename:match("^(.+/)[%w*?_.%-]*$")
                for _, pkg in ipairs(global_data.packages) do
                    local pv = tostring(pkg.path)
                    if pv == string.sub(bank_path, 1, #pv) then
                        bank_path = "/pkg/"..pkg.name .. string.sub(bank_path, #pv + 1)
                        break;
                    end
                end
                local files = access.list_files(global_data.repo, bank_path)
                local bank_files = {
                    bank_path .. "Master.strings.bank",
                    bank_path .. "Master.bank"
                }
                for value in pairs(files) do
                    if string.sub(value, -5) == ".bank" and (value ~= "Master.strings.bank") and (value ~= "Master.bank") then
                        bank_files[#bank_files + 1] = bank_path .. value
                    end
                end
                local audio = global_data.audio
                for _, file in ipairs(bank_files) do
                    audio:load_bank(file, sound_event_list)
                end
                for key, _ in pairs(sound_event_list) do
                    sound_event_name_list[#sound_event_name_list + 1] = key
                end
                world.sound_event_list = sound_event_list
            --     local rp = lfs.relative(lfs.path(path), global_data.project_root)
            --     local fullpath = (global_data.package_path and global_data.package_path or global_data.editor_package_path) .. tostring(rp)
            --     local bank = iaudio.load_bank(fullpath)
            --     if not bank then
            --         print("LoadBank Faied. :", fullpath)
            --     end
            --     local bankname = fullpath:sub(1, -5) .. "strings.bank"
            --     local bank_string = iaudio.load_bank(bankname)
            --     if not bank_string then
            --         print("LoadBank Faied. :", bankname)
            --     end
            --     local event_list = iaudio.get_event_list(bank)
            --     sound_event_list = {}
            --     for _, v in ipairs(event_list) do
            --         sound_event_list[#sound_event_list + 1] = iaudio.get_event_name(v)
            --     end
            --     current_event.asset_path_ui.text = fullpath
            --     current_event.asset_path = fullpath
            --     dirty = true
            end
        end
        imgui.widget.Text("BankPath : " .. current_event.asset_path)
        imgui.widget.Text("SoundEvent : " .. current_event.sound_event)
        imgui.cursor.Separator();
        for _, se in ipairs(sound_event_name_list) do
            if imgui.widget.Selectable(se, current_event.sound_event == se, 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                current_event.sound_event = se
                if (imgui.util.IsMouseDoubleClicked(0)) then
                    fmod.play(sound_event_list[se])
                    dirty = true
                end
            end
        end
    elseif current_event.event_type == "Effect" then
        if imgui.widget.Button("SelectEffect") then
            local rpath = uiutils.get_open_file_path("Effect", "efk")
            if rpath then
                local pkgpath = access.virtualpath(global_data.repo, rpath)
                assert(pkgpath)
                current_event.asset_path_ui.text = pkgpath
                current_event.asset_path = pkgpath
                dirty = true
            end
        end
        imgui.widget.PropertyLabel("EffectPath")
        if imgui.widget.InputText("##EffectPath", current_event.asset_path_ui) then
            current_event.asset_path = tostring(current_event.asset_path_ui.text)
            dirty = true
        end
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
    local e <close> = world:entity(eid, "slot?in")
    if e.slot and anim_eid then
        local ae <close> = world:entity(anim_eid, "anim_ctrl?in")
        local tpl = hierarchy:get_node_info(eid).template
        local name = tpl.tag and tpl.tag[1] or ""
        ae.anim_ctrl.slot_eid[name] = nil
    end
    if dirty then
        set_event_dirty(-1)
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
        current_event = nil
    end
    set_event_dirty(-1)
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
end

local stringify = import_package "ant.serialize".stringify
local event_filename

function m.save_timeline()
    if not timeline_eid then
        return
    end
    local info = hierarchy:get_node_info(timeline_eid)
    info.template.data.timeline.loop = ui_loop[1]
    info.template.data.timeline.key_event = to_runtime_event(anim_key_event)
    info.template.data.timeline.duration = ui_timeline_duration[1] / sample_ratio
end

function m.save_keyevent()
    if not edit_anims then
        return
    end
    local revent = {}
    for _, name in ipairs(edit_anims.name_list) do
        local eventlist = to_runtime_event(edit_anims[name].key_event)
        if #eventlist > 0 then
            revent[name] = eventlist
        end
    end
    if next(revent) then
        --local prefab_filename = filename or prefab_mgr:get_current_filename():sub(1, -8) .. ".event"
        if not event_filename then
            event_filename = widget_utils.get_saveas_path("Save AnimationEvent", "event")
        end
        if event_filename then
            utils.write_file(event_filename, stringify(revent))
        end
    end
end

function m.clear()
    anim_eid = nil
    current_anim = nil
    current_event = nil
    current_clip = nil
    edit_anims = nil
    keyframe_view.clear()
end

local ui_showskeleton = {false}
local function show_skeleton(b)
    local _, joints_list = joint_utils:get_joints()
    if not joints_list then
        return
    end
    for _, joint in ipairs(joints_list) do
        if joint.mesh then
            local e <close> = world:entity(joint.mesh)
            ivs.set_state(e, "main_view", b)
            local be <close> = world:entity(joint.bone_mesh)
            ivs.set_state(be, "main_view", b)
        end
    end
    joint_utils.show_skeleton = b
end
local anim_name_ui = {text = ""}
local anim_path_ui = {text = ""}
local update_slot_list = world:sub {"UpdateSlotList"}
local event_keyframe = world:sub{"keyframe_event"}
local iefk = ecs.require "ant.efk|efk"
local effect_map = {}

local function play_timeline()
    if not timeline_eid then
        return
    end
    local e <close> = world:entity(timeline_eid, "start_timeline?out timeline:in")
    e.start_timeline = true
    e.timeline.key_event = to_runtime_event(anim_key_event)
    anim_state.current_frame = 0
    timeline_playing = true
end

local function stop_timeline()
    timeline_playing = false
    if not timeline_eid then
        return
    end
end

function m.show()
    for _ in update_slot_list:unpack() do
        if anim_eid then
            local slotlist = {}
            for name, eid in pairs(hierarchy.slot_list) do
                slotlist[name] = eid
            end
            local e <close> = world:entity(anim_eid, "anim_ctrl:in")
            e.anim_ctrl.slot_eid = slotlist
            break
        end
    end
    for _, action, path in event_keyframe:unpack() do
        if action == "effect" then
            if not effect_map[path] then
                effect_map[path] = iefk.create(path, {
                    scene = {},
                    visible_state = "main_queue",
                })
            else
                local e <close> = world:entity(effect_map[path], "efk:in")
                iefk.play(e)
            end
        end
    end
    if (not current_anim or not anim_eid) and not edit_timeline then
        return
    end
    local reload = false
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    if imgui.windows.Begin("Animation", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) then
        if edit_timeline then
            if timeline_playing then
                anim_state.current_frame = anim_state.current_frame + 1
                local maxframe = math.ceil(anim_state.duration * sample_ratio) - 1
                if anim_state.current_frame > maxframe then
                    anim_state.current_frame = maxframe
                    timeline_playing = false
                end
            end
        else
            if current_anim then
                anim_state.is_playing = iani.is_playing(anim_eid)
                if anim_state.is_playing then
                    anim_state.current_frame = math.floor(iani.get_time(anim_eid) * sample_ratio)
                end
            end
            imgui.cursor.SameLine()
            local title = "Add"
            if imgui.widget.Button(faicons.ICON_FA_SQUARE_PLUS.." Add") then
                anim_name_ui.text = ""
                anim_path_ui.text = ""
                imgui.windows.OpenPopup(title)
            end
            local change, opened = imgui.windows.BeginPopupModal(title, imgui.flags.Window{"AlwaysAutoResize"})
            if change then
                imgui.widget.Text("Anim Name:")
                imgui.cursor.SameLine()
                if imgui.widget.InputText("##AnimName", anim_name_ui) then
                end
                imgui.widget.Text("Anim Path:")
                imgui.cursor.SameLine()
                if imgui.widget.InputText("##AnimPath", anim_path_ui) then
                end
                imgui.cursor.SameLine()
                if imgui.widget.Button("...") then
                    local localpath = uiutils.get_open_file_path("Animation", "anim")
                    if localpath then
                        anim_path_ui.text = access.virtualpath(global_data.repo, localpath)
                    end
                end
                imgui.cursor.Separator()
                if imgui.widget.Button(faicons.ICON_FA_CHECK.."  OK  ") then
                    local anim_name = tostring(anim_name_ui.text)
                    local anim_path = tostring(anim_path_ui.text)
                    if #anim_name > 0 and #anim_path > 0 then
                        local update = true
                        local e <close> = world:entity(anim_eid, "animation:in")
                        if e.animation.ozz.animations[anim_name] then
                            local confirm = {title = "Confirm", message = "animation ".. anim_name .. " exist, replace it ?"}
                            uiutils.confirm_dialog(confirm)
                            if confirm.answer and confirm.answer == 0 then
                                update = false
                            end
                        end
                        if update then
                            local info = hierarchy:get_node_info(anim_eid)
                            info.template.data.animation[anim_name] = anim_path
                            prefab_mgr:on_patch_animation(anim_eid, anim_name, anim_path)
                            e.animation.ozz.animations[anim_name] = anim_path
                            --TODO:reload
                            reload = true
                        end
                    end
                    imgui.windows.CloseCurrentPopup()
                end
                imgui.cursor.SameLine()
                if imgui.widget.Button(faicons.ICON_FA_XMARK.." Cancel") then
                    imgui.windows.CloseCurrentPopup()
                end
                imgui.windows.EndPopup()
            end

            imgui.cursor.SameLine()
            if imgui.widget.Button(faicons.ICON_FA_TRASH.." Remove") then
                anim_group_delete(current_anim.name)
                local nextanim = edit_anims.name_list[1]
                if nextanim then
                    set_current_anim(nextanim)
                end
                reload = true
            end
            imgui.cursor.SameLine()
            imgui.cursor.PushItemWidth(150)
            local current_name = edit_timeline and "" or current_anim.name
            local current_name_list = edit_timeline and {} or edit_anims.name_list
            if imgui.widget.BeginCombo("##NameList", {current_name, flags = imgui.flags.Combo {}}) then
                for _, name in ipairs(current_name_list) do
                    if imgui.widget.Selectable(name, current_name == name) then
                        set_current_anim(name)
                    end
                end
                imgui.widget.EndCombo()
            end
            imgui.cursor.PopItemWidth()
            imgui.cursor.SameLine()
            if imgui.widget.Checkbox("default", birth_anim) then
                local tpl = hierarchy:get_node_info(anim_eid).template
                tpl.data.animation_birth = birth_anim[1] and current_anim.name or nil
                prefab_mgr:do_patch(anim_eid, "/data/animation_birth", tpl.data.animation_birth)
            end
        end
        imgui.cursor.SameLine()
        local icon = anim_state.is_playing and icons.ICON_PAUSE or icons.ICON_PLAY
        local imagesize = icon.texinfo.width * icons.scale
        if imgui.widget.ImageButton("##play", assetmgr.textures[icon.id], imagesize, imagesize) then
            if not edit_timeline then
                if anim_state.is_playing then
                    iani.pause(anim_eid, true)
                else
                    iani.play(anim_eid, {name = current_anim.name, loop = ui_loop[1], speed = ui_speed[1], manual = false})
                end
            else
                play_timeline()
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("loop", ui_loop) then
            if not edit_timeline then
                iani.set_loop(anim_eid, ui_loop[1])
            else
                local e <close> = world:entity(timeline_eid, "timeline:in")
                e.timeline.loop = ui_loop[1]
            end
        end
        if not edit_timeline then
            imgui.cursor.SameLine()
            imgui.cursor.PushItemWidth(50)
            if imgui.widget.DragFloat("speed", ui_speed) then
                iani.set_speed(anim_eid, ui_speed[1])
            end
            imgui.cursor.PopItemWidth()
            imgui.cursor.SameLine()
            if imgui.widget.Checkbox("showskeleton", ui_showskeleton) then
                show_skeleton(ui_showskeleton[1])
            end
        else
            imgui.cursor.SameLine()
            imgui.cursor.PushItemWidth(100)
            if imgui.widget.DragInt("duration", ui_timeline_duration) then
                local second = ui_timeline_duration[1] / sample_ratio
                edit_timeline.duration = second
                anim_state.duration = second
                local tpl = hierarchy:get_node_info(timeline_eid).template
                edit_timeline[tpl.tag[1]].duration = second
                edit_timeline.dirty = true
                local e <close> = world:entity(timeline_eid, "timeline:in")
                e.timeline.duration = second
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button(faicons.ICON_FA_FLOPPY_DISK.." SaveEvent") then
            if edit_timeline then
                m.save_timeline()
            else
                m.save_keyevent()
            end
        end
        imgui.cursor.SameLine()
        local current_time = iani.get_time(anim_eid)
        imgui.widget.Text(string.format("Selected Frame: %d Time: %.2f(s) Current Frame: %d/%d Time: %.2f/%.2f(s)", anim_state.selected_frame, anim_state.selected_frame / sample_ratio, math.floor(current_time * sample_ratio), math.floor(anim_state.duration * sample_ratio), current_time, anim_state.duration))
        imgui_message = {}
        local current_seq = edit_timeline and edit_timeline or edit_anims
        imguiWidgets.Sequencer(current_seq, anim_state, imgui_message)
        current_seq.dirty = false
        local move_type
        local new_frame_idx
        local move_delta
        for k, v in pairs(imgui_message) do
            if k == "pause" then
                if anim_state.current_frame ~= v then
                    anim_state.current_frame = v
                end
                if not edit_timeline then
                    iani.pause(anim_eid, true)
                    iani.set_time(anim_eid, v / sample_ratio)
                else
                    stop_timeline()
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
        if imgui.table.Begin("EventColumns", edit_timeline and 2 or 3, imgui.flags.Table {'Resizable', 'ScrollY'}) then
            if not edit_timeline then
                imgui.table.SetupColumn("Bones", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
            end
            imgui.table.SetupColumn("Event", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
            imgui.table.SetupColumn("Event(Detail)", imgui.flags.TableColumn {'WidthStretch'}, 2.0)
            imgui.table.HeadersRow()
            local child_width, child_height
            if not edit_timeline then
                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##show_joints", child_width, child_height)
                joint_utils:show_joints(joint_map.root)
                imgui.windows.EndChild()
            end
            imgui.table.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##show_events", child_width, child_height)
            show_events()
            imgui.windows.EndChild()

            imgui.table.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##show_current_event", child_width, child_height)
            show_current_event()
            imgui.windows.EndChild()
            imgui.table.End()
        end
    end
    imgui.windows.End()
    if reload then
        prefab_mgr:save()
        prefab_mgr:reload()
    end
end

function m.on_prefab_load(entities)
    local editanims = {dirty = true, name_list = {} }
    local skeleton
    for _, eid in ipairs(entities) do
        local e <close> = world:entity(eid, "anim_ctrl?in animation?in animation_birth?in")
        if e.anim_ctrl then
            anim_eid = eid
            local prefab_filename = prefab_mgr:get_current_filename()
            local path_list = utils.split_ant_path(prefab_filename)
            if path_list[1] then
                --xxx.glb
                iani.load_events(eid, string.sub(path_list[1], 1, -5) .. ".event")
            else
                ---xxx.prefab
                iani.load_events(eid, string.sub(prefab_filename, 1, -8) .. ".event")
            end
            
            local animations = e.animation.ozz.animations
            if animations then
                editanims.birth = e.animation_birth
                skeleton = e.animation.ozz.skeleton
                for key, anim in pairs(animations) do
                    if not editanims[key] then
                        local events = e.anim_ctrl.keyframe_events[key]
                        editanims[key] = {
                            name = key,
                            duration = anim:duration(),
                            key_event = events and from_runtime_event(events) or {},
                        }
                        editanims.name_list[#editanims.name_list + 1] = key
                    end
                end
                break
            end
        end
    end
    hierarchy:update_slot_list(world)
    if #editanims.name_list > 0 then
        edit_anims = editanims
        table.sort(edit_anims.name_list)
        local animname
        if edit_anims.birth and edit_anims.birth ~="" then
            animname = edit_anims.birth
        else
            animname = editanims.name_list[1]
        end
        set_current_anim(animname)
        keyframe_view.init(skeleton)
        joint_map, _ = joint_utils:get_joints()
    end
end

function m.on_target(eid)
    edit_timeline = nil
    timeline_eid = nil
    local e <close> = world:entity(eid, "timeline?in")
    if e.timeline then
        if not e.timeline.eid_map then
            e.timeline.eid_map = prefab_mgr.current_prefab.tag
        end
        local name = hierarchy:get_node_info(eid).template.tag[1]
        timeline_eid = eid
        edit_timeline = {
            dirty = true
        }
        edit_timeline[name] = {
            name = name,
            duration = e.timeline.duration,
            key_event = from_runtime_event(e.timeline.key_event),
        }
        local frame = math.floor(e.timeline.duration * sample_ratio)
        ui_loop[1] = e.timeline.loop
        ui_timeline_duration[1] = frame
        local current_timeline = edit_timeline[name]
        anim_state.anim_name = current_timeline.name
        anim_state.key_event = current_timeline.key_event
        anim_key_event = current_timeline.key_event
        anim_state.duration = current_timeline.duration
        anim_state.current_frame = 0
        anim_state.dirty = true
        set_event_dirty(-1)
    elseif current_anim then
        anim_state.anim_name = current_anim.name
        anim_state.key_event = current_anim.key_event
        anim_key_event = current_anim.key_event
        anim_state.duration = current_anim.duration
        anim_state.current_frame = 0
        anim_state.dirty = true
        set_event_dirty(-1)
    end
end

return m