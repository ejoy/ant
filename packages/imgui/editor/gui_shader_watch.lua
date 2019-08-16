local dbgutil       = import_package "ant.editor".debugutil
local GuiBase       = require "gui_base"
local scene         = import_package "ant.scene".util
local ru            = import_package "ant.render".util
local bgfx = require "bgfx"
local fs = require "filesystem"
local pm = require "antpm"
local vfs           = require "vfs"

local GuiShaderWatch = GuiBase.derive("GuiShaderWatch")
GuiShaderWatch.GuiName = "GuiShaderWatch"

local file_watch_mgr = require "tools.file_watch_mgr"

local function try_load_shader( pkg_path)
    vfs.clean_build(pkg_path:string())
    local f = fs.open(pkg_path,"rb")
    local data = f:read("a")
    f:close()
    assert(data)
    local s, h = dbgutil.try(bgfx.create_shader,data)
    if s and h then
        bgfx.destroy(h)
        log(string.format("Shader compiled successfully:%s",pkg_path:string()))
    else
        log(string.format("Shader compiled failed:%s,set log",pkg_path:string()))
    end
end

function GuiShaderWatch:_init()
    GuiBase._init(self)
    self.last_filepath = nil
    self.last_time = 0
    self.watch = {}
    self.watch_num = 0
end

function GuiShaderWatch:on_gui()
    local packages = pm.get_pkg_list()
    if #packages ~= self.watch_num then
        local cb = function(typ,pkgpath)
            self:on_shader_change(typ,pkgpath)
        end
        for k,v in ipairs(packages) do
            local pkg_name = string.format("/pkg/%s/",v)
            if not self.watch[pkg_name] then
                local id = file_watch_mgr:add_pkg_path_watch(pkg_name,cb)
                self.watch[pkg_name] = id
            end
        end
        self.watch_num = #packages
    end
end

local TypeLoadFunc = {
    [".sc"] = try_load_shader,
}

function GuiShaderWatch:on_shader_change(typ,pkgpath)
    if typ ~= "delete" then
        local pkgpath_s = pkgpath:string()
        for postfix,load_func in pairs(TypeLoadFunc) do
            local postfix_len = #postfix
            if string.sub(pkgpath_s,-1*postfix_len,-1) == postfix then
                local now = os.clock()
                if self.last_filepath == pkgpath:string() and ( (now - self.last_time)<1.0) then
                    return
                end
                self.last_time = now
                self.last_filepath = pkgpath:string()
                load_func(pkgpath)
                break
            end
        end
    end
end




return GuiShaderWatch