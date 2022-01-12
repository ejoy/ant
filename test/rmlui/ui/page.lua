local page_meta = {}
page_meta.__index = page_meta

function page_meta:update_view_pages()
    local vitems = {}
    local view_page_idx = self.current_page - 1
    local page_offset = -self.contain_size[1]
    local pages = self.virtual_pages
    for i = 1, 3 do
        local start_index
        local end_index
        if view_page_idx >= 1 and view_page_idx <= #pages then
            start_index = pages[view_page_idx].start_index
            end_index = pages[view_page_idx].end_index
        end
        if start_index and end_index then
            for idx = 0, end_index - start_index do
                local row = math.floor(idx/self.col)
                local col = math.fmod(idx, self.col)
                vitems[#vitems + 1] = {left = tostring(page_offset + col * self.item_size) .. 'px', top = tostring(row * self.item_size) .. 'px', data = self.data_source.items[start_index + idx]}
            end
        end
        page_offset = page_offset + self.contain_size[1]
        view_page_idx = view_page_idx + 1
    end
    self.data_source.view_items = vitems
end

function page_meta:update_virtual_pages(items)
    local pages = {}
    local count = #items
    local count_per_page = self.row * self.col
    local page_index = 0
    
    while count > 0 do
        local page_offset = page_index * count_per_page
        pages[#pages + 1] = {start_index = 1 + page_offset, end_index = (count > count_per_page) and (page_offset + count_per_page) or (page_offset + count)}
        page_index = page_index + 1
        count = count - count_per_page
    end
    self.virtual_pages = pages
    self.data_source.virtual_pages = pages
end

function page_meta.create(size, source)
    local item_size = source.item_size
    local page = {
        current_page = 1,
        contain_size = size or {0,0},
        item_size    = item_size,
        col          = math.floor(size[1] / item_size),
        row          = math.floor(size[2] / item_size),
        pos          = 0,
        drag         = {mouse_pos = 0, anchor = 0, delta = 0},
        data_source  = source,
        virtual_pages = {}
    }
    
    setmetatable(page, page_meta)
    page:update_virtual_pages(source.items)
    page:update_view_pages()
    return page
end

function page_meta:set_contain_size(size)
    self.contain_size = size
end

function page_meta:get_current_page()
    return self.current_page
end

function page_meta:on_mousedown(event)
    self.drag.mouse_pos = event.x
    -- self.pos = -self.contain_size[1]
    -- event.current.style.left = tostring(self.pos) .. 'px'
    self.drag.anchor = self.pos
end

function page_meta:on_mouseup(event)
    local page_change = false
    if self.drag.delta < -100 then
        self.current_page = self.current_page + 1
        if self.current_page > #self.virtual_pages then
            self.current_page = #self.virtual_pages
        end
        page_change = true
    elseif self.drag.delta > 100 then
        self.current_page = self.current_page - 1
        if self.current_page < 1 then
            self.current_page = 1
        end
        page_change = true
    end
    self:update_view_pages()
    self.pos = 0--self.contain_size[1]
    event.current.style.left = tostring(self.pos) .. 'px'
    return page_change
end

function page_meta:on_drag(event)
    if event.button then
        self.drag.delta = event.x - self.drag.mouse_pos
        self.pos = self.drag.anchor + self.drag.delta
        event.current:setPropertyImmediate("left", tostring(math.floor(self.pos)) .. 'px')
    end
end

return page_meta