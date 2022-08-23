-- local platform = require 'bee.platform'
local page_meta = {}
page_meta.__index = page_meta

function page_meta.create(document, e, raw_pages, item_renderer, detail_renderer)
    local page = {
        current_page    = 1,
        pos             = 0,
        draging         = false,
        drag            = {mouse_pos = 0, anchor = 0, delta = 0},
        width           = e.getAttribute("width"),
        height          = e.getAttribute("height"),
        raw_pages      = raw_pages,
        item_renderer   = item_renderer,
        detail_renderer = detail_renderer,
        document        = document,
    }
    setmetatable(page, page_meta)
    e.style.overflow = 'hidden'
    e.style.width = page.width
    local panel = item_renderer()
    e.appendChild(panel)
    panel.className = "pagestyle"
    -- if platform.OS == 'Windows' then
        panel.addEventListener('mousedown', function(event) page:on_mousedown(event) end)
        panel.addEventListener('mousemove', function(event) page:on_drag(event) end)
        panel.addEventListener('mouseup', function(event) page:on_mouseup(event) end)
    -- else
        -- panel.addEventListener('touchstart', function(event) page:on_mousedown(event) end)
        -- panel.addEventListener('touchmove', function(event) page:on_drag(event) end)
        -- panel.addEventListener('touchend', function(event) page:on_mouseup(event) end)
    -- end
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
    page:update_footer(#raw_pages)
    return page
end

function page_meta:update_footer_status()
    for index, e in ipairs(self.footer.childNodes) do
        e.style.backgroundImage = (index == self.current_page) and 'common/page1.png' or 'common/page0.png'
    end
end

function page_meta:update_footer(page_count)
    if self.page_count == page_count then
        return
    end
    self.page_count = page_count
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

-- function page_meta:set_selected(item)
--     if self.selected == item then
--         return false
--     end
--     self.selected = item
--     return true
-- end

-- function page_meta:get_selected()
--     return self.selected
-- end

-- function page_meta:get_item_info(index)
--     return self.index_map[index]
-- end

-- function page_meta:get_current_page()
--     return self.current_page
-- end

function page_meta:on_mousedown(event)
    local posx = event.x
    if not posx and event.targetTouches and #event.targetTouches > 0 then
        posx = event.targetTouches[1].x
    end
    self.drag.mouse_pos = posx
    self.drag.anchor = self.pos
    self.draging = false
end

function page_meta:on_mouseup(event)
    local page_count = #self.raw_pages
    local old_value = self.current_page
    if self.drag.delta < -100 then
        self.current_page = self.current_page + 1
        if self.current_page > page_count then
            self.current_page = page_count
        end
    elseif self.drag.delta > 100 then
        self.current_page = self.current_page - 1
        if self.current_page < 1 then
            self.current_page = 1
        end
    end
    if old_value ~= self.current_page then
        self:update_footer_status()
    end

    if not self.panel.childNodes[1] then
        return
    end
    self.pos = (1 - self.current_page) * self.panel.childNodes[1].clientWidth
    self.panel.style.left = tostring(self.pos) .. 'px'
    return old_value ~= self.current_page
end

function page_meta:on_drag(event)
    local posx = event.x
    if not posx and event.targetTouches and #event.targetTouches > 0 then
        posx = event.targetTouches[1].x
    end
    if event.button or event.targetTouches then
        self.drag.delta = posx - self.drag.mouse_pos
        self.pos = self.drag.anchor + self.drag.delta
        local e = self.panel
        local oldClassName = e.className
        e.className = e.className .. " notransition"
        e.style.left = tostring(math.floor(self.pos)) .. 'px'
        e.className = oldClassName
        self.draging = true
    else
        self.drag.delta = 0
    end
end

return page_meta