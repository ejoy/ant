local utils = require "common.utils"

local hierarchy = {
    root = {eid = -1, parent = -1, info = {}, children = {}, locked = {false}, visible = {true}},
    all_node = {},
    select_adapter = {},
    select_adaptee = {}
}

function hierarchy:set_root(eid)
    self.root.eid = eid
    self.all_node[eid] = self.root
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
    if self.all_node[ineid] then return end
    local node = { eid = ineid, parent = inpeid, info = tp, children = {}, locked = {false}, visible = {true} }
    if inpeid then
        local parent = self.all_node[inpeid]
        if parent then
            table.insert(parent.children, node)
        else
            print("parent not exist.", inpeid)
            return
        end
    else
        table.insert(self.root.children, node)
    end
    self.all_node[ineid] = node
    return node
end

function hierarchy:del(eid)
    if not eid then return end
    local node = self.all_node[eid]
    if not node then return end

    local pt
    if node.parent and self.all_node[node.parent]then
        pt = self.all_node[node.parent].children
    else
        pt = self.root.children
    end
    if pt then
        local idx = find(pt, eid)
        if idx then
            table.remove(pt, idx)
        end
    end
    self.all_node[eid] = nil
    return node
end

function hierarchy:clear()
    self.root = {eid = -1, parent = -1, info = {}, children = {}, locked = {false}, visible = {true}}
    self.all_node = {}
    self.select_adapter = {}
    self.select_adaptee = {}
    self.collider_list = nil
    self.slot_list = nil
end

function hierarchy:set_parent(eid, peid)
    local eid_node = self.all_node[eid]
    local peid_node = peid and self.all_node[peid] or self.root
    if (not eid_node) or (not peid_node) or (eid_node.parent == peid) then return end
    local removed_node = self:del(eid)
    removed_node.parent = peid
    table.insert(peid_node.children, removed_node)
    self.all_node[eid] = removed_node
end

function hierarchy:get_parent(eid)
    return self.all_node[eid].parent
end

function hierarchy:get_prefab_template(ispatch)
    local new_tpl = {}
    local function construct_entity(eid, tpl, patch)
        local node = self.all_node[eid]
        if not (node == self.root or node.info.scene_root) then
            if node.info.temporary or not node.info.is_patch then
                return
            end
        end
        local template = utils.deep_copy(node.info.template)
        if template then
            if template.index then
                template.index = nil
            end
            if template.filename then
                template.filename = nil
            end
            if template.replace_mtl then
                template.replace_mtl = nil
            end
            if template.data then
                if template.data.tag then
                    template.data.tag = nil
                end
                local scene = template.data.scene
                if scene and scene.parent then
                    scene.parent = nil
                end
            end
            -- if self.all_node[node.parent] == self.root then
            --     template.mount = 1
            -- end
        end
        table.insert(tpl, template)

        local pidx = #tpl > 0 and #tpl or nil
        local prefab_filename = node.info.filename
        if prefab_filename then
            -- table.insert(tpl, {mount = patch and pidx - 1 or pidx, prefab = prefab_filename})
            table.insert(tpl, {mount = pidx, prefab = prefab_filename})
        end
        for _, child in ipairs(node.children) do
            local nd = self.all_node[child.eid]
            local tt = nd.info.template
            if nd.parent ~= self.root.eid and tt then
                tt.mount = pidx
            end
            construct_entity(child.eid, tpl, patch)
        end
    end
    construct_entity(self.root.eid, new_tpl, ispatch)
    return new_tpl
end

function hierarchy:get_locked_uidata(eid)
    return self.all_node[eid].locked
end

function hierarchy:get_visible_uidata(eid)
    return self.all_node[eid].visible
end

function hierarchy:is_locked(eid)
    if not self.all_node[eid] then return false end
    return self.all_node[eid].locked[1]
end

function hierarchy:is_visible(eid)
    return self.all_node[eid].visible[1]
end

function hierarchy:set_lock(eid, b)
    self.all_node[eid].locked[1] = b
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

function hierarchy:get_node_info(e)
    return self.all_node[e] and self.all_node[e].info or nil
end

function hierarchy:clear_adapter(e)
    local ac = self.all_node[e].info.children
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
    if not self.all_node[e] then return end
    self.all_node[e].display_name = (name or "")
end

function hierarchy:get_node(e)
    return self.all_node[e]
end

function hierarchy:update_slot_list(world)
    local slot_list = {["None"] = -1}
    for _, value in pairs(self.all_node) do
        local e <close> = world:entity(value.eid, "slot?in")
        if e.slot then
            local tagname = value.info.template.tag[1]--value.template.template.data.tag--
            local slot_name = tagname--#tagname > 0 and tagname[1] or ""
            slot_list[slot_name] = value.eid
        end
    end
    self.slot_list = slot_list
    world:pub {"UpdateSlotList"}
end

local function find_table(eid)
    local p = hierarchy.all_node[eid].parent
    local t = hierarchy.all_node[p].children
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
    table.insert(t, 1, self.all_node[eid])
end
function hierarchy:move_up(eid)
    local i, t = find_table(eid)
    if i < 2 then return end
    table.remove(t, i)
    table.insert(t, i - 1 , self.all_node[eid])
end
function hierarchy:move_down(eid)
    local i, t = find_table(eid)
    if i == #t then return end
    table.remove(t, i)
    table.insert(t, i + 1 , self.all_node[eid])
end
function hierarchy:move_bottom(eid)
    local i, t = find_table(eid)
    if i == #t then return end
    table.remove(t, i)
    table.insert(t, self.all_node[eid])
end
return hierarchy