local imgui     = require "imgui"
local assetmgr  = import_package "ant.asset"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local vfs       = require "vfs"
local cr        = import_package "ant.compile_resource"
local datalist  = require "datalist"
local stringify = import_package "ant.serialize".stringify
local utils         = require "common.utils"
local math3d        = require "math3d"
local uiproperty    = require "widget.uiproperty"
local BaseView      = require "widget.view_class".BaseView
local MaterialView  = require "widget.view_class".MaterialView
local world
local imaterial

local mtldata_list = {

}

function MaterialView:_init()
    BaseView._init(self)
    self.mat_file       = uiproperty.ResourcePath({label = "File"})
    self.vs_file        = uiproperty.ResourcePath({label = "VS", readonly = true})
    self.fs_file        = uiproperty.ResourcePath({label = "FS", readonly = true})
    self.save_mat       = uiproperty.Button({label = "Save"})
    self.save_as_mat    = uiproperty.Button({label = "SaveAs"})
    self.samplers       = {}
    self.uniforms       = {}
    self.float_uniforms = {}
    self.color_uniforms = {}
    self.sampler_num    = 0
    self.float_uniform_num  = 0
    self.color_uniform_num  = 0
    --
    self.mat_file:set_getter(function() return self:on_get_mat() end)
    self.mat_file:set_setter(function(value) self:on_set_mat(value) end)
    self.vs_file:set_getter(function() return self:on_get_vs() end)
    self.vs_file:set_setter(function(value) self:on_set_vs(value) end)
    self.fs_file:set_getter(function() return self:on_get_fs() end)
    self.fs_file:set_setter(function(value) self:on_set_fs(value) end)
    self.save_mat:set_click(function() self:on_save_mat() end)
    self.save_as_mat:set_click(function() self:on_saveas_mat() end)
end
function MaterialView:on_set_mat(value)
    world[self.eid].material = value
end
function MaterialView:on_get_mat()
    return world[self.eid].material
end
function MaterialView:on_set_vs(value)
    mtldata_list[self.eid].tdata.fx.vs = value
end
function MaterialView:on_get_vs()
    return mtldata_list[self.eid].tdata.fx.vs
end
function MaterialView:on_set_fs(value)
    mtldata_list[self.eid].tdata.fx.fs = value
end
function MaterialView:on_get_fs()
    return mtldata_list[self.eid].tdata.fx.fs
end
function MaterialView:on_save_mat()
end
function MaterialView:on_saveas_mat()
end

local function is_sampler(str)
    return string.find(str,"s") == 1 and string.find(str,"_") == 2 
end

local function is_uniform(str)
    return string.find(str,"u") == 1 and string.find(str,"_") == 2
end

function MaterialView:get_sampler_property()
    self.sampler_num = self.sampler_num + 1
    if self.sampler_num > #self.samplers then
        self.samplers[#self.samplers + 1] = uiproperty.ResourcePath({label = ""}, {})
    end
    return self.samplers[self.sampler_num]
end

function MaterialView:get_float_uniform_property()
    self.float_uniform_num = self.float_uniform_num + 1
    if self.float_uniform_num > #self.float_uniforms then
        self.float_uniforms[#self.float_uniforms + 1] = uiproperty.Float({label = "", dim = 4, speed = 0.01, min = 0, max = 1}, {})
    end
    return self.float_uniforms[self.float_uniform_num]
end

function MaterialView:get_color_uniform_property()
    self.color_uniform_num = self.color_uniform_num + 1
    if self.color_uniform_num > #self.color_uniforms then
        self.color_uniforms[#self.color_uniforms + 1] = uiproperty.Color({label = "", dim = 4}, {})
    end
    return self.color_uniforms[self.color_uniform_num]
end

local texture_used_idx = {
    ["s_basecolor"] = 1,
    ["s_normal"]    = 2,
    ["s_occlusion"] = 3,
    ["s_emissive"]  = 4
}

function MaterialView:set_model(eid)
    if not BaseView.set_model(self, eid) then return false end

    if not mtldata_list[eid] then
        local mtl_filename = tostring(world[eid].material)
        local md = {filename = mtl_filename, tdata = datalist.parse(cr.read_file(mtl_filename))}
        local mtl_path = cr.compile(mtl_filename):remove_filename()
        for k, v in pairs(md.tdata.properties) do
            if is_sampler(k) then
                local absolute_path
                if fs.path(v.texture):is_absolute() then
                    absolute_path = v.texture
                else
                    absolute_path = tostring(mtl_path) .. v.texture 
                end
                v.tdata = utils.readtable(absolute_path)
            end
        end
        mtldata_list[eid] = md
    end

    self.sampler_num = 0
    self.uniforms = {}
    self.float_uniform_num = 0
    self.color_uniform_num = 0
    for k, v in pairs(mtldata_list[eid].tdata.properties) do
        if is_sampler(k) then
            local pro = self:get_sampler_property()
            pro:set_label(k)
            pro:set_getter(
                function()
                    -- local prop = mtldata_list[eid].tdata.properties[k]
                    -- return prop.texture
                    local prop = imaterial.get_property(eid, k)
                    if prop then
                        return prop.value.texture
                    else
                        return {}
                    end
                end
            )
            pro:set_setter(
                function(value)
                    local runtime_tex = assetmgr.resource(value)
                    local s = runtime_tex.sampler
                    local md = mtldata_list[eid]
                    if k == "s_metallic_roughness" then
                        md.tdata.properties.u_metallic_roughness_factor[4] = 1
                        imaterial.set_property(eid, "u_metallic_roughness_factor", md.tdata.properties.u_metallic_roughness_factor)
                    else
                        local used_flags = md.tdata.properties.u_material_texture_flags
                        used_flags[texture_used_idx[k]] = 1
                        imaterial.set_property(eid, "u_material_texture_flags", used_flags)
                    end
                    imaterial.set_property(eid, k, {stage = md.tdata.properties[k].stage, texture = {handle = runtime_tex._data.handle}})
                end
            )
        elseif is_uniform(k) then
            local pro
            if k == "u_color" then
                pro = self:get_color_uniform_property()
            else
                pro = self:get_float_uniform_property()
            end
            pro:set_label(k)
            pro:set_getter(
                function()
                    local prop = imaterial.get_property(eid, k)
                    return prop and math3d.totable(prop.value) or {0, 0, 0, 0}
                end
            )
            pro:set_setter(
                function(...)
                    imaterial.set_property(eid, k, {...})
                end
            )
            self.uniforms[#self.uniforms + 1] = pro
        end
    end
    self:update()
    return true
end

function MaterialView:update()
    BaseView.update(self)
    self.mat_file:update()
    self.vs_file:update()
    self.fs_file:update()

    for i = 1, self.sampler_num do
        self.samplers[i]:update()
    end
    for i = 1, #self.uniforms do
        self.uniforms[i]:update()
    end
end

function MaterialView:show()
    BaseView.show(self)
    if imgui.widget.TreeNode("Material", imgui.flags.TreeNode { "DefaultOpen" }) then
        self.mat_file:show()
        imgui.cursor.Indent()
        self.vs_file:show()
        self.fs_file:show()
        self.save_mat:show()
        imgui.cursor.SameLine()
        self.save_as_mat:show()
        imgui.cursor.Unindent()
        for i = 1, self.sampler_num do
            self.samplers[i]:show()
        end
        for i = 1, #self.uniforms do
            self.uniforms[i]:show()
        end
        imgui.widget.TreePop()
    end
end

return function(w)
    world       = w
    imaterial   = world:interface "ant.asset|imaterial"
    prefab_mgr  = require "prefab_manager"(world)
    require "widget.base_view"(world)
    return MaterialView
end