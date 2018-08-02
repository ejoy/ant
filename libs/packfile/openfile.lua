local require = import and import(...) or require
local winfile =  require "winfile"
--local fs =  require "cppfs"

local rawopen = winfile.open

local rules = {}
--todo support packfile
--[[
if winfile.exist(".antpack") then
	for str in io.lines '.antpack' do
		local f, l = str:find ' '
		if f then
			local pattern = str:sub(1, f - 1)
			local packer =  str:sub(l + 1)
			pattern = pattern:gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0'):gsub('%*', '.*')
			rules[#rules+1] = { pattern, packer }
		end
	end
end
--]]

local function glob_match(pattern, target)
    return target:match(pattern) ~= nil
end

local function find_packer(path)
    for _, rule in ipairs(rules) do
        if glob_match(rule[1], path) then
            return rule[2]
        end
    end
end

local function savefile(filename, content)
    local path =  require "filesystem.path"
    path.create_dirs(path.parent(filename))
	local f, err = rawopen(filename, "wb")
	if not f then
		return false, err
	end
    f:write(content)
	f:close()
	return true
end

local function need_update(lnk_path, cache_path)
    if winfile.exist(lnk_path) and winfile.exist(cache_path) then
        local util =  require "filesystem.util"
        if util.file_is_newer(lnk_path, cache_path) then
            return true
        end
    end
    return not winfile.exist(cache_path)
end

return function (path, mode)
    if mode and mode:match 'w' then
        return rawopen(path, mode)
    end
    if winfile.exist(path) then
        return rawopen(path, mode)
    end
    local packer_path = find_packer(path)
    if not packer_path then
        return nil, path .. ': No such file or directory'
    end
    local cache_path = 'cache/' .. path
    local lnk_path = path .. '.lnk'
    if not need_update(lnk_path, cache_path) then
        return rawopen(path, mode)
    end
    local packer = require(packer_path)
    local res = packer(lnk_path)
    local ok, err = savefile(cache_path, res)
    if not ok then
        return nil, err
    end
  --  local time = fs.last_write_time(fs.path(lnk_path))
  --  fs.last_write_time(fs.path(cache_path), time)
    return rawopen(cache_path, mode)
end
