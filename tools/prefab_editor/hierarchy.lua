local queue = require "queue"
local utils = require "common.utils"
local math3d = require "math3d"

local hierarchy = {
    root = {eid = -1, parent = -1, template = {}, children = {}, locked = {false}, visible = {true}},
    all = {},
    select_adapter = {}
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

function hierarchy:del(eid)
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

function hierarchy:update_prefab_template(prefab)
    local prefab_template = {}
    local function construct_entity(eid, pt)
        table.insert(pt, self.all[eid].template.template)
        local pidx = #pt
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
            local action = self.all[child.eid].template.template.action
            if action then
                action.mount = pidx
            end
            construct_entity(child.eid, pt)
        end
    end
    construct_entity(self.root.eid, prefab_template)
    prefab.__class = prefab_template
end

function hierarchy:get_locked_uidata(eid)
    return self.all[eid].locked
end

function hierarchy:get_visible_uidata(eid)
    return self.all[eid].visible
end

function hierarchy:is_locked(eid)
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
end

function hierarchy:get_select_adapter(eid)
    return self.select_adapter[eid] or eid
end

function hierarchy:update_display_name(eid, name)
    if not self.all[eid] then return end
    self.all[eid].display_name = name .. "(" .. eid .. ")"
end

function hierarchy:get_node(eid)
    return self.all[eid]
end

return hierarchy