local queue = require "queue"
local utils = require "common.utils"
local math3d = require "math3d"

local hierarchy = {
    root = {eid = -1, parent = -1, template = {}, children = {}, locked = {false}, visible = {true}},
    all = {},
    select_adapter = {},
    select_adaptee = {}
}

function hierarchy:set_root(eid)
    self.root.eid = eid
    self.all[eid] = self.root
end

local function find(t, eid)
    for i, v in ipairs(t) do
        if v.eid == eid then
            return i
        end
    end
    return nil
end
function hierarchy:add(ineid, tp, inpeid)
    local node = { eid = ineid, parent = inpeid, template = tp, children = {}, locked = {false}, visible = {true} }
    if inpeid then
        local parent = self.all[inpeid]
        if parent then
            table.insert(parent.children, node)
        else
            print("parent not exist.", inpeid)
            return
        end
    else
        table.insert(self.root.children, node)
    end
    self.all[ineid] = node
    return node
end

function hierarchy:replace(old_eid, new_eid)
    local node = { eid = new_eid, parent = self.all[old_eid].parent, template = self.all[old_eid].template, children = self.all[old_eid].children, locked = {false}, visible = {true} }
    local parent_node
    if node.parent then
        parent_node = self.all[node.parent]
    else
        parent_node = self.root
    end
    local idx = find(parent_node.children, old_eid)
    if idx then
        parent_node.children[idx] = node
    end
    for _, v in ipairs(node.children) do
        v.parent = node
    end
    self.all[old_eid] = nil
    self.all[new_eid] = node
    return node
end

function hierarchy:del(eid)
    if not eid then return end
    local eid_node = self.all[eid]
    if not eid_node then return end

    local pt
    if eid_node.parent then
        pt = self.all[eid_node.parent].children
    else
        pt = self.root.children
    end
    local idx = find(pt, eid)
    if idx then
        table.remove(pt, idx)
    end
    self.all[eid] = nil
    return eid_node
end

function hierarchy:clear()
    self.root = {eid = -1, parent = -1, template = {}, children = {}, locked = {false}, visible = {true}}
    self.all = {}
    self.select_adapter = {}
    self.select_adaptee = {}
end

function hierarchy:set_parent(eid, peid)
    local eid_node = self.all[eid]
    local peid_node = self.all[peid]
    if (not eid_node) or (not peid_node) or (eid_node.parent == peid) then return end
    local removed_node = self:del(eid)
    removed_node.parent = peid
    table.insert(peid_node.children, removed_node)
    self.all[eid] = removed_node
end

function hierarchy:update_prefab_template()
    local prefab_template = {}
    local function construct_entity(eid, pt)
        local templ = self.all[eid].template.template
        if templ and templ.data and templ.data.collider then
            local templ_copy = utils.deep_copy(templ)
            templ_copy.data.color = nil
            templ_copy.data.mesh = nil
            templ_copy.data.material = nil
            templ_copy.data.state = nil
            templ_copy.policy = {
                "ant.general|name",
                "ant.scene|hierarchy_policy",
                "ant.scene|transform_policy",
                "ant.collision|collider_policy"
            }
            table.insert(pt, templ_copy)
        else
            table.insert(pt, self.all[eid].template.template)
        end
        
        local pidx = (#pt < 1) and "root" or #pt
        local keyframe_templ = self.all[eid].template.keyframe
        if keyframe_templ then
            local templ_copy = utils.deep_copy(keyframe_templ)
            for i, v in ipairs(templ_copy.data.frames) do
                local tp = math3d.totable(keyframe_templ.data.frames[i].position)
                local tr = math3d.totable(keyframe_templ.data.frames[i].rotation)
                templ_copy.data.frames[i].position = {tp[1], tp[2], tp[3]}
                templ_copy.data.frames[i].rotation = {tr[1], tr[2], tr[3], tr[4]}
            end
            table.insert(pt, templ_copy)
        end
        local prefab_filename = self.all[eid].template.filename
        if prefab_filename then
            table.insert(pt, {args = {root = #pt}, prefab = prefab_filename})
        end
        for _, child in ipairs(self.all[eid].children) do
            if self.all[child.eid].template.template then
                self.all[child.eid].template.template.action = {mount = pidx}
            end
            construct_entity(child.eid, pt)
        end
    end
    construct_entity(self.root.eid, prefab_template)
    return prefab_template
end

function hierarchy:get_locked_uidata(eid)
    return self.all[eid].locked
end

function hierarchy:get_visible_uidata(eid)
    return self.all[eid].visible
end

function hierarchy:is_locked(eid)
    if not self.all[eid] then return false end
    return self.all[eid].locked[1]
end

function hierarchy:is_visible(eid)
    return self.all[eid].visible[1]
end

function hierarchy:set_lock(eid, b)
    self.all[eid].locked[1] = b
end

function hierarchy:set_visible(eid, b)
    self.all[eid].visible[1] = b
end

function hierarchy:get_template(eid)
    return self.all[eid] and self.all[eid].template or nil
end

function hierarchy:add_select_adapter(eid, target)
    self.select_adapter[eid] = target
    
    if not self.select_adaptee[target] then
        self.select_adaptee[target] = {}
    end
    local count = #self.select_adaptee[target]
    self.select_adaptee[target][count + 1] = eid
end

function hierarchy:get_select_adapter(eid)
    return self.select_adapter[eid] or eid
end

function hierarchy:get_select_adaptee(eid)
    return self.select_adaptee[eid] or {}
end

function hierarchy:update_display_name(eid, name)
    if not self.all[eid] then return end
    self.all[eid].display_name = (name or "") .. "(" .. eid .. ")"
end

function hierarchy:get_node(eid)
    return self.all[eid]
end

function hierarchy:update_slot_list()
    local slot_list = {["None"] = -1}
    for _, value in pairs(self.all) do
        if world[value.eid].slot then
            slot_list[value.template.template.data.name] = value.eid
        end
    end
    self.slot_list = slot_list
end

return hierarchy