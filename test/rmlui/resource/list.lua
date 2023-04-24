-- local platform = require 'bee.platform'
local list_meta = {}
list_meta.__index = list_meta

function list_meta.create(document, e, item_init, item_update, detail_renderer, data_for)
    local list = {
        direction   = tonumber(e.getAttribute("direction")),
        width       = e.getAttribute("width"),
        height      = e.getAttribute("height"),
        item_count  = 0,
        pos         = 0,
        drag        = {mouse_pos = 0, anchor = 0, delta = 0},
        item_init   = item_init,
        item_update = item_update,
        detail_renderer = detail_renderer,
        document    = document,
        data_for    = data_for
    }
    setmetatable(list, list_meta)
    e.style.overflow = 'hidden'
    e.style.width = list.width
    e.style.height = list.height
    local panel
    if data_for then
        panel = item_init()
    else
        panel = document.createElement "div"
        list.item_map = {}
        list.index_map = {}
    end
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
    panel.addEventListener('mousedown', function(event) list:on_mousedown(event) end)
    panel.addEventListener('mousemove', function(event) list:on_drag(event) end)
    panel.addEventListener('mouseup', function(event) list:on_mouseup(event) end)
    e.appendChild(panel)
    list.panel = panel
    list.view = e
    list:on_dirty_all(0)
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
function list_meta:reset_position()
    self.pos = 0
    local oldClassName = self.panel.className
    self.panel.className = self.panel.className .. " notransition"
    if self.direction == 0 then
        self.panel.style.left = '0px'
    else
        self.panel.style.top = '0px'
    end
    self.panel.className = oldClassName
end

function list_meta:on_dirty(index)
    if index > 0 and index <= #self.index_map then
        self.item_update(self.index_map[index].item, index)
    end
end

function list_meta:create_item(index)
    local item = self.document.createElement "div"
    self.item_init(item, index)
    self.panel.appendChild(item)
    local item_info = {index = index, detail = false, item = item}
    self.item_map[item] = item_info
    self.index_map[#self.index_map + 1] = item_info
end

function list_meta:on_dirty_all(item_count)
    if self.data_for then
        return
    end
    local total_item_count = #self.index_map
    for new_idx = total_item_count + 1, item_count do
        self:create_item(new_idx)
    end
    local index_map = {}
    for index = 1, item_count do
        local item = self.index_map[index].item
        self.item_update(item, index)
        index_map[#index_map + 1] = self.index_map[index]
    end
    for empty_idx = item_count + 1, total_item_count do
        local item = self.index_map[empty_idx].item
        self.item_map[item] = nil
        self.panel.removeChild(item)
    end
    self.index_map = index_map
    self.item_count = item_count
end

function list_meta:show_detail(it, show)
    if not self.index_map or not self.item_map then
        return
    end
    local iteminfo
    if type(it) == "number" then
        iteminfo = self.index_map[it]
    else
        iteminfo = self.item_map[it]
    end
     
    if not iteminfo then
        return
    end
    if show then
        if not iteminfo.detail then
            self.detail = self.detail_renderer(iteminfo.index)
            iteminfo.item.parentNode.appendChild(self.detail, iteminfo.index)
            iteminfo.detail = true
        end
    else
        if iteminfo.detail and self.detail then
            local parent = self.detail.parentNode
            parent.removeChild(self.detail)
            self.detail = nil
            iteminfo.detail = false
        end
    end
end

function list_meta:on_mousedown(event)
    if not self.item_width then
        local childNodes = self.panel.childNodes
        self.item_count = #childNodes
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
    self.oldClassName = self.panel.className
    self.panel.className = self.panel.className .. " notransition"
end

function list_meta:on_mouseup(event)
    local item_count = self.item_count
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
    self.panel.className = self.oldClassName
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
        if self.direction == 0 then
            e.style.left = tostring(math.floor(self.pos)) .. 'px'
        else
            e.style.top = tostring(math.floor(self.pos)) .. 'px'
        end
    end
end

return list_meta