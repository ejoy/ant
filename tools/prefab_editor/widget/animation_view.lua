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
            col.joint_name = col.joint_index > 0 and ske:joint_name(col.joint_index) or "None"
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
                if e.event_type == "Effect" or e.event_type == "Sound"  then
                    e.rid_ui = {e.rid}
                end
                if e.event_type == "Collision" then
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

local function get_runtime_events()
    if not world[current_eid].keyframe_events or not world[current_eid].keyframe_events[current_anim_name] then
        iani.set_event(current_eid, current_anim_name, {})
    end
    return world[current_eid].keyframe_events[current_anim_name]
end

local function to_runtime_event()
    local runtime_event = get_runtime_events()
    -- for i in pairs(runtime_event) do
    --     runtime_event[i] = nil
    -- end
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
        name_ui = {text = event_name},
        res_id_ui = {-1}
    }
    if et == "Collision" then
        event_list[#event_list].collision = {
            collider = current_collider,--find_collider_index(current_collider),
            offset = {position = {0,0,0}, rotate = {0,0,0}},
            enable = false,
            enable_ui = {false},
            offset_ui = {position = {0,0,0,speed = 0.01}, rotate = {0,0,0,speed = 0.01}},
        }
    end
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
local collider_idx = 1
local function add_collider(ct)
    if #current_anim.collider >= collider_idx then
        collider_idx = #current_anim.collider + 1
    end 
    if ct == "capsule" then return end
    if not current_anim.collider then
        current_anim.collider = {}
    end
    local shape = {type = ct, define = utils.deep_copy(default_collider_define[ct])}
    local colname = "collider" .. collider_idx
    current_anim.collider[#current_anim.collider + 1] = {
        hid = 0,
        name = colname,
        shape = shape,
        type = collider_type[1],
        joint_index = current_joint and current_joint.index or 0,
        joint_name = current_joint and current_joint.name or "",
        --
        eid = prefab_mgr:create("collider", shape),
        hid_ui = {0},
        name_ui = {text = colname},
        radius_ui = {0.025, speed = 0.01},
        height_ui = {0.025, speed = 0.01},
        halfsize_ui = {0.025, 0.025, 0.025, speed = 0.01}
    }
    collider_idx = collider_idx + 1
    local runtime_event = get_runtime_events()
    runtime_event.collider = current_anim.collider
end

local function recreate_collider(col, config)
    if config.type == "capsule" then return end
    prefab_mgr:remove_entity(col.eid)
    delete_collider(col.collider)
    col.shape = config
    col.eid = prefab_mgr:create("collider", config)
end

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
        imgui.widget.PropertyLabel("Collider")
        local collision = current_event.collision
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
    elseif current_event.event_type == "Sound" or current_event.event_type == "Effect" then
        imgui.widget.Text("AssetPath : path")
    end
end

local function show_collider()
    if not current_collider then return end

    imgui.widget.PropertyLabel("HID")
    if imgui.widget.DragInt("##HID", current_collider.hid_ui) then
        current_collider.hid = current_collider.hid_ui[1]
    end
    
    imgui.widget.PropertyLabel("Name")
    if imgui.widget.InputText("##Name", current_collider.name_ui) then
        current_collider.name = tostring(current_collider.name_ui.text)
    end

    imgui.widget.PropertyLabel("Shape")
    if imgui.widget.BeginCombo("##ColliderShapeCombo", {current_collider.shape.type, flags = imgui.flags.Combo {}}) then
        for _, option in ipairs(shape_type) do
            if imgui.widget.Selectable(option, current_collider.shape.type == option) then
                recreate_collider(current_collider, {type = option})
            end
        end
        imgui.widget.EndCombo()
    end
    imgui.widget.PropertyLabel("Type")
    if imgui.widget.BeginCombo("##ColliderTypeCombo", {current_collider.type, flags = imgui.flags.Combo {}}) then
        for _, option in ipairs(collider_type) do
            if imgui.widget.Selectable(option, current_collider.type == option) then
                current_collider.type = option
            end
        end
        imgui.widget.EndCombo()
    end

    imgui.widget.PropertyLabel("LinkJoint")
    if imgui.widget.BeginCombo("##LinkJoint", {current_collider.joint_name, flags = imgui.flags.Combo {}}) then
        for _, option in ipairs(joint_list) do
            if imgui.widget.Selectable(option.name, current_collider.joint_name == option.name) then
                current_collider.joint_index = option.index
                current_collider.joint_name = option.name
            end
        end
        imgui.widget.EndCombo()
    end

    local redefine
    if current_collider.shape.type == "sphere" or current_collider.shape.type == "capsule" then
        imgui.widget.PropertyLabel("Radius")
        local is_capsule = current_collider.shape.type == "capsule"
        if imgui.widget.DragFloat("##Radius", current_collider.radius_ui) then
            redefine = {
                origin = {0, 0, 0, 1}, radius = current_collider.radius_ui[1]
            }
        end
        if is_capsule then
            imgui.widget.PropertyLabel("Height")
            if imgui.widget.DragFloat("##Height", current_collider.height_ui) then
                redefine.height = current_collider.height_ui[1]
            end
        end
    elseif current_collider.shape.type == "box" then
        imgui.widget.PropertyLabel("HalfSize")
        if imgui.widget.DragFloat("##HalfSize", current_collider.halfsize_ui) then
            redefine = {
                origin = {0, 0, 0, 1},
                size = {
                    current_collider.halfsize_ui[1],
                    current_collider.halfsize_ui[2],
                    current_collider.halfsize_ui[3]
                }
            }
        end
    end
    if redefine then
        recreate_collider(current_collider, {type = current_collider.shape.type, define = redefine})
    end
end

local function on_select_frame(frame_idx, moving)
    if not frame_idx or selected_frame == frame_idx then return end
    local old_selected_frame = selected_frame
    selected_frame = frame_idx
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
        current_event = nil
    end
end

local current_event_file
local stringify     = import_package "ant.serialize".stringify
local widget_utils  = require "widget.utils"
local function save_event(filename)
    if not filename then
        filename = widget_utils.get_saveas_path("Event", ".event")
    end
    if not filename then return end
    local runtime_event = get_runtime_events()
    local serialize_data = {
        collider = {},
        event = {}
    }
    for _, col in ipairs(runtime_event.collider) do
        serialize_data.collider[#serialize_data.collider + 1] = {
            hid = col.hid,
            name = col.name,
            shape = col.shape,
            type = col.type,
            joint_index = col.joint_index
        }
    end
    
    local function find_collider_index(col)
        for i, c in ipairs(current_anim.collider) do
            if col == c then return i end
        end
        return 0
    end

    for _, ev in ipairs(runtime_event.event) do
        local list = {}
        for _, ev in ipairs(ev.event_list) do
            list[#list + 1] = {
                event_type = ev.event_type,
                name = ev.name,
                rid = ev.rid,
                collision = ev.collision and {
                    collider_index = find_collider_index(ev.collision.collider),
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
                local path = widget_utils.get_open_file_path("Event", ".event")
                if path then
                    --local filename = tostring(path[1])--fs.path(path[1]):localpath()
                    -- local f = assert(lfs.open(path))
                    -- local data = f:read "a"
                    -- f:close()
                    -- local events = datalist.parse(data)

                    iani.set_event(current_eid, current_anim_name, path)
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
            if imgui.widget.Button("AddCollider") then
                imgui.windows.OpenPopup("AddColliderPop")
            end
            if imgui.windows.BeginPopup("AddColliderPop") then
                for _, ct in ipairs(shape_type) do
                    if imgui.widget.MenuItem(ct) then
                        add_collider(ct)
                    end
                end
                imgui.windows.EndPopup()
            end
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
            imgui.cursor.SameLine()
            imgui.widget.Text(string.format("Selected Frame: %d Time: %.2f(s) Current Frame: %d Time: %.2f/%.2f(s)", selected_frame, selected_frame / 30, math.floor(anim_state.current_time * 30), anim_state.current_time, anim_state.duration))
            imgui_message = {}
            imgui.widget.Sequencer(ozz_anims[current_eid], anim_state, imgui_message)
            set_event_dirty(0)
            local moving
            local new_frame_idx
            for k, v in pairs(imgui_message) do
                if k == "pause" then
                    current_anim.ozz_anim:pause(true)
                    current_anim.ozz_anim:set_time(v)
                elseif k == "selected_frame" then
                    new_frame_idx = v
                elseif k == "moving" then
                    moving = true
                end
            end
            on_select_frame(new_frame_idx, moving)
            imgui.cursor.Separator()
            if imgui.table.Begin("EventColumns", 5, imgui.flags.Table {'Resizable', 'ScrollY'}) then
                imgui.table.SetupColumn("Bones", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.SetupColumn("Collider", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.SetupColumn("Collider(Detail)", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.SetupColumn("Event", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.SetupColumn("Event(Detail)", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
                imgui.table.HeadersRow()

                imgui.table.NextColumn()
                local child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##EventEditorColumn0", child_width, child_height, false)
                -- show joints
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
                show_joints(joints[current_eid].root)
                
                imgui.windows.EndChild()

                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##EventEditorColumn1", child_width, child_height, false)
                local delete_col
                if current_anim.collider then
                    for idx, col in ipairs(current_anim.collider) do
                        if imgui.widget.Selectable(col.name, current_collider and (current_collider.name == col.name)) then
                            current_collider = col
                        end
                        if current_collider and (current_collider.name == col.name) then
                            if imgui.windows.BeginPopupContextItem(col.name) then
                                if imgui.widget.Selectable("Delete", false) then
                                    delete_col = col
                                end
                                imgui.windows.EndPopup()
                            end
                        end
                    end
                    delete_collider(delete_col)
                end
                imgui.windows.EndChild()

                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##EventEditorColumn2", child_width, child_height, false)
                show_collider()
                imgui.windows.EndChild()
                
                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##EventEditorColumn3", child_width, child_height, false)
                if anim_state.current_event_list then
                    local delete_idx
                    for idx, ke in ipairs(anim_state.current_event_list) do
                        if imgui.widget.Selectable(ke.name, current_event and (current_event.name == ke.name)) then
                            current_event = ke
                            if current_event.collision then
                                gizmo:set_target(current_event.collision.collider.eid)
                            end
                        end
                        if current_event and (current_event.name == ke.name) then
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

                imgui.table.NextColumn()
                child_width, child_height = imgui.windows.GetContentRegionAvail()
                imgui.windows.BeginChild("##EventEditorColumn4", child_width, child_height, false)
                show_current_event()
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
            --joint_list[#joint_list + 1] = new_joint
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