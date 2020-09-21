local imgui     = require "imgui"
local assetmgr  = import_package "ant.asset"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local vfs       = require "vfs"
local cr        = import_package "ant.compile_resource"
local rhwi      = import_package 'ant.render'.hwi
local datalist  = require "datalist"
local stringify = import_package "ant.serialize".stringify
local filedialog = require 'filedialog'
local utils     = require "common.utils"

local m = {}
local world
local imaterial
local mtldata_list = {}
local mtldata = nil

local function is_sampler(str)
    return string.find(str,"s") == 1 and string.find(str,"_") == 2 
end

local function is_uniform(str)
    return string.find(str,"u") == 1 and string.find(str,"_") == 2
end

local function readtable(filename)
    local path = fs.path(filename):localpath()
    local f = assert(lfs.open(path))
	local data = f:read "a"
	f:close()
    return datalist.parse(data)
end

function m.update_ui_data(eid)
    if world[eid].material then
        if not mtldata_list[eid] then
            local mtl_filename = tostring(world[eid].material)
            local md = {filename = mtl_filename, tdata = datalist.parse(cr.read_file(mtl_filename))}
            
            for k, v in pairs(md.tdata.properties) do
                if is_sampler(k) then
                    v.tdata = readtable(v.texture)
                end
            end

            local uidata = {
                material_file = {text = "nomaterial"},
                vs = {text = "novs"},
                fs = {text = "nofs"},
                properties = {}
            }
            md.uidata = uidata

            local tdata = md.tdata
            uidata.material_file.text = md.filename
            uidata.vs.text = tdata.fx.vs
            uidata.fs.text = tdata.fx.fs
            for k, v in pairs(tdata.properties) do
                if is_sampler(k) then
                    uidata.properties[v.stage + 1] = {{text = v.texture}, {text = v.tdata.path}, label = k}
                elseif is_uniform(k) then
                    uidata.properties[k] = {v[1], v[2], v[3], v[4], speed = 0.01, min = 0, max = 1}
                end
            end
            mtldata_list[eid] = md
        end
        mtldata = mtldata_list[eid]
    else
        mtldata = nil
    end
end

local filter_type = {"POINT", "LINEAR", "ANISOTROPIC"}
local address_type = {"WRAP", "MIRROR", "CLAMP", "BORDER"}
local combo_width = 60
local combo_flags = imgui.flags.Combo { "NoArrowButton" }
local texture_used_idx = {
    ["s_basecolor"] = 1,
    ["s_normal"] = 2,
    ["s_occlusion"] = 3,
    ["s_emissive"] = 4
}

local edit_sampler = function(eid, md)
    for idx, pro in ipairs(md.uidata.properties) do
        local k = pro.label
        local tp = md.tdata.properties[k]
        imgui.widget.Text(k..":")
        imgui.cursor.SameLine()
        imgui.cursor.PushItemWidth(-1)
        if imgui.widget.InputText("##" .. k, pro[1]) then
            -- tp.texture = tostring(pro[1].text)
            -- if string.sub(tp.texture, -8) == ".texture" then
            --     tp.tdata = datalist.parse(cr.read_file(tp.texture .. "|main.cfg"))
            --     imaterial.set_property(eid, k, assetmgr.resource(tp.texture))
            -- end
        end
        imgui.cursor.PopItemWidth()
        imgui.cursor.Indent()
        imgui.widget.Text("image:")
        imgui.cursor.SameLine()
        imgui.cursor.PushItemWidth(-1)
        if imgui.widget.InputText("##" .. tp.tdata.path .. idx, pro[2]) then
            --tp.tdata.path = tostring(pro[2].text)
        end
        imgui.cursor.PopItemWidth()
        imgui.cursor.Unindent()
        if imgui.widget.BeginDragDropTarget() then
            local payload = imgui.widget.AcceptDragDropPayload("DragFile")
            if payload then
                local rp = lfs.relative(lfs.path(payload), fs.path "":localpath())
                local pkg_path = "/pkg/ant.tools.prefab_editor/" .. tostring(rp)
                local texture_handle
                if string.sub(payload, -8) == ".texture" then
                    pro[1].text = pkg_path
                    tp.texture = pkg_path
                    tp.tdata = readtable(tp.texture)
                    local t = assetmgr.resource(tp.texture)
                    local s = t.sampler
                    texture_handle = t._data.handle
                elseif string.sub(payload, -4) == ".png"
                    or string.sub(payload, -4) == ".dds" then
                    local t = assetmgr.resource(pkg_path, { compile = true })
                    texture_handle = t.handle
                    tp.tdata.path = pkg_path
                end
                if k == "s_metallic_roughness" then
                    md.tdata.properties.u_metallic_roughness_factor[4] = 1
                    imaterial.set_property(eid, "u_metallic_roughness_factor", md.tdata.properties.u_metallic_roughness_factor)
                else
                    local used_flags = md.tdata.properties.u_material_texture_flags
                    used_flags[texture_used_idx[k]] = 1
                    imaterial.set_property(eid, "u_material_texture_flags", used_flags)
                end
                imaterial.set_property(eid, k, {stage = tp.stage, texture = {handle = texture_handle}})
            end
            imgui.widget.EndDragDropTarget()
        end

        local sampler = tp.tdata.sampler
        imgui.cursor.Indent()
        imgui.widget.Text("MAG:")
        imgui.cursor.SameLine()
        imgui.cursor.SetNextItemWidth(combo_width)
        imgui.util.PushID("MAG" .. idx)
        if imgui.widget.BeginCombo("##MAG", {sampler.MAG, flags = combo_flags}) then
            for i, type in ipairs(filter_type) do
                if imgui.widget.Selectable(type, sampler.MAG == type) then
                    sampler.MAG = type
                end
            end
            imgui.widget.EndCombo()
        end
        imgui.util.PopID()

        imgui.cursor.SameLine()
        imgui.widget.Text("MIN:")
        imgui.cursor.SameLine()
        imgui.cursor.SetNextItemWidth(combo_width)
        imgui.util.PushID("MIN" .. idx)
        if imgui.widget.BeginCombo("##MIN", {sampler.MIN, flags = combo_flags}) then
            for i, type in ipairs(filter_type) do
                if imgui.widget.Selectable(type, sampler.MIN == type) then
                    sampler.MIN = type
                end
            end
            imgui.widget.EndCombo()
        end
        imgui.util.PopID()

        imgui.cursor.SameLine()
        imgui.widget.Text("MIP:")
        imgui.cursor.SameLine()
        imgui.cursor.SetNextItemWidth(combo_width)
        imgui.util.PushID("MIP" .. idx)
        if imgui.widget.BeginCombo("##MIP", {sampler.MIP, flags = combo_flags}) then
            for i, type in ipairs(filter_type) do
                if imgui.widget.Selectable(type, sampler.MIP == type) then
                    sampler.MIP = type
                end
            end
            imgui.widget.EndCombo()
        end
        imgui.util.PopID()

        imgui.widget.Text("U:")
        imgui.cursor.SameLine()
        imgui.cursor.SetNextItemWidth(combo_width)
        imgui.util.PushID("U" .. idx)
        if imgui.widget.BeginCombo("##U", {sampler.U, flags = combo_flags}) then
            for i, type in ipairs(address_type) do
                if imgui.widget.Selectable(type, sampler.U == type) then
                    sampler.U = type
                end
            end
            imgui.widget.EndCombo()
        end
        imgui.util.PopID()

        imgui.cursor.SameLine()
        imgui.widget.Text("V:")
        imgui.cursor.SameLine()
        imgui.cursor.SetNextItemWidth(combo_width)
        imgui.util.PushID("V" .. idx)
        if imgui.widget.BeginCombo("##V", {sampler.V, flags = combo_flags}) then
            for i, type in ipairs(address_type) do
                if imgui.widget.Selectable(type, sampler.V == type) then
                    sampler.V = type
                end
            end
            imgui.widget.EndCombo()
        end
        imgui.cursor.SameLine()
        imgui.util.PopID()
        if imgui.widget.Button("Save") then
            utils.write_file(tp.texture, stringify(tp.tdata))
            assetmgr.unload(tp.texture)
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Save As") then
            local dialog_info = {
                Owner = rhwi.native_window(),
                Title = "Save As..",
                FileTypes = {"Texture", "*.texture" }
            }
            local ok, path = filedialog.save(dialog_info)
            if ok then
                path = string.gsub(path, "\\", "/") .. ".texture"
                local pos = string.find(path, "%.texture")
                if #path > pos + 7 then
                    path = string.sub(path, 1, pos + 7)
                end
                utils.write_file(path, stringify(tp.tdata))
            end
        end
        imgui.cursor.Unindent()
    end
end

local edit_uniform = function(eid, md)
    for k, v in pairs(md.uidata.properties) do
        if type(k) == "string" then
            imgui.widget.Text(k..":")
            imgui.cursor.SameLine()
            if imgui.widget.DragFloat("##" .. k, v) then
                local tu = md.tdata.properties[k]
                tu[1] = v[1]
                tu[2] = v[2]
                tu[3] = v[3]
                tu[4] = v[4]
                imaterial.set_property(eid, k, {v[1], v[2], v[3], v[4]})
            end
        end
    end
end

local function load_material(m, setting)
	local fx = assetmgr.load_fx(m.fx, setting)
	local properties = m.properties
	if not properties and #fx.uniforms > 0 then
		properties = {}
	end
	return {
		fx = fx,
		properties = properties,
		state = m.state
	}
end

function m.show(eid)
    if not mtldata then
        return
    end
    local uidata = mtldata.uidata
    local tdata = mtldata.tdata
    local do_save = function(path)
        local tempt = {}
        for idx, pro in ipairs(uidata.properties) do
            local k = pro.label
            local tp = tdata.properties[k]
            tempt[idx] = tp.tdata
            tp.tdata = nil
        end
        utils.write_file(path, stringify(tdata))
        for idx, pro in ipairs(uidata.properties) do
            local k = pro.label
            local tp = tdata.properties[k]
            tp.tdata = tempt[idx]
        end
    end
    if imgui.widget.TreeNode("Material", imgui.flags.TreeNode { "DefaultOpen" }) then
        if imgui.widget.Button("Save") then
            do_save(mtldata_list[eid].filename)
            assetmgr.unload(mtldata_list[eid].filename)
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Save As") then
            local dialog_info = {
                Owner = rhwi.native_window(),
                Title = "Save As..",
                FileTypes = {"Material", "*.material" }
            }
            local ok, path = filedialog.save(dialog_info)
            if ok then
                path = string.gsub(path, "\\", "/") .. ".material"
                local pos = string.find(path, "%.material")
                if #path > pos + 8 then
                    path = string.sub(path, 1, pos + 8)
                end
                do_save(path)
            end
        end

        imgui.widget.Text("file:")
        imgui.cursor.SameLine()
        imgui.cursor.PushItemWidth(-1)
        if imgui.widget.InputText("##file", uidata.material_file) then
            world[eid].material = tostring(uidata.material_file.text)
        end
        imgui.cursor.PopItemWidth()
        if imgui.widget.BeginDragDropTarget() then
            local payload = imgui.widget.AcceptDragDropPayload("DragFile")
            if payload then
                world[eid].material = payload
                local m = assetmgr.resource(payload, world)
                local c = world[eid]._cache_prefab
		        local m = load_material(m, c.material_setting)
		        c.fx, c.properties, c.state = m.fx, m.properties, m.state
            end
            imgui.widget.EndDragDropTarget()
        end
        imgui.cursor.Indent()
        imgui.widget.Text("vs:")
        imgui.cursor.SameLine()
        imgui.cursor.PushItemWidth(-1)
        if imgui.widget.InputText("##vs", uidata.vs) then
            tdata.fx.vs = tostring(uidata.vs.text)
        end
        imgui.cursor.PopItemWidth()
        -- if imgui.widget.BeginDragDropTarget() then
        --     local payload = imgui.widget.AcceptDragDropPayload("DragFile")
        --     if payload then
        --         print(payload)
        --     end
        --     imgui.widget.EndDragDropTarget()
        -- end
        imgui.widget.Text("fs:")
        imgui.cursor.SameLine()
        imgui.cursor.PushItemWidth(-1)
        if imgui.widget.InputText("##fs", uidata.fs) then
            tdata.fx.fs = tostring(uidata.fs.text)
        end
        imgui.cursor.PopItemWidth()
        -- if imgui.widget.BeginDragDropTarget() then
        --     local payload = imgui.widget.AcceptDragDropPayload("DragFile")
        --     if payload then
        --         print(payload)
        --     end
        --     imgui.widget.EndDragDropTarget()
        -- end
        imgui.cursor.Unindent()

        if imgui.widget.TreeNode("Properties", imgui.flags.TreeNode { "DefaultOpen" }) then
            edit_sampler(eid, mtldata)
            edit_uniform(eid, mtldata)
            imgui.widget.TreePop()
        end
        imgui.widget.TreePop()
    end
end

return function(w)
    world = w
    imaterial = world:interface "ant.asset|imaterial"
    return m
end