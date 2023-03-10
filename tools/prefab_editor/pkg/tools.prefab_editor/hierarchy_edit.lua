local utils = require "common.utils"

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

function hierarchy:get_parent(eid)
    return self.all[eid].parent
end

local function find_policy(t, policy)
    for i, v in ipairs(t) do
        if v == policy then
            return i
        end
    end
    return nil
end

function hierarchy:update_prefab_template()
    local raw_tpl = {}
    local patch_tpl = {}
    local function construct_entity(eid, rpt, ppt)
        local node = self.all[eid]
        if node.template.temporary then
            return
        end
        local templ = node.template.template
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
            local scene = templ.data.scene
            if scene and scene.parent then
                scene.parent = nil
            end
        end
        local cur_tp = node.template.patch and ppt or rpt
        table.insert(cur_tp, templ)

        local pidx = #cur_tp > 0 and #cur_tp or nil
        local prefab_filename = node.template.filename
        if prefab_filename then
            table.insert(cur_tp, {mount = #rpt + pidx, name = node.template.name, editor = node.template.editor, prefab = prefab_filename})
        end
        for _, child in ipairs(node.children) do
            local nd = self.all[child.eid]
            local tt = nd.template.template
            if nd.parent ~= self.root.eid and tt then
                if nd.template.patch then
                    if tt.mount and tt.mount ~= 1 then
                        tt.mount = #ppt
                    end
                else
                    tt.mount = pidx
                end
            end
            construct_entity(child.eid, rpt, ppt)
        end
    end
    construct_entity(self.root.eid, raw_tpl, patch_tpl)
    return raw_tpl, patch_tpl
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

function hierarchy:get_template(e)
    return self.all[e] and self.all[e].template or nil
end

function hierarchy:clear_adapter(e)
    local ac = self.all[e].template.children
    if ac then
        for _, child in ipairs(ac) do
            self.select_adapter[child] = nil
        end
    end
    self.select_adaptee[e] = nil
end

function hierarchy:add_select_adapter(e, target)
    self.select_adapter[e] = target
    
    if not self.select_adaptee[target] then
        self.select_adaptee[target] = {}
    end
    local count = #self.select_adaptee[target]
    self.select_adaptee[target][count + 1] = e
end

function hierarchy:get_select_adapter(e)
    return self.select_adapter[e] or e
end

function hierarchy:get_select_adaptee(e)
    return self.select_adaptee[e] or {}
end

function hierarchy:update_display_name(e, name)
    if not self.all[e] then return end
    self.all[e].display_name = (name or "")
end

function hierarchy:get_node(e)
    return self.all[e]
end

function hierarchy:update_slot_list(world)
    local slot_list = {["None"] = -1}
    for _, value in pairs(self.all) do
        local e <close> = world.w:entity(value.eid, "slot?in")
        if e.slot then
            local tagname = value.template.template.data.name--value.template.template.data.tag--
            local slot_name = tagname--#tagname > 0 and tagname[1] or ""
            slot_list[slot_name] = value.eid
        end
    end
    self.slot_list = slot_list
    world:pub {"UpdateSlotList"}
end

function hierarchy:update_collider_list(world)
    local collider_list = {["None"] = -1}
    for _, value in pairs(self.all) do
        local e <close> = world.w:entity(value.eid, "collider?in")
        if e.collider then
            collider_list[world[value.eid].name] = value.eid
        end
    end
    self.collider_list = collider_list
end

local function find_table(eid)
    local p = hierarchy.all[eid].parent
    local t = hierarchy.all[p].children
    for i, n in ipairs(t) do
        if n.eid == eid then
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