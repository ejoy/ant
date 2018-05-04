local ecs = ...

local path = require "filesystem.path"
local fs_util = require "filesystem.util"
local asset = require "asset"

ecs.component "position"{
    v = {type="vector"}
}

ecs.component "rotation"{
    v = {type="vector"}
}

ecs.component "scale" {
    v = {type="vector"}
}

ecs.component "frustum" {
    isortho = false,
    n = 0.1,
    f = 10000,
    l = -1,
    r = 1,
    t = -1,
    b = 1,
}

ecs.component "viewid" {
    id = 0
}

ecs.component "render" {
    info = {
        type = "asset", 
        default = "",
        save = function (v, arg)
            assert(type(v) == "table")
            -- we assume only render and material file can be memery file
            local res_path = assert(v.res_path)
            local t = {
                render = {},
                material = {},
            }
            t.render.res_path = res_path

            
            local render_content = fs_util.read_from_file(res_path)
            if render_content == nil then
                error(string.format("read from file failed, memory file is : %s", res_path))
            end

            if path.is_mem_file(res_path) then
                t.render.value = render_content
            end
        
            local materials = {}
            local material_path_dup = {}
            for r in render_content:gmatch("material%s*=%s*\"(mem://[^%w_.]+)\"") do
                if material_path_dup[r] == nil then
                    local content = read_file_content(r)
                    if content == nil then
                        error(string.format("read from memory file failed, memory file is : %s", r))
                    end
                    table.insert(materials, {res_path=r, value=content})
                    material_path_dup[r] = true
                end
            end
            t.material = materials

            return t
        end,
        load = function (v, arg)
            assert(type(v) == "table")            
            local render_res_path = v.render.res_path
            if not asset.has_res(render_res_path) then
                for _, m in ipairs(v.material) do
                    local p = m.res_path
                    if not asset.has_res(p) then
                        fs_util.write_to_file(p, m.value)
                    end
                end
    
                local render_content = v.render.value
                if render_content then                
                    if not asset.has_res(render_res_path) then
                        fs_util.write_to_file(p, render_content)
                    end
                end                
            end

            return asset.load(render_res_path)
        end
        },
    visible = true,
}

ecs.component "name" {
    n = ""
}

ecs.component "can_select" {

}

ecs.component "last_render"{
    enable = true
}

ecs.component "control_state" {
    state = "camera"
}

