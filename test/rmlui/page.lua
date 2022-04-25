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
    self.source.view_items = vitems
    --self.source.current_page = self.current_page - 1
    if self.footer then
        for i, child in ipairs(self.footer.childNodes) do
            child.style.backgroundImage = (i == self.current_page) and 'common/page1.png' or 'common/page0.png'
        end
    end
    if self.detail then
        self.detail.style.left = (self.current_page - 1) * self.width .. self.unit
    end
end

function page_meta:update_virtual_pages(items)
    local vpages = {}
    local count_per_page = self.row * self.col
    local gapx = math.floor(math.fmod(self.width, self.item_size) / (self.col + 1))
    local gapy = math.floor(math.fmod(self.height, self.item_size) / (self.row + 1))
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
        offset = offset + self.width
        page_index = page_index + 1
        index = index + count_per_page
    end
    self.gapx = gapx
    self.gapy = gapy
    self.virtual_pages = vpages
end
function page_meta:update_time()
    self.current_time = self.current_time + 1
end
function page_meta.create(e, source, pagefooter)
    local width = tonumber(e.getAttribute("width"))
    local height = tonumber(e.getAttribute("height"))
    local item_size = tonumber(e.getAttribute("item_size"))
    local unit = source.unit
    local page = {
        current_time = 0,
        current_page = 1,
        pos          = 0,
        draging      = false,
        interval     = 200,--按下到释放的时间小于0.5秒时显示详细信息
        page_top     = 0,
        gapx         = 0,
        gapy         = 0,
        drag         = {mouse_pos = 0, anchor = 0, delta = 0},
        virtual_pages = {},
        row          = math.floor(height / item_size),
        col          = math.floor(width / item_size),
        width        = width,
        height       = height,
        item_size    = item_size,
        detail_height = tonumber(e.getAttribute("detail_height")),
        source       = source,
        unit         = unit
    }
    setmetatable(page, page_meta)
    page:update_virtual_pages(source.items)
    page:update_view_pages()

    e.style.overflow = 'hidden'
    local panel = e.childNodes[1]
    panel.addEventListener('mousedown', function(event) page:on_mousedown(event) end)
    panel.addEventListener('mousemove', function(event) page:on_drag(event) end)
    panel.addEventListener('mouseup', function(event) page:on_mouseup(event) end)
    --page.detail = panel.getElementById "detail"
    page.view = e
    page.panel = panel
    page.view.style.width = width .. unit
    page.view.style.height = height .. unit
    page.panel.style.width = #page.virtual_pages * width .. unit
    page.panel.style.height = (height - 30) .. unit
    local footer = e.childNodes[2]
    page.footer = footer
    footer.style.flexDirection = 'row'
    footer.style.justifyContent = 'center'
    footer.style.width = '100%'
    footer.style.height = '30px'
    local page_count = #page.virtual_pages
    for i = 1, page_count do
        local newChild
        for _, child in ipairs(pagefooter.childNodes) do
            newChild = child.cloneNode()
            newChild.style.backgroundImage = (i == page.current_page) and 'common/page1.png' or 'common/page0.png'
            footer.appendChild(newChild)
        end
    end
    return page
end

function page_meta:set_size(width, height)
    self.width = width
    self.height = height
end

function page_meta:get_current_page()
    return self.current_page
end

function page_meta:on_item_down(id, row, top)
    self.item_down_time = self.current_time
end

function page_meta:do_show_detail(show, id, row, top)
    if not self.detail then
        return
    end
    console.log("do_show_detail: ", id, show)
    local offset = 0
    if show then
        self.source.selected_id = id
        self.detail.style.top = (top + self.item_size) .. self.unit
        local dy = self.height - ((row + 1) * (self.item_size + self.gapy) + self.detail_height)
        offset = (dy >= 0) and 0 or dy
    else
        self.source.selected_id = 0
    end
    self.panel.style.top = offset .. self.unit
    self.source.show_detail = show
end

function page_meta:on_item_up(id, row, top)
    if not self.detail then
        return
    end
    if self.current_time - self.item_down_time <= self.interval and not self.draging then
        console.log("old_id, current_id: ", self.source.selected_id, id)
        if self.source.selected_id ~= id then
            self:do_show_detail(true, id, row, top)
        else
            self:do_show_detail(not self.source.show_detail, id, row, top)
        end
    else
        self:do_show_detail(false, 0, 0, 0)
    end
end

function page_meta:on_mousedown(event)
    self.drag.mouse_pos = event.x
    self.drag.anchor = self.pos
    self.draging = false
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
    self.pos = (1 - self.current_page) * self.width
    self.panel.style.left = tostring(self.pos) .. self.unit
    return old_value ~= self.current_page
end

function page_meta:on_drag(event)
    if event.button then
        self.drag.delta = event.x - self.drag.mouse_pos
        self.pos = self.drag.anchor + self.drag.delta
        --event.current:setPropertyImmediate("left", tostring(math.floor(self.pos)) .. self.unit)
        local e = self.panel--event.current
        local oldClassName = e.className
        e.className = e.className .. " notransition"
        e.style.left = tostring(math.floor(self.pos)) .. self.unit
        e.className = oldClassName
        self.draging = true
    else
        self.drag.delta = 0
    end
end

return page_meta