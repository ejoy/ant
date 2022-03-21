local page_meta = {}
page_meta.__index = page_meta

function page_meta:update_view_pages()
    local vitems = {}
    local view_page_idx = self.current_page - 1
    local pages = self.virtual_pages
    for i = 1, 3 do
        if view_page_idx >= 1 and view_page_idx <= #pages then
            for _, item in  ipairs(pages[view_page_idx].vitems) do
                vitems[#vitems + 1] = item
            end
        end
        view_page_idx = view_page_idx + 1
    end
    self.data_source.view_items = vitems
end

function page_meta:update_virtual_pages(items)
    local vpages = {}
    local count_per_page = self.row * self.col
    local gapx = math.floor(math.fmod(self.contain_size[1], self.item_size) / (self.col + 1))
    local gapy = math.floor(math.fmod(self.contain_size[2], self.item_size) / (self.row + 1))
    self.data_source.gapx = gapx
    self.data_source.gapy = gapy
    local offset = 0
    local index = 1
    local total_item_count = #items
    local page_index = 0
    while index <= total_item_count do
        local index_offset = page_index * count_per_page
        local remain = total_item_count - index + 1
        local new_page = {
            start_index = 1 + index_offset,
            end_index = (remain > count_per_page) and (index_offset + count_per_page) or (index_offset + remain),
            vitems = {}
        }
        local current_count = new_page.end_index - new_page.start_index
        local vitems = new_page.vitems
        for idx = 0, current_count do
            local row = math.floor(idx/self.col)
            local col = math.fmod(idx, self.col)
            vitems[#vitems + 1] = {
                left = offset + col * (self.item_size + gapx) + gapx,
                top = row * (self.item_size + gapy) + gapy,
                row = row,
                data = items[index + idx]
            }
        end
        vpages[#vpages + 1] = new_page
        offset = offset + self.contain_size[1]
        page_index = page_index + 1
        index = index + count_per_page
    end
    self.virtual_pages = vpages
    self.data_source.virtual_pages = vpages
end

function page_meta.create(size, source)
    local item_size = source.item_size
    local row = math.floor(size[2] / item_size)
    source.row_count = row
    local page = {
        current_page = 1,
        contain_size = size or {0,0},
        item_size    = item_size,
        col          = math.floor(size[1] / item_size),
        row          = row,
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
    self.drag.anchor = self.pos
end

function page_meta:on_mouseup(event)
    local old_value = self.current_page
    if self.drag.delta < -100 then
        self.current_page = self.current_page + 1
        if self.current_page > #self.virtual_pages then
            self.current_page = #self.virtual_pages
        end
    elseif self.drag.delta > 100 then
        self.current_page = self.current_page - 1
        if self.current_page < 1 then
            self.current_page = 1
        end
    end
    if old_value ~= self.current_page then
        self:update_view_pages()
    end
    self.pos = (1 - self.current_page) * self.contain_size[1]
    event.current.style.left = tostring(self.pos) .. 'px'
    return old_value ~= self.current_page
end

function page_meta:on_drag(event)
    if event.button then
        self.drag.delta = event.x - self.drag.mouse_pos
        self.pos = self.drag.anchor + self.drag.delta
        --event.current:setPropertyImmediate("left", tostring(math.floor(self.pos)) .. 'px')
        local e = event.current
        local oldClassName = e.className
        e.className = e.className .. " notransition"
        e.style.left = tostring(math.floor(self.pos)) .. 'px'
        e.className = oldClassName
        self.data_source.draging = true
    else
        self.drag.delta = 0
    end
end

return page_meta