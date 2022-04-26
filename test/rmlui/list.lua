local list_meta = {}
list_meta.__index = list_meta

function list_meta.create(e, source, dirty)
    local list = {
        direction   = tonumber(e.getAttribute("direction")),
        width       = tonumber(e.getAttribute("width")),
        height      = tonumber(e.getAttribute("height")),
        item_count  = 1,
        item_width  = tonumber(e.getAttribute("item_width")),
        item_height = tonumber(e.getAttribute("item_height")),
        pos         = 0,
        drag        = {mouse_pos = 0, anchor = 0, delta = 0},
        source      = source,
        unit        = source.unit,
        dirty       = dirty
    }
    setmetatable(list, list_meta)
    e.style.overflow = 'hidden'
    local panel = e.childNodes[1]
    panel.addEventListener('mousedown', function(event) list:on_mousedown(event) end)
    panel.addEventListener('mousemove', function(event) list:on_drag(event) end)
    panel.addEventListener('mouseup', function(event) list:on_mouseup(event) end)
    list.view = e
    list.panel = panel
    list:update_size()
    return list
end

function list_meta:update_size()
    self.view.style.width = self.width .. self.unit
    self.view.style.height = self.height .. self.unit
    self.panel.style.width = self.width .. self.unit
    self.panel.style.height = self.item_count * self.item_height .. self.unit
end

function list_meta:set_list_size(width, height)
    self.width = width
    self.height = height
    self:update_size()
end

function list_meta:set_item_count(count)
    self.item_count = count
    self:update_size()
end

function list_meta:set_item_size(width, height)
    self.item_width = width
    self.item_height = height
    self:update_size()
end

function list_meta:on_mousedown(event)
    self.drag.mouse_pos = ((self.direction == 0) and event.x or event.y)
    self.drag.anchor = self.pos
end

function list_meta:on_mouseup(event)
    local min = (self.direction == 0) and (self.width - self.item_count * self.item_width) or (self.height - self.item_count * self.item_height)
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
            self.panel.style.left = tostring(self.pos) .. self.unit
        else
            self.panel.style.top = tostring(self.pos) .. self.unit
        end
    end
end

function list_meta:on_drag(event)
    if event.button then
        self.drag.delta = ((self.direction == 0) and event.x or event.y) - self.drag.mouse_pos
        self.pos = self.drag.anchor + self.drag.delta
        local e = self.panel
        local oldClassName = e.className
        e.className = e.className .. " notransition"
        if self.direction == 0 then
            e.style.left = tostring(math.floor(self.pos)) .. self.unit
        else
            e.style.top = tostring(math.floor(self.pos)) .. self.unit
        end
        e.className = oldClassName
    end
end

return list_meta