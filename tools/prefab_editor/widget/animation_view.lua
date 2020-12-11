local imgui     = require "imgui"
local math3d    = require "math3d"
local hierarchy = require "hierarchy"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local utils     = require "common.utils"
local world
local icons
local iani

local m = {}
local ozz_anims = {}
local current_eid
local imgui_message
local current_anim_name
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
    event_dirty = true,
    current_event_list = {}
}

local current_event = {name = ""}
local event_type = {
    "Effect", "Sound", "Collision", "Message"
}
local function set_current_anim(anim_name)
    current_anim_name = anim_name
    current_anim = ozz_anims[current_eid][anim_name]
    anim_state.anim_name = current_anim.name
    anim_state.key_event = current_anim.key_event
    anim_state.duration = current_anim.duration
end


local function from_runtime_event(runtime_event)
    local key_event = {}
    for _, ev in ipairs(runtime_event) do
        key_event[tostring(math.floor(ev.time * sample_ratio))] = ev.events
    end
    return key_event
end

local function to_runtime_event()
    if not world[current_eid].keyframe_events or not world[current_eid].keyframe_events[current_anim_name] then
        iani.set_event(current_eid, current_anim_name, {})
    end
    local runtime_event = world[current_eid].keyframe_events[current_anim_name]
    for i in pairs(runtime_event) do
        runtime_event[i] = nil
    end
    local temp = {}
    for key, value in pairs(current_anim.key_event) do
        if #value > 0 then
            temp[#temp + 1] = tonumber(key)
        end
    end
    table.sort(temp, function(a, b) return a < b end)
    for i, frame_idx in ipairs(temp) do
        runtime_event[#runtime_event + 1] = {
            time = frame_idx / sample_ratio,
            events = current_anim.key_event[tostring(frame_idx)]
        }
    end
end

local function set_event_dirty(num)
    anim_state.event_dirty = num
    if num ~= 0 then
        to_runtime_event()
    end
end

local function add_event(et)
    local event_list = anim_state.current_event_list
    event_list[#event_list + 1] = { event_type = et, name = et..tostring(#event_list)}
    -- event_list[#event_list].edit_text.text = event_list[#event_list].name
    -- event_list[#event_list].edit_text.hint = event_list[#event_list].hint
    set_event_dirty(1)
end

local function delete_event(idx)
    if not idx then return end
    table.remove(anim_state.current_event_list, idx)
    set_event_dirty(1)
end

local function clear_event()
    current_anim.key_event[tostring(selected_frame)] = {}
    anim_state.current_event_list = current_anim.key_event[tostring(selected_frame)]
    set_event_dirty(1)
end

-- local function get_event_index_by_frame(frameindex)
--     local time = frameindex / 30.0
--     for idx, ev in ipairs(anim_state.key_event) do
--         if math.abs(ev.time - time) < 0.001 then
--             return idx
--         end 
--     end
--     return 0
-- end

function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    for _ in uiutils.imgui_windows("Animation", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
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
            if imgui.widget.Button("LoadEvent") then
                local stringify     = import_package "ant.serialize".stringify
                local testtabe = {
                    {
                        time = 0.1,
                        events = {
                            {
                                name = "event_0",
                                event_type = "Message"
                            },
                            {
                                name = "event_1",
                                event_type = "Sound"
                            }
                        }
                    },
                    {
                        time = 0.5,
                        events = {
                            {
                                name = "event_2",
                                event_type = "Collision"
                            },
                            {
                                name = "event_3",
                                event_type = "Effect"
                            }
                        }
                    }
                }
                local filename = "/pkg/tools.prefab_editor/res/event/test.event"
                utils.write_file(filename, stringify(testtabe))
                iani.set_event(current_eid, current_anim_name, filename)

                current_anim.key_event = from_runtime_event(world[current_eid].keyframe_events[current_anim_name])
                set_event_dirty(-1)
            end
            imgui.cursor.SameLine()
            imgui.widget.Text(string.format("CurrentTime: %.2f/%.2f(s) CurrentFrame: %d", anim_state.current_time, anim_state.duration, math.floor(anim_state.current_time * 30)))
            imgui_message = {}
            imgui.widget.Sequencer(ozz_anims[current_eid], anim_state, imgui_message)
            set_event_dirty(0)
            local moving
            local old_selected_frame = selected_frame
            for k, v in pairs(imgui_message) do
                if k == "pause" then
                    current_anim.ozz_anim:pause(true)
                    current_anim.ozz_anim:set_time(v)
                elseif k == "selected_frame" then
                    selected_frame = v
                elseif k == "moving" then
                    moving = true
                end
            end
            if selected_frame ~= old_selected_frame then
                local newkey = tostring(selected_frame)
                if moving then
                    local oldkey = tostring(old_selected_frame)
                    current_anim.key_event[newkey] = current_anim.key_event[oldkey]
                    current_anim.key_event[oldkey] = {}
                    to_runtime_event()
                else
                    if not current_anim.key_event[newkey] then
                        current_anim.key_event[newkey] = {}
                    end
                    anim_state.current_event_list = current_anim.key_event[newkey]
                end
            end
            imgui.cursor.Separator()
            imgui.deprecated.Columns(4, "EventColumns", true)
            local child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##EventEditorColumn0", child_width, child_height, false)
            imgui.widget.Text(string.format("SelectedFrame: %d", selected_frame))
            imgui.widget.Text(string.format("SelectedTime: %.2f(s)", selected_frame / 30))
            if selected_frame >= 0 then
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
            imgui.windows.EndChild()

            imgui.deprecated.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##EventEditorColumn1", child_width, child_height, false)
            if anim_state.current_event_list then
                local delete_idx
                for idx, ke in ipairs(anim_state.current_event_list) do
                    if imgui.widget.Selectable(ke.name, current_event.name == ke.name) then
                        current_event = ke
                    end
                    if current_event.name == ke.name then
                        if imgui.windows.BeginPopupContextItem(ke.name) then
                            if imgui.widget.Selectable("Delete", false) then
                                delete_idx = idx
                            end
                            if imgui.widget.Selectable("Rename", false) then
                                -- renaming = true
                                -- new_filename.text = tostring(current_file:filename())
                            end
                            imgui.windows.EndPopup()
                        end
                    end
                end
                delete_event(delete_idx)
            end
            imgui.windows.EndChild()

            imgui.deprecated.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##EventEditorColumn2", child_width, child_height, false)
            imgui.windows.EndChild()

            imgui.deprecated.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##EventEditorColumn3", child_width, child_height, false)
            imgui.windows.EndChild()

            imgui.deprecated.Columns(1)
        end
    end
end

function m.bind(eid)
    if current_eid ~= eid then
        current_eid = eid
    end
    if world[eid] and world[eid].animation then
        if not ozz_anims[eid] then
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
                    -- {
                    --     ["1"] = {
                    --         {event_type = "Message", name = "event_0"},
                    --         {event_type = "Sound", name = "event_2"}
                    --     },
                    --     ["5"] = {
                    --         {event_type = "Effect", name = "event_3"},
                    --         {event_type = "Collision", name = "event_4"}
                    --     }
                    -- }
                }
                animation_list[#animation_list + 1] = key
            end
            set_current_anim(ozz_anims[eid].birth)
        end
    end
end

function m.add_animation(anim_name)

end

return function(w, am)
    world = w
    icons = require "common.icons"(am)
    iani = world:interface "ant.animation|animation"
    return m
end