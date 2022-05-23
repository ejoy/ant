local list_meta = {}
list_meta.__index = list_meta

function list_meta.create(document, e, item_count, item_renderer)
    local list = {
        direction   = tonumber(e.getAttribute("direction")),
        width       = e.getAttribute("width"),
        height      = e.getAttribute("height"),
        item_count  = item_count,
        pos         = 0,
        drag        = {mouse_pos = 0, anchor = 0, delta = 0},
        item_renderer = item_renderer,
        items       = {},
        document    = document,
    }
    setmetatable(list, list_meta)
    e.style.overflow = 'hidden'
    local panel = document.createElement "div"
    e.appendChild(panel)
    panel.className = "liststyle"
    panel.addEventListener('mousedown', function(event) list:on_mousedown(event) end)
    panel.addEventListener('mousemove', function(event) list:on_drag(event) end)
    panel.addEventListener('mouseup', function(event) list:on_mouseup(event) end)
    list.view = e
    list.panel = panel
    list:on_dirty(item_count)
    return list
end

function list_meta:on_dirty(item_count)
    for _, e in ipairs(self.items) do
        self.panel.removeChild(e)
    end
    self.item_count = item_count or self.item_count
    self.view.style.width = self.width
    self.view.style.height = self.height
    if self.direction == 0 then
        self.panel.style.height = self.height
        self.panel.style.flexDirection = 'row'
    else
        self.panel.style.width = self.width
        self.panel.style.flexDirection = 'column'
    end
    self.panel.style.alignItems = 'center'
    self.panel.style.justifyContent = 'flex-start'
    self.items = {}
    for index = 1, self.item_count do
        local e = self.item_renderer(index)
        self.panel.appendChild(e)
        self.items[#self.items + 1] = e
    end
end

function list_meta:set_list_size(width, height)
    self.width = width
    self.height = height
    self:on_dirty()
end

function list_meta:set_item_count(count)
    self.item_count = count
    self:on_dirty()
end

function list_meta:on_mousedown(event)
    self.drag.mouse_pos = ((self.direction == 0) and event.x or event.y)
    self.drag.anchor = self.pos
end

function list_meta:on_mouseup(event)
    local min = (self.direction == 0) and (self.view.clientWidth - self.item_count * self.panel.childNodes[1].clientWidth) or (self.view.clientHeight - self.item_count * self.panel.childNodes[1].clientHeight)
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
            self.panel.style.left = tostring(self.pos) .. 'px'
        else
            self.panel.style.top = tostring(self.pos) .. 'px'
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
            e.style.left = tostring(math.floor(self.pos)) .. 'px'
        else
            e.style.top = tostring(math.floor(self.pos)) .. 'px'
        end
        e.className = oldClassName
    end
end

return list_meta