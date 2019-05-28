local List = class("ImguiList")

function List:_init(listname)
    self.list_source = {"Empty"}
    self.title = title or "List"
end

function List:set_data(datalist,select_index,title )
    local source = setmetatable( {}, {__index=datalist}))
    source.current = select_index or 1
    self.list_source = source
    self.title = title or self.title
end

function List:update()
    widget.ListBox(string.format("%s###ImguiList",self.listname),
        self.list_source)
end

function List:get_selected()
    return self.list_source.current
end

function List:set_selected(value)
    self.list_source.current = value
end

return List