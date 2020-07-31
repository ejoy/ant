local queue = require "queue"

local scene = {
    root = {eid = -1, parent = -1, template = {}, children = {}, locked = {false}, visible = {true}},
    all = {},
    select_adapter = {}
}

function scene:set_root(eid)
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
function scene:add(ineid, tp, inpeid)
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
end

function scene:del(eid)
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
        table.remove(pt, idx, eid)
    end
    self.all[eid] = nil
    return eid_node
end

function scene:clear()
    self.root = {eid = -1, parent = -1, template = {}, children = {}, locked = {false}, visible = {true}}
    self.all = {}
end

function scene:set_parent(eid, peid)
    local eid_node = self.all[eid]
    local peid_node = self.all[peid]
    if (not eid_node) or (not peid_node) or (eid_node.parent == peid) then return end
    local removed_node = self:del(eid)
    removed_node.parent = peid
    table.insert(peid_node.children, removed_node)
    self.all[eid] = removed_node
end

function scene:get_locked_uidata(eid)
    return self.all[eid].locked
end

function scene:get_visible_uidata(eid)
    return self.all[eid].visible
end

function scene:is_locked(eid)
    return self.all[eid].locked[1]
end

function scene:is_visible(eid)
    return self.all[eid].visible[1]
end

function scene:set_lock(eid, b)
    self.all[eid].locked[1] = b
end

function scene:set_visible(eid, b)
    self.all[eid].visible[1] = b
end

function scene:get_template(eid)
    return self.all[eid] and self.all[eid].template or nil
end

function scene:add_select_adapter(eid, target)
    self.select_adapter[eid] = target
end

function scene:get_select_adapter(eid)
    return self.select_adapter[eid] or eid
end

return scene