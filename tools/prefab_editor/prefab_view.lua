local queue = require "queue"

local scene = {root = {eid = -1, parent = -1, children = {}}, all = {}}

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
function scene:add(ineid, inpeid)
    local node = { eid = ineid, parent = inpeid, children = {} }
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
    self.root = {eid = -1, parent = -1, children = {}}
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

return scene