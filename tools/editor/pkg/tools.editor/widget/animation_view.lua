local ecs = ...
local world = ecs.world
local fs        = require "filesystem"
local fastio    = require "fastio"
local iani      = ecs.require "ant.anim_ctrl|state_machine"
local ivs       = ecs.require "ant.render|visible_state"
local keyframe_view = ecs.require "widget.keyframe_view"
local prefab_mgr = ecs.require "prefab_manager"
local assetmgr = import_package "ant.asset"
local icons     = require "common.icons"
local logger    = require "widget.log"
local ImGui     = import_package "ant.imgui"
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
local srt_tag_list = {}
local mtl_tag_list = {}
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
    anim_name = '',
    key_event = {},
    event_dirty = 0,
    selected_clip_index = 0,
    current_event_list = {}
}
local ui_loop = {false}
local ui_speed = {1, min = 0.1, max = 10, speed = 0.1}
local ui_timeline_duration = {1, min = 1, max = 300, speed = 1}
local event_type = {"Animation", "Effect", "Sound", "Message"}

local current_event
local current_event_index
local current_clip
local anim_key_event = {}
local function find_index(t, item)
    for i, c in ipairs(t) do
        if c == item then
            return i
        end
    end
end

local datalist = require "datalist"
local function get_action_list(asset_path)
    local al = {}
    local tl = {}
    if asset_path and asset_path ~= '' then
        local animlist = datalist.parse(fastio.readall_f(global_data.project_root:string()..asset_path))
        for _, anim in ipairs(animlist) do
            al[#al + 1] = anim.name
            tl[anim.name] = anim.type
        end
    end
    return al, tl
end

local function do_to_runtime_event(evs)
    local list = {}
    for _, ev in ipairs(evs) do
        list[#list + 1] = {
            name        = ev.name,
            event_type  = ev.event_type,
            asset_path  = ev.asset_path ~= '' and ev.asset_path or nil,
            target      = ev.target ~= '' and ev.target or nil,
            action      = ev.action,
            sound_event = ev.sound_event,
            forwards    = ev.forwards,
            pause_frame = ev.pause_frame,
            msg_content = ev.msg_content,
        }
    end
    return list
end

local function to_runtime_event(ke)
    if not ke then
        return {}
    end
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
    local e <close> = world:entity(anim_eid, "animation:in")
    e.animation.status[anim_name] = nil
    prefab_mgr:on_patch_animation(anim_eid, anim_name)
    local name_idx = find_index(edit_anims.name_list, anim_name)
    if name_idx then
        table.remove(edit_anims.name_list, name_idx)
    end
end

local function from_runtime_event(runtime_event)
    local ke = {}
    for _, ev in ipairs(runtime_event) do
        for _, e in ipairs(ev.event_list) do
            if e.event_type == "Sound" or e.event_type == "Effect" or e.event_type == "Animation" then
                e.asset_path_ui = {text = e.asset_path or ''}
                e.action_list, e.action_type_map = get_action_list(e.asset_path)
                if e.event_type == "Animation" then
                    e.target_ui = {text = e.target or ''}
                    e.forwards = e.forwards or false
                    e.forwards_ui = {e.forwards}
                    e.pause_frame = e.pause_frame or -1
                    e.pause_frame_ui = {e.pause_frame, min = -1, max = 300, speed = 1}
                end
            elseif e.event_type == "Message" then
                e.msg_content = e.msg_content or ''
                e.msg_content_ui = {text = e.msg_content}
            end
        end
        ke[tostring(math.floor(ev.time * sample_ratio))] = ev.event_list
    end
    return ke
end

local widget_utils  = require "widget.utils"

local function set_current_anim(anim_name)
    if anim_name == '' then
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
    current_anim = anim
    anim_state.anim_name = current_anim.name
    anim_state.key_event = current_anim.key_event
    anim_key_event = current_anim.key_event
    anim_state.duration = current_anim.duration
    current_event = nil
    current_event_index = 0
    iani.play(anim_eid, {name = anim_name, loop = ui_loop[1], speed = ui_speed[1]})
    iani.set_time(anim_eid, 0)
    iani.pause(anim_eid, not anim_state.is_playing)
    return true
end

local function add_event(et)
    local new_event = {
        event_type      = et,
        asset_path      = (et == "Sound" or et == "Animation") and '' or nil,
        target          = (et == "Animation") and '' or nil,
        action          = (et == "Effect" or et == "Animation") and '' or nil,
        sound_event     = (et == "Sound") and '' or nil,
        forwards        = (et == "Animation") and false or nil,
        pause_frame     = (et == "Animation") and -1 or nil,
        forwards_ui     = (et == "Animation") and {false} or nil,
        pause_frame_ui  = (et == "Animation") and {-1, min = -1, max = 300, speed = 1} or nil,
        msg_content     = (et == "Message") and '' or nil,
        msg_content_ui  = (et == "Message") and {text = ''} or nil,
        asset_path_ui   = (et == "Effect" or et == "Sound" or et == "Animation") and {text = ''} or nil,
        target_ui       = (et == "Animation") and {text = ''} or nil
    }
    current_event = new_event
    local key = tostring(anim_state.selected_frame)
    if not anim_key_event[key] then
        anim_key_event[key] = {}
        anim_state.current_event_list = anim_key_event[key]
    end
    local event_list = anim_key_event[key]--anim_state.current_event_list
    event_list[#event_list + 1] = new_event
    current_event_index = #event_list
end

local function delete_event(idx)
    if not idx then
        return
    end
    current_event       = nil
    current_event_index = 0
    table.remove(anim_state.current_event_list, idx)
end

local function clear_event()
    anim_key_event[tostring(anim_state.selected_frame)] = {}
    anim_state.current_event_list = anim_key_event[tostring(anim_state.selected_frame)]
end

local function show_events()
    if anim_state.selected_frame >= 0 then -- and current_clip then
        ImGui.SameLine()
        if ImGui.Button(faicons.ICON_FA_SQUARE_PLUS.." AddEvent") then
            ImGui.OpenPopup("AddKeyEvent")
        end
    end

    if ImGui.BeginPopup("AddKeyEvent") then
        for _, et in ipairs(event_type) do
            if ImGui.MenuItem(et) then
                add_event(et)
            end
        end
        ImGui.EndPopup()
    end
    if #anim_state.current_event_list > 0 then
        ImGui.SameLine()
        if ImGui.Button("ClearEvent") then
            clear_event()
        end
    end
    if anim_state.current_event_list then
        local delete_idx
        for idx, ke in ipairs(anim_state.current_event_list) do
            local label = "event:" .. tostring(idx)
            if ImGui.Selectable(label, current_event and (current_event_index == idx)) then
                current_event = ke
                current_event_index = idx
            end
            if current_event and (current_event_index == idx) then
                if ImGui.BeginPopupContextItem(label) then
                    if ImGui.Selectable("Delete", false) then
                        delete_idx = idx
                    end
                    ImGui.EndPopup()
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
    ImGui.PropertyLabel("EventType")
    ImGui.Text(current_event.event_type)

    local dirty
    if current_event.event_type == "Sound" then
        if not bank_path and ImGui.Button("SelectBankPath") then
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
                local bank_files = {
                    bank_path .. "Master.strings.bank",
                    bank_path .. "Master.bank"
                }
                for value in fs.pairs(fs.path(bank_path)) do
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
        ImGui.Text("BankPath : " .. current_event.asset_path)
        ImGui.Text("SoundEvent : " .. current_event.sound_event)
        ImGui.Separator();
        for _, se in ipairs(sound_event_name_list) do
            if ImGui.Selectable(se, current_event.sound_event == se, ImGui.Flags.Selectable {"AllowDoubleClick"}) then
                current_event.sound_event = se
                if (ImGui.IsMouseDoubleClicked(0)) then
                    fmod.play(sound_event_list[se])
                    dirty = true
                end
            end
        end
    elseif current_event.event_type == "Effect" or current_event.event_type == "Animation" then
        local action_list = {}
        if current_event.event_type == "Animation" then
            local function update_asset_path(asset_path)
                current_event.asset_path = tostring(current_event.asset_path_ui.text)
                current_event.action_list, current_event.action_type_map = get_action_list(asset_path)
                current_event.action = nil
                current_event.target = nil
            end
            if ImGui.Button("Modify") then
                local localpath = uiutils.get_open_file_path("Modify Animation", "anim")
                if localpath then
                    current_event.asset_path_ui.text = access.virtualpath(global_data.repo, localpath)
                    update_asset_path(tostring(current_event.asset_path_ui.text))
                    dirty = true
                end
            end
            if current_event.asset_path and #current_event.asset_path > 0 then
                ImGui.PropertyLabel("AssetPath")
                if ImGui.InputText("##AssetPath", current_event.asset_path_ui) then
                    update_asset_path(tostring(current_event.asset_path_ui.text))
                    dirty = true
                end
            end
            action_list = current_event.action_list or {}
        end
        action_list = (current_event.event_type == "Effect") and prefab_mgr.efk_tag_list or (#action_list > 0 and action_list or (edit_anims and edit_anims.name_list or {}))
        if #action_list > 0 then
            local action = current_event.action or ''
            ImGui.PropertyLabel("Action")
            if ImGui.BeginCombo("##ActionList", {action, flags = ImGui.Flags.Combo {}}) then
                for _, name in ipairs(action_list) do
                    if ImGui.Selectable(name, action == name) then
                        current_event.action = name
                    end
                end
                ImGui.EndCombo()
                dirty = true
            end
        end
        if current_event.asset_path and #current_event.asset_path > 0 then
            local target = current_event.target or ''
            ImGui.PropertyLabel("Target")
            if ImGui.BeginCombo("##Target", {target, flags = ImGui.Flags.Combo {}}) then
                local namelist = (current_event.action_type_map[current_event.action] == "mtl") and prefab_mgr.mtl_list or prefab_mgr.srt_mtl_list
                for _, name in ipairs(namelist) do
                    if ImGui.Selectable(name, target == name) then
                        current_event.target = name
                    end
                end
                ImGui.EndCombo()
                dirty = true
            end
        end
        if current_event.event_type == "Animation" then
            ImGui.PropertyLabel("Forwards")
            if ImGui.Checkbox("##Forwards", current_event.forwards_ui) then
                current_event.forwards = current_event.forwards_ui[1]
                dirty = true
            end
            ImGui.PropertyLabel("PauseFrame")
            if ImGui.DragInt("##PauseFrame", current_event.pause_frame_ui) then
                current_event.pause_frame = current_event.pause_frame_ui[1]
                dirty = true
            end
        end
    elseif current_event.event_type == "Message" then
        ImGui.PropertyLabel("Content")
        if ImGui.InputText("##Content", current_event.msg_content_ui) then
            current_event.msg_content = tostring(current_event.msg_content_ui.text)
            dirty = true
        end
    end
end

function m.on_remove_entity(eid)
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
        current_event_index = 0
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
end

local stringify = import_package "ant.serialize".stringify
local event_filename

function m.save_timeline()
    if not timeline_eid then
        return
    end
    local info = hierarchy:get_node_info(timeline_eid)
    local tl = info.template.data.timeline
    tl.loop = ui_loop[1]
    tl.key_event = to_runtime_event(anim_key_event)
    tl.duration = ui_timeline_duration[1] / sample_ratio
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
        if not event_filename then
            event_filename = widget_utils.get_saveas_path("Save AnimationEvent", "event")
        end
        if event_filename then
            utils.write_file(event_filename, stringify(revent))
        end
    end
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
local anim_name_ui = {text = ''}
local anim_path_ui = {text = ''}
local update_slot_list = world:sub {"UpdateSlotList"}
local event_keyframe = world:sub{"keyframe_event"}
local iefk = ecs.require "ant.efk|efk"
local effect_map = {}
local itl = ecs.require "ant.timeline|timeline"
local current_timeline_id
local function play_timeline()
    if not timeline_eid then
        return
    end
    local e <close> = world:entity(timeline_eid, "timeline:in")
    e.timeline.key_event = to_runtime_event(anim_key_event)
    if #e.timeline.key_event <= 0 then
        return
    end
    anim_state.current_frame = 0
    timeline_playing = true
    if current_timeline_id then
        itl:stop(current_timeline_id)
    end
    current_timeline_id = itl:start(e)
end

local function stop_timeline()
    timeline_playing = false
    if current_timeline_id then
        itl:stop(current_timeline_id)
        current_timeline_id = nil
    end
end

function m.clear()
    stop_timeline()
    anim_eid = nil
    current_anim = nil
    current_event = nil
    current_event_index = 0
    current_clip = nil
    edit_anims = nil
    keyframe_view.clear()
    timeline_eid = nil
    edit_timeline = nil
    anim_state.key_event = {}
    anim_state.current_event_list = {}
    anim_state.selected_frame = -1
end

function m.get_title()
    return "Animation"
end

function m.show()
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
    local reload = false
    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    ImGui.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    if ImGui.Begin("Animation", true, ImGui.Flags.Window { "NoCollapse", "NoScrollbar" }) then
        if (not current_anim or not anim_eid) and not edit_timeline then
            goto continue
        end
        if edit_timeline then
            if timeline_playing then
                anim_state.current_frame = anim_state.current_frame + 1
                local maxframe = math.ceil(anim_state.duration * sample_ratio) - 1
                if anim_state.current_frame > maxframe then
                    if ui_loop[1] then
                        anim_state.current_frame = anim_state.current_frame - maxframe
                    else
                        anim_state.current_frame = maxframe
                        timeline_playing = false
                    end
                end
            end
        else
            if current_anim then
                anim_state.is_playing = iani.is_playing(anim_eid)
                if anim_state.is_playing then
                    anim_state.current_frame = math.floor(iani.get_time(anim_eid) * sample_ratio)
                end
            end
            ImGui.SameLine()
            ImGui.PushItemWidth(150)
            local current_name = edit_timeline and '' or current_anim.name
            local current_name_list = edit_timeline and {} or edit_anims.name_list
            if ImGui.BeginCombo("##NameList", {current_name, flags = ImGui.Flags.Combo {}}) then
                for _, name in ipairs(current_name_list) do
                    if ImGui.Selectable(name, current_name == name) then
                        set_current_anim(name)
                    end
                end
                ImGui.EndCombo()
            end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            local title = "Add"
            if ImGui.Button(faicons.ICON_FA_SQUARE_PLUS.." Add") then
                anim_name_ui.text = ''
                anim_path_ui.text = ''
                ImGui.OpenPopup(title)
            end
            local change = ImGui.BeginPopupModal(title, nil, ImGui.Flags.Window{"AlwaysAutoResize"})
            if change then
                ImGui.Text("Anim Name:")
                ImGui.SameLine()
                if ImGui.InputText("##AnimName", anim_name_ui) then
                end
                ImGui.Text("Anim Path:")
                ImGui.SameLine()
                if ImGui.InputText("##AnimPath", anim_path_ui) then
                end
                ImGui.SameLine()
                if ImGui.Button("...") then
                    local localpath = uiutils.get_open_file_path("Select Animation", "anim")
                    if localpath then
                        anim_path_ui.text = access.virtualpath(global_data.repo, localpath)
                    end
                end
                ImGui.Separator()
                if ImGui.Button(faicons.ICON_FA_CHECK.."  OK  ") then
                    local anim_name = tostring(anim_name_ui.text)
                    local anim_path = tostring(anim_path_ui.text)
                    if #anim_name > 0 and #anim_path > 0 then
                        local update = true
                        local e <close> = world:entity(anim_eid, "animation:in")
                        if e.animation.status[anim_name] then
                            local confirm = {title = "Confirm", message = "animation ".. anim_name .. " exist, replace it ?"}
                            uiutils.confirm_dialog(confirm)
                            if confirm.answer and confirm.answer == 0 then
                                update = false
                            end
                        end
                        if update then
                            -- local info = hierarchy:get_node_info(anim_eid)
                            -- info.template.data.animation[anim_name] = anim_path
                            prefab_mgr:on_patch_animation(anim_eid, anim_name, anim_path)
                            e.animation.status[anim_name] = anim_path
                            --TODO:reload
                            reload = true
                        end
                    end
                    ImGui.CloseCurrentPopup()
                end
                ImGui.SameLine()
                if ImGui.Button(faicons.ICON_FA_XMARK.." Cancel") then
                    ImGui.CloseCurrentPopup()
                end
                ImGui.EndPopup()
            end

            ImGui.SameLine()
            if ImGui.Button(faicons.ICON_FA_TRASH.." Remove") then
                anim_group_delete(current_anim.name)
                local nextanim = edit_anims.name_list[1]
                if nextanim then
                    set_current_anim(nextanim)
                end
                reload = true
            end
        end
        ImGui.SameLine()
        local icon = anim_state.is_playing and icons.ICON_PAUSE or icons.ICON_PLAY
        local imagesize = icon.texinfo.width * icons.scale
        if ImGui.ImageButton("##play", assetmgr.textures[icon.id], imagesize, imagesize) then
            if not edit_timeline then
                if anim_state.is_playing then
                    iani.pause(anim_eid, true)
                else
                    iani.play(anim_eid, {name = current_anim.name, loop = ui_loop[1], speed = ui_speed[1]})
                end
            else
                play_timeline()
            end
        end
        ImGui.SameLine()
        if ImGui.Checkbox("loop", ui_loop) then
            if not edit_timeline then
                iani.set_loop(anim_eid, ui_loop[1])
            else
                if timeline_playing then
                    stop_timeline()
                end
                local e <close> = world:entity(timeline_eid, "timeline:in")
                e.timeline.loop = ui_loop[1]
            end
        end
        if not edit_timeline then
            ImGui.SameLine()
            ImGui.PushItemWidth(50)
            if ImGui.DragFloat("speed", ui_speed) then
                iani.set_speed(anim_eid, ui_speed[1])
            end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            if ImGui.Checkbox("showskeleton", ui_showskeleton) then
                show_skeleton(ui_showskeleton[1])
            end
        else
            ImGui.SameLine()
            ImGui.PushItemWidth(100)
            if ImGui.DragInt("duration", ui_timeline_duration) then
                local second = ui_timeline_duration[1] / sample_ratio
                edit_timeline.duration = second
                anim_state.duration = second
                edit_timeline["timeline"].duration = second
                edit_timeline.dirty = true
                local e <close> = world:entity(timeline_eid, "timeline:in")
                e.timeline.duration = second
            end
        end
        ImGui.SameLine()
        if ImGui.Button(faicons.ICON_FA_FLOPPY_DISK.." SaveEvent") then
            if edit_timeline then
                m.save_timeline()
            else
                m.save_keyevent()
            end
        end
        ImGui.SameLine()
        local current_time = edit_timeline and (anim_state.current_frame / sample_ratio) or iani.get_time(anim_eid)
        ImGui.Text(string.format("Selected Frame: %d Time: %.2f(s) Current Frame: %d/%d Time: %.2f/%.2f(s)", anim_state.selected_frame, anim_state.selected_frame / sample_ratio, math.floor(current_time * sample_ratio), math.floor(anim_state.duration * sample_ratio), current_time, anim_state.duration))
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
        ImGui.Separator()
        if ImGui.BeginTable("EventColumns", edit_timeline and 2 or 3, ImGui.Flags.Table {'Resizable', 'ScrollY'}) then
            if not edit_timeline then
                ImGui.TableSetupColumnEx("Bones", ImGui.Flags.TableColumn {'WidthStretch'}, 1.0)
            end
            ImGui.TableSetupColumnEx("Event", ImGui.Flags.TableColumn {'WidthStretch'}, 1.0)
            ImGui.TableSetupColumnEx("Event(Detail)", ImGui.Flags.TableColumn {'WidthStretch'}, 2.0)
            ImGui.TableHeadersRow()
            local child_width, child_height
            if not edit_timeline then
                ImGui.TableNextColumn()
                child_width, child_height = ImGui.GetContentRegionAvail()
                ImGui.BeginChild("##show_joints", child_width, child_height)
                joint_utils:show_joints(joint_map.root)
                ImGui.EndChild()
            end
            ImGui.TableNextColumn()
            child_width, child_height = ImGui.GetContentRegionAvail()
            ImGui.BeginChild("##show_events", child_width, child_height)
            show_events()
            ImGui.EndChild()

            ImGui.TableNextColumn()
            child_width, child_height = ImGui.GetContentRegionAvail()
            ImGui.BeginChild("##show_current_event", child_width, child_height)
            show_current_event()
            ImGui.EndChild()
            ImGui.EndTable()
        end
        ::continue::
    end
    ImGui.End()
    if reload then
        prefab_mgr:save()
        prefab_mgr:reload()
    end
end

function m.on_prefab_load(eid)
    if not eid then
        return
    end
    local editanims = {dirty = true, name_list = {} }
    local skeleton
    local e <close> = world:entity(eid, "animation?in")
    if e.animation then
        anim_eid = eid
        local animations = e.animation.status
        if animations then
            skeleton = e.animation.skeleton
            for key, status in pairs(e.animation.status) do
                if not editanims[key] then
                    editanims[key] = {
                        name = key,
                        duration = status.handle:duration(),
                    }
                    editanims.name_list[#editanims.name_list + 1] = key
                end
            end
        end
    end
    if #editanims.name_list > 0 then
        edit_anims = editanims
        table.sort(edit_anims.name_list)
        set_current_anim(editanims.name_list[1])
        keyframe_view.init(skeleton)
        joint_map, _ = joint_utils:get_joints()
    end
end

function m.on_target(eid)
    stop_timeline()
    edit_timeline = nil
    timeline_eid = nil
    if not eid then
        return
    end
    local e <close> = world:entity(eid, "timeline?in")
    if e.timeline then
        if not e.timeline.eid_map then
            e.timeline.eid_map = prefab_mgr.current_prefab.tag
        end
        
        timeline_eid = eid
        edit_timeline = {
            dirty = true
        }
        edit_timeline["timeline"] = {
            name = "timeline",
            duration = e.timeline.duration,
            key_event = from_runtime_event(e.timeline.key_event),
        }
        local frame = math.floor(e.timeline.duration * sample_ratio)
        ui_loop[1] = e.timeline.loop
        ui_timeline_duration[1] = frame
        local current_timeline = edit_timeline["timeline"]
        anim_state.anim_name = current_timeline.name
        anim_state.key_event = current_timeline.key_event
        anim_key_event = current_timeline.key_event
        anim_state.duration = current_timeline.duration
        anim_state.current_frame = 0
    elseif current_anim then
        anim_state.anim_name = current_anim.name
        anim_state.key_event = current_anim.key_event
        anim_key_event = current_anim.key_event
        anim_state.duration = current_anim.duration
        anim_state.current_frame = 0
        edit_anims.dirty = true
    end
end

function m.update_anim_namelist()
    -- efk_tag_list = namelist
end

return m