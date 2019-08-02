local dbgutil       = import_package "ant.editor".debugutil
local GuiBase       = require "gui_base"
local scene         = import_package "ant.scene".util
local ru            = import_package "ant.render".util
local bgfx = require "bgfx"
local fs = require "filesystem"

local GuiShaderWatch = GuiBase.derive("GuiShaderWatch")
GuiShaderWatch.GuiName = "GuiShaderWatch"

local file_watch_mgr = require "tools.file_watch_mgr"

local function try_load_shader( pkg_path)
    local f = fs.open(pkg_path,"rb")
    local data = f:read("a")
    f:close()
    assert(data)
    local h = dbgutil.try(bgfx.create_shader(data))
    if h then
        bgfx.destroy(h)
        log(string.format("Shader compiled successfully:%s",pkg_path:string()))
    else
        log(string.format("Shader compiled failed:%s,set log",pkg_path:string()))
    end
end

function GuiShaderWatch:_init()
    GuiBase._init(self)
    self.on_gui = false
    self.last_filepath = nil
    self.last_time = 0
    local cb = function(typ,pkgpath)
        self:on_shader_change(typ,pkgpath)
    end
    file_watch_mgr:add_pkg_path_watch("/pkg/ant.resources/shaders/src",cb)
end


function GuiShaderWatch:on_shader_change(typ,pkgpath)
    if typ ~= "delete" then
        local now = os.clock()
        if self.last_filepath == pkgpath:string() and ( (now - self.last_time)<1.0) then
            return
        end
        self.last_time = now
        self.last_filepath = pkgpath:string()
        try_load_shader(pkgpath)
    end
end



return GuiShaderWatch