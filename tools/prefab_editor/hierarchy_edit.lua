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
    if self.all[ineid] then return end
    local node = { eid = ineid, parent = inpeid, template = utils.deep_copy(tp), children = {}, locked = {false}, visible = {true} }
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
    -- local node = { eid = new_eid, parent = self.all[old_eid].parent, template = self.all[old_eid].template, children = self.all[old_eid].children, locked = {false}, visible = {true} }
    -- local parent_node
    -- if node.parent then
    --     parent_node = self.all[node.parent]
    -- else
    --     parent_node = self.root
    -- end
    -- local idx = find(parent_node.children, old_eid)
    -- if idx then
    --     parent_node.children[idx] = node
    -- end
    -- for _, v in ipairs(node.children) do
    --     v.parent = node
    -- end
    -- self.all[old_eid] = nil
    -- self.all[new_eid] = node
    -- return node
end

function hierarchy:del(eid)
    if not eid then return end
    local eid_node = self.all[eid]
    if not eid_node then return end

    local pt
    if eid_node.parent and self.all[eid_node.parent]then
        pt = self.all[eid_node.parent].children
    else
        pt = self.root.children
    end
    if pt then
        local idx = find(pt, eid)
        if idx then
            table.remove(pt, idx)
        end
    end
    self.all[eid] = nil
    return eid_node
end

function hierarchy:clear()
    self.root = {eid = -1, parent = -1, template = {}, children = {}, locked = {false}, visible = {true}}
    self.all = {}
    self.select_adapter = {}
    self.select_adaptee = {}
    self.collider_list = nil
    self.slot_list = nil
end

function hierarchy:set_parent(eid, peid)
    local eid_node = self.all[eid]
    local peid_node = peid and self.all[peid] or self.root
    if (not eid_node) or (not peid_node) or (eid_node.parent == peid) then return end
    local removed_node = self:del(eid)
    removed_node.parent = peid
    table.insert(peid_node.children, removed_node)
    self.all[eid] = removed_node
end

local function find_policy(t, policy)
    for i, v in ipairs(t) do
        if v == policy then
            return i
        end
    end
    return nil
end

function hierarchy:update_prefab_template(world)
    local prefab_template = {}
    local function construct_entity(eid, pt)
        if type(eid) == "table" then
            
        elseif world[eid].collider then
            return
        end
        local templ = self.all[eid].template.template
        if templ and templ.data then
            if templ.data.tag then
                local policy_name = "ant.general|tag"
                local find = find_policy(templ.policy, policy_name)
                if #templ.data.tag > 0 then
                    if not find then
                        templ.policy[#templ.policy + 1] = policy_name
                    end
                elseif find then
                    templ.data.tag = nil
                    table.remove(templ.policy, find)
                end
            end
        end
        table.insert(pt, templ)

        local pidx = #pt > 0 and #pt or nil
        local prefab_filename = self.all[eid].template.filename
        if prefab_filename then
            table.insert(pt, {mount = pidx, name = self.all[eid].template.name, editor = self.all[eid].template.editor, prefab = prefab_filename})
        end
        for _, child in ipairs(self.all[eid].children) do
            if self.all[child.eid].template.template then
                self.all[child.eid].template.template.mount = pidx
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

local function set_visible_all(nd, b)
    nd.visible[1] = b
    for _, c in ipairs(nd.children) do
        set_visible_all(c, b)
    end
end

function hierarchy:set_visible(nd, b, recursion)
    if recursion then
        set_visible_all(nd, b)
    else
        nd.visible[1] = b
    end
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
    self.all[eid].display_name = (name or "")
end

function hierarchy:get_node(eid)
    return self.all[eid]
end

function hierarchy:update_slot_list(world)
    local slot_list = {["None"] = -1}
    for _, value in pairs(self.all) do
        world.w:sync("slot?in", value.eid)
        if value.eid.slot then
            local tagname = value.template.template.data.tag
            local slot_name = #tagname > 0 and tagname[1] or ""
            slot_list[slot_name] = value.eid
        end
    end
    self.slot_list = slot_list
end

function hierarchy:update_collider_list(world)
    local collider_list = {["None"] = -1}
    for _, value in pairs(self.all) do
        world.w:sync("collider?in", value.eid)
        if value.eid.collider then
            collider_list[world[value.eid].name] = value.eid
        end
    end
    self.collider_list = collider_list
end

local function find_table(eid)
    local p = hierarchy.all[eid].parent
    local t = hierarchy.all[p].children
    for i, e in ipairs(t) do
        if e.eid == eid then
            return i, t
        end
    end
    return -1, t
end

function hierarchy:move_top(eid)
    local i, t = find_table(eid)
    if i < 2 then return end
    table.remove(t, i) 
    table.insert(t, 1, self.all[eid])
end
function hierarchy:move_up(eid)
    local i, t = find_table(eid)
    if i < 2 then return end
    table.remove(t, i) 
    table.insert(t, i - 1 , self.all[eid])
end
function hierarchy:move_down(eid)
    local i, t = find_table(eid)
    if i == #t then return end
    table.remove(t, i) 
    table.insert(t, i + 1 , self.all[eid])
end
function hierarchy:move_bottom(eid)
    local i, t = find_table(eid)
    if i == #t then return end
    table.remove(t, i)
    table.insert(t, self.all[eid])
end
return hierarchy