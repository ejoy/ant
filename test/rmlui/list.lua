-- local platform = require 'bee.platform'
local list_meta = {}
list_meta.__index = list_meta

function list_meta.create(document, e, raw_items, item_renderer, detail_renderer)
    local list = {
        direction   = tonumber(e.getAttribute("direction")),
        width       = e.getAttribute("width"),
        height      = e.getAttribute("height"),
        raw_items  = raw_items,
        pos         = 0,
        drag        = {mouse_pos = 0, anchor = 0, delta = 0},
        item_renderer = item_renderer,
        detail_renderer = detail_renderer,
        document        = document,
    }
    setmetatable(list, list_meta)
    e.style.overflow = 'hidden'
    e.style.width = list.width
    e.style.height = list.height
    local panel = item_renderer()
    panel.className = "liststyle"
    panel.style.width = list.width
    if list.direction == 0 then
        panel.style.height = '100%'--list.height
        panel.style.flexDirection = 'row'
    else
        panel.style.width = '100%'--list.width
        panel.style.flexDirection = 'column'
    end
    panel.style.alignItems = 'center'
    panel.style.justifyContent = 'flex-start'
    -- if platform.OS == "Windows" then
        panel.addEventListener('mousedown', function(event) list:on_mousedown(event) end)
        panel.addEventListener('mousemove', function(event) list:on_drag(event) end)
        panel.addEventListener('mouseup', function(event) list:on_mouseup(event) end)
    -- else
        -- panel.addEventListener('touchstart', function(event) list:on_mousedown(event) end)
        -- panel.addEventListener('touchmove', function(event) list:on_drag(event) end)
        -- panel.addEventListener('touchend', function(event) list:on_mouseup(event) end)
    -- end
    e.appendChild(panel)
    list.panel = panel
    list.view = e
    return list
end

-- function list_meta:set_selected(item)
--     if self.selected == item then
--         return false
--     end
--     self.selected = item
--     return true
-- end

-- function list_meta:get_selected()
--     return self.selected
-- end

-- function list_meta:get_item(index)
--     return self.index_map[index].item
-- end

-- function list_meta:set_list_size(width, height)
--     self.width = width
--     self.height = height
--     self:on_dirty()
-- end

-- function list_meta:set_item_count(count)
--     self.item_count = count
--     self:on_dirty()
-- end
-- function list_meta:show_detail(it, show)
--     local iteminfo
--     if type(it) == "number" then
--         iteminfo = self.index_map[it]
--     else
--         iteminfo = self.item_map[it]
--     end
     
--     if not iteminfo then
--         return
--     end
--     if show then
--         if not iteminfo.detail then
--             self.detail = self.detail_renderer(iteminfo.index)
--             iteminfo.item.parentNode.appendChild(self.detail, iteminfo.index)
--             iteminfo.detail = true
--         end
--     else
--         if iteminfo.detail and self.detail then
--             local parent = self.detail.parentNode
--             parent.removeChild(self.detail)
--             self.detail = nil
--             iteminfo.detail = false
--         end
--     end
-- end
function list_meta:on_mousedown(event)
    if not self.item_width then
        local childNodes = self.panel.childNodes
        for _, it in ipairs(childNodes) do
            if not self.item_width then
                self.item_width = it.clientWidth
                self.item_height = it.clientHeight
                break
            end
        end
    end
    local pos = ((self.direction == 0) and event.x or event.y)
    if not pos and event.targetTouches and #event.targetTouches > 0 then
        pos = (self.direction == 0) and event.targetTouches[1].x or event.targetTouches[1].y
    end
    self.drag.mouse_pos = pos
    self.drag.anchor = self.pos
end

function list_meta:on_mouseup(event)
    local item_count = #self.raw_items
    local min = (self.direction == 0) and (self.view.clientWidth - item_count * self.item_width) or (self.view.clientHeight - item_count * self.item_height)
    if min > 0 then
        min = 0
    end
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
    local pos = (self.direction == 0) and event.x or event.y
    if not pos and event.targetTouches and #event.targetTouches > 0 then
        pos = (self.direction == 0) and event.targetTouches[1].x or event.targetTouches[1].y
    end
    if event.button or event.targetTouches then
        self.drag.delta = pos - self.drag.mouse_pos
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