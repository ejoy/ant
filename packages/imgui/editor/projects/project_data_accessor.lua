local accessor          = require "editor.config_accessor"
local pm                = require "antpm"
local lfs               = require "filesystem.local"

local project_data_accessor = {}

-- project_detail = {
--     config = {},
--     external_packages = {},
--     inner_packages = {},
-- }

--return project_detail
function project_data_accessor.load(pdata)
    local config_path = string.format("%s/.project",pdata.path)
    local r = loadfile(config_path,"t")
    assert(r)
    local config = r()
    do--register self
        local project_path = lfs.path(pdata.path)
        pm.editor_load_package(project_path,true)
    end
    local config_external_packages = config.external_packages
    local external_packages = {}
    if config_external_packages then
        for i,pkg_path in ipairs(config_external_packages) do
            local _path = lfs.path(pkg_path)
            local pkg_data = pm.get_registered(_path)
            if pkg_data then
                external_packages[pkg_data.config.name] = _path
            else
                local pkg_name = pm.editor_load_package(_path)
                external_packages[pkg_name] = _path
            end
        end
    end
    local config_inner_packages = config.inner_packages
    local inner_packages = {}
    if config_inner_packages then
        for i,pkg_path in ipairs(config_inner_packages) do
            local _path = lfs.path(pdata.path.."/"..pkg_path)
            local pkg_data = pm.get_registered(_path)
            if pkg_data then
                inner_packages[pkg_data.config.name] = _path
            else
                local pkg_name = pm.editor_load_package(_path)
                inner_packages[pkg_name] = _path
            end
        end
    end
    return { config = config,inner_packages = inner_packages,external_packages=external_packages}
end

local ProjectMeta = {
    {
        name = "inner_packages",
        field = "string[]",
    },
    {
        name = "external_packages",
        field = "string[]",
    },
    {
        name = "entry_scene",
        field = "string",
    },
}

project_data_accessor.ProjectMeta = ProjectMeta

function project_data_accessor.save(pdata,project_detail)
    local lua_content = accessor.write_lua(project_detail.config,ProjectMeta)
    local config_path = string.format("%s/.project",pdata.path)
    local f = io.open(config_path,"w")
    f:write(lua_content)
    f:close()
end

function project_data_accessor.add_inner_package(pdata,project_detail,pkg_relative_path)
    project_detail.config.inner_packages = project_detail.config.inner_packages or {}
    local config_inner_packages = project_detail.config.inner_packages --list
    local inner_packages = project_detail.inner_packages --dict
    local _path = lfs.path(pdata.path.."/"..pkg_relative_path)
    local pkg_data = pm.get_registered(_path)
    if pkg_data then
        if inner_packages[pkg_data.config.name] then
            log.warning("Can't add inner_packages, warningpackage with same name exist:"..pkg_data.config.name)
            return false
        end
        inner_packages[pkg_data.config.name] = _path
    else
        local pkg_name = pm.editor_load_package(_path)
        if inner_packages[pkg_name] then
            log.warning("Can't add inner_packages,package with same name exist:"..pkg_data.config.name)
            return false
        end
        inner_packages[pkg_name] = _path
    end
    table.insert(config_inner_packages,pkg_relative_path)
    return true
end

function project_data_accessor.add_external_package(pdata,project_detail,pkg_path)
    project_detail.config.external_packages = project_detail.config.external_packages or {}
    local config_external_packages = project_detail.config.external_packages
    local external_packages = project_detail.external_packages
    local _path = lfs.path(pkg_path)
    local pkg_data = pm.get_registered(_path)
    if pkg_data then
        if external_packages[pkg_data.config.name] then
            log.warning("Can't add external_packages,package with same name exist:"..pkg_data.config.name)
            return false
        end
        external_packages[pkg_data.config.name] = _path
    else
        local pkg_name = pm.editor_load_package(_path)
         if external_packages[pkg_name] then
            log.warning("Can't add external_packages,package with same name exist:"..pkg_data.config.name)
            return false
        end
        external_packages[pkg_name] = _path
    end
    table.insert(config_external_packages,_path)
    return true
end

return project_data_accessor