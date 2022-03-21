local list_meta = {}
list_meta.__index = list_meta

function list_meta.create(direction, size, item_count, item_size)
    local list = {
        direction   = direction or 0,
        contain_size = size or {0,0},
        item_count  = item_count or 0,
        item_size   = item_size or {0,0},
        pos         = 0,
        drag        = {mouse_pos = 0, anchor = 0, delta = 0}
    }
    setmetatable(list, list_meta)
    return list
end

function list_meta:set_contain_size(size)
    self.contain_size = size
end

function list_meta:set_item_count(count)
    self.item_count = count
end

function list_meta:set_item_size(size)
    self.item_size = size
end

function list_meta:on_mousedown(event)
    self.drag.mouse_pos = ((self.direction == 0) and event.x or event.y)
    self.drag.anchor = self.pos
end

function list_meta:on_mouseup(event)
    local min = (self.direction == 0) and (self.contain_size[1] - self.item_count * self.item_size[1]) or (self.contain_size[2] - self.item_count * self.item_size[2])
    local adjust = false
    if self.pos > 0 then
        self.pos = 0
        adjust = true  
    elseif self.pos < min then
        self.pos = min
        adjust = true
    end
    if adjust then
        if self.direction == 0 then
            event.current.style.left = tostring(self.pos) .. 'px'
        else
            event.current.style.top = tostring(self.pos) .. 'px'
        end
    end
end

function list_meta:on_drag(event)
    if event.button then
        self.drag.delta = ((self.direction == 0) and event.x or event.y) - self.drag.mouse_pos
        self.pos = self.drag.anchor + self.drag.delta
        local e = event.current
        local oldClassName = e.className
        e.className = e.className .. " notransition"
        if self.direction == 0 then
            e.style.left = tostring(math.floor(self.pos)) .. 'px'
        else
            e.style.top = tostring(math.floor(self.pos)) .. 'px'
        end
        e.className = oldClassName
    end
end

return list_meta