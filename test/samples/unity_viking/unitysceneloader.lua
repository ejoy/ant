local readDataSource = function( name )
    local  fs = require "filesystem"
    local  f = fs.open(fs.path( name ) )
    local  d = f:read "*a"
	f:close()
    return d 
end 

local function loadLevelJson(path)
    -- todo 
end 

local function loadLevelBinary(path)
    -- todo
end 

local function loadLevelLua(path)
    local  source = readDataSource(path)
    local  level = load( source )()
    return level 
    --local level = assetmgr.get_depiction(path)
end 

local function load(path,type)
    local loaders = { 
        j = loadLevelJson,
        b = loadLevelBinary,
        l = loadLevelLua
    }
    if type == nil then type = 'l' end 
    local loadlevel = loaders[type]
    if loadlevel then 
        return loadlevel(path) 
    else
        return nil
    end 
end 

return { load = load }
