local page_meta = {}
page_meta.__index = page_meta

function page_meta.create(size, count)
    local page = {
        current_page = 1,
        contain_size = size or {0,0},
        page_count   = count or 0,
        pos          = 0,
        drag         = {mouse_pos = 0, anchor = 0, delta = 0}
    }
    setmetatable(page, page_meta)
    return page
end

function page_meta:set_contain_size(size)
    self.contain_size = size
end

function page_meta:set_page_count(count)
    self.page_count = count
end

function page_meta:get_current_page()
    return self.current_page
end

function page_meta:on_mousedown(event)
    self.drag.mouse_pos = event.x
    self.drag.anchor = self.pos
end

function page_meta:on_mouseup(event)
    local page_change = false
    if self.drag.delta < -100 then
        self.current_page = self.current_page + 1
        if self.current_page > self.page_count then
            self.current_page = self.page_count
        end
        page_change = true
    elseif self.drag.delta > 100 then
        self.current_page = self.current_page - 1
        if self.current_page < 1 then
            self.current_page = 1
        end
        page_change = true
    end
    self.pos = (1 - self.current_page) * self.contain_size[1]
    event.current.style.left = tostring(self.pos) .. 'px'
    --local left_percent = tostring(self.pos/self.page_width*100) .. '%'
    --event.current.style.left = left_percent
    return page_change
end

function page_meta:on_drag(event)
    if event.button then
        self.drag.delta = event.x - self.drag.mouse_pos
        self.pos = self.drag.anchor + self.drag.delta
        event.current:setPropertyImmediate("left", tostring(math.floor(self.pos)) .. 'px')
        --local left_percent = tostring(self.pos/self.page_width*100) .. '%'
        --event.current:setPropertyImmediate("left", left_percent)
    end
end

return page_meta