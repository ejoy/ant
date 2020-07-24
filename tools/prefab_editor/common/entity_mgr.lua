local entity_mgr = {
    current_eid = nil,
    entitys = {}
}

function entity_mgr:get_locked_uidata(eid)
    return self.entitys[eid].locked
end

function entity_mgr:get_visible_uidata(eid)
    return self.entitys[eid].visible
end

function entity_mgr:is_locked(eid)
    return self.entitys[eid].locked[1]
end

function entity_mgr:is_visible(eid)
    return self.entitys[eid].visible[1]
end

function entity_mgr:set_lock(eid, b)
    self.entitys[eid].locked[1] = b
end

function entity_mgr:set_visible(eid, b)
    self.entitys[eid].visible[1] = b
end

function entity_mgr:set_current_entity(eid)
    self.current_eid = eid
end
function entity_mgr:get_current_entity()
    return self.current_eid
end

function entity_mgr:add_entity(eid, prefab)
    self.entitys[eid] = {template = prefab, locked = {false}, visible = {true} }
end

return entity_mgr