-- local platform = require 'bee.platform'
local page_meta = {}
page_meta.__index = page_meta

function page_meta.create(document, e, item_init, item_update, detail_renderer, data_for)
    local row = e.getAttribute("row")
    local col = e.getAttribute("col")
    local page = {
        current_page    = 1,
        pos             = 0,
        drag            = {mouse_pos = 0, anchor = 0, delta = 0},
        row             = row and tonumber(row) or 0,
        col             = col and tonumber(col) or 0,
        width           = e.getAttribute("width"),
        height          = e.getAttribute("height"),
        item_init       = item_init,
        item_update     = item_update,
        detail_renderer = detail_renderer,
        document        = document,
        data_for        = data_for
    }
    setmetatable(page, page_meta)
    e.style.overflow = 'hidden'
    e.style.width = page.width
    local panel
    if data_for then
        panel = item_init()
    else
        panel = document.createElement "div"
    end
    e.appendChild(panel)
    panel.className = "pagestyle"
    panel.className = panel.className .. " notransition"
    -- panel.addEventListener('mousedown', function(event) page:on_mousedown(event) end)
    -- panel.addEventListener('mousemove', function(event) page:on_drag(event) end)
    -- panel.addEventListener('mouseup', function(event) page:on_mouseup(event) end)
    panel.addEventListener('pan', function(event) page:on_pan(event) end)
    panel.style.height = page.height
    panel.style.flexDirection = 'row'
    panel.style.alignItems = 'flex-start'
    panel.style.justifyContent = 'flex-start'
    page.panel = panel

    local footer = document.createElement "div"
    e.appendChild(footer)
    page.footer = footer
    footer.style.flexDirection = 'row'
    footer.style.justifyContent = 'center'
    footer.style.width = '100%'
    footer.style.height = e.getAttribute("footerheight")
    return page
end

function page_meta:update_footer_status()
    for index, e in ipairs(self.footer.childNodes) do
        e.style.backgroundImage = (index == self.current_page) and 'common/page1.png' or 'common/page0.png'
    end
end

function page_meta:update_footer(page_count)
    local footcount = #self.footer.childNodes
    if footcount > self.page_count then
        local removenode = {}
        for i = self.page_count + 1, footcount do
            removenode[#removenode + 1] = self.footer.childNodes[i]
        end
        for _, e in ipairs(removenode) do
            self.footer.removeChild(e)
        end
    elseif footcount < self.page_count then
        for i = footcount + 1, self.page_count do
            local footitem = self.document.createElement "div"
            footitem.style.width = '20px'
            footitem.style.height = '20px'
            footitem.style.backgroundSize = 'cover'
            self.footer.appendChild(footitem)
        end
    end
    self:update_footer_status()
end

function page_meta:on_dirty(index)
    print("--------page_meta:on_dirty--------")
    if self.data_for then
        return
    end
    local map = self.index_map[index]
    self:show_detail(map.item, false)
    if self.selected == map.item then
        self.selected = nil
    end
    self.item_update(map.item, index)
    -- self.item_map[map.item] = nil
    -- local parent = self.pages[map.page].childNodes[map.row]
    -- parent.removeChild(map.item)
    -- --
    -- local new_item = self.item_renderer(map.index)
    -- self.item_map[new_item] = map
    -- map.item = new_item
    -- parent.appendChild(new_item, map.col - 1)
end

function page_meta:init(item_count)
    print("--------page_meta:init--------")
    if self.data_for then
        return
    end
    local page_count = math.ceil(item_count / (self.row * self.col))
    if self.page_count and self.page_count == page_count then
        return
    end
    self.page_count = page_count
    self.pages = {}
    self.container = {}
    self.item_map = {}
    self.index_map = {}
    self.selected = nil
    self.detail = nil
    self.current_page = 1
    for i = 1, self.page_count do
        local page_e = self.document.createElement "div"
        page_e.style.flexDirection = 'column'
        page_e.style.alignItems = 'center'
        page_e.style.justifyContent = 'flex-start'
        page_e.style.width = '100%'--self.width
        page_e.style.height = self.height
        local row = {}
        for r = 1, self.row do
            local row_e = self.document.createElement "div"
            row_e.style.width = '100%'--self.width
            row_e.style.flexDirection = 'row'
            row_e.style.alignItems = 'center'
            row_e.style.justifyContent = 'space-evenly'--'flex-start'--
            page_e.appendChild(row_e)
            row[#row + 1] = row_e
        end
        self.panel.appendChild(page_e)
        self.pages[#self.pages + 1] = page_e
        self.container[#self.container + 1] = row
    end
    local cid = 0
    local last_rid = 0
    local count_per_page = self.row * self.col
    local icount = self.page_count * count_per_page
    for index = 1, icount do
        local pid = math.ceil(index / count_per_page)
        local remain = index % count_per_page
        local page = self.container[pid]
        local rid = math.ceil((remain == 0 and count_per_page or remain) / self.col)
        if last_rid ~= rid then
            last_rid = rid
            cid = 1
        else
            cid = cid + 1
        end
        local item = self.document.createElement "div"
        local w, wu = string.match(self.width, "([0-9]+%.*[0-9]*)([%w%%]+)")
        if wu ~= '%' then
            local width = (tonumber(w) / self.col) .. wu
            item.style.width = width
            item.style.height = width
        end
        self.item_init(item, index)
        page[rid].appendChild(item)
        local item_info = {index = index, page = pid, row = rid, col = cid, item = item}
        self.item_map[item] = item_info
        self.index_map[#self.index_map + 1] = item_info
    end
    self:update_footer(page_count)
    self.inited = true
end

function page_meta:on_dirty_all(item_count)
    print("--------page_meta:on_dirty_all--------")
    if not self.inited then
        self:init(item_count)
    end
    for index = 1, item_count do
        self.item_update(self.index_map[index].item, index)
    end

    local total_item_count = #self.index_map
    for empty_idx = item_count + 1, total_item_count do
        local item = self.index_map[empty_idx].item
        item.outerHTML = ""
        item.removeEventListener('click')
        item.style.border = "0px white"
    end

    local page_count = math.ceil(item_count / (self.row * self.col))
    if self.page_count ~= page_count then
        self.page_count = page_count
        self:update_footer(page_count)
    end
    if self.current_page > self.page_count then
        self.current_page = 1
        self.panel.style.left = '0px'
    end
end

function page_meta:set_selected(item)
    if self.selected == item then
        return false
    end
    self.selected = item
    return true
end

function page_meta:get_selected()
    return self.selected
end

function page_meta:get_item_info(index)
    if self.data_for then
        return
    end
    return self.index_map[index]
end

function page_meta:get_current_page()
    return self.current_page
end

function page_meta:show_detail(item_index, show)
    if not item_index or not self.detail_renderer or not self.index_map then
        return
    end
    local map = (type(item_index) == "number") and self.index_map[item_index] or self.item_map[item_index]
    if not map then
        return
    end
    if show then
        if not map.detail then
            self.detail = self.detail_renderer(map.index)
            if self.detail then
                self.pages[map.page].appendChild(self.detail, map.row)
                map.detail = true
            end
        end
    else
        if map.detail and self.detail then
            local parent = self.detail.parentNode
            parent.removeChild(self.detail)
            self.detail = nil
            map.detail = false
        end
    end
end

function page_meta:on_pan(event)
    -- print("--------page_meta:on_pan--------")
    if self.page_count < 2 then
        return
    end
    if not self.page_width then
        self.page_width = self.panel.childNodes[1].clientWidth
    end
    local target_pos = self.pos + event.dx
    if target_pos > 0 or target_pos < (1 - self.page_count) * self.page_width - 1 then
        return
    end
    self.pos = target_pos
    local page_index = math.floor(-target_pos / self.page_width) + 1
    if page_index ~= self.current_page then
        self.current_page = page_index
        self:update_footer_status()
    end
    self.panel.style.left = tostring(math.floor(self.pos)) .. 'px'
end

-- function page_meta:on_mousedown(event)
--     local posx = event.x
--     if not posx and event.targetTouches and #event.targetTouches > 0 then
--         posx = event.targetTouches[1].x
--     end
--     self.drag.mouse_pos = posx
--     self.drag.anchor = self.pos
--     self.oldClassName = self.panel.className
--     self.panel.className = self.panel.className .. " notransition"
-- end

-- function page_meta:on_mouseup(event)
--     local old_value = self.current_page
--     if self.drag.delta < -100 then
--         self.current_page = self.current_page + 1
--         if self.current_page > self.page_count then
--             self.current_page = self.page_count
--         end
--     elseif self.drag.delta > 100 then
--         self.current_page = self.current_page - 1
--         if self.current_page < 1 then
--             self.current_page = 1
--         end
--     end
--     if old_value ~= self.current_page then
--         self:update_footer_status()
--     end
--     self.panel.className = self.oldClassName
--     if not self.panel.childNodes[1] then
--         return
--     end
--     self.pos = (1 - self.current_page) * self.panel.childNodes[1].clientWidth
--     self.panel.style.left = tostring(self.pos) .. 'px'
--     return old_value ~= self.current_page
-- end

-- function page_meta:on_drag(event)
--     local posx = event.x
--     if not posx and event.targetTouches and #event.targetTouches > 0 then
--         posx = event.targetTouches[1].x
--     end
--     if event.button or event.targetTouches then
--         self.drag.delta = posx - self.drag.mouse_pos
--         self.pos = self.drag.anchor + self.drag.delta
--         local e = self.panel
--         e.style.left = tostring(math.floor(self.pos)) .. 'px'
--     else
--         self.drag.delta = 0
--     end
-- end

return page_meta