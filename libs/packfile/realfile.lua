--luacheck: globals import
local require = import and import(...) or require

local function gen_rules_operation()
	local rules = nil
	return function()
		if rules then
			return rules
		end

		local vfsutil = require "vfs.util"
		rules = {}
		for _, ap in ipairs {".antpack", "engine/libs/packfile/.antpack"} do
			local f = vfsutil.open(ap, "r")
			if f then
				for line in f:lines() do
					local t = {}
					for m in line:gmatch("[^%s]+") do
						table.insert(t, m)
					end

					local pattern, packer, reg = t[1], t[2], t[3]
					if pattern then	
						if reg == nil then
							pattern = pattern:gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0'):gsub('%*', '.*')
						end
						table.insert(rules, { pattern, packer })
					end
				end
			end
		end

		return rules
	end
end

local get_rules = gen_rules_operation()

local function glob_match(pattern, target)
    return target:match(pattern) ~= nil
end

local function find_packer(path)
	local rules = get_rules()
    for _, rule in ipairs(rules) do
        if glob_match(rule[1], path) then
            return rule[2]
        end
    end
end

local fs = require "filesystem"
local path = require "filesystem.path"

return function (filepath)
	assert(path.is_absolute_path(filepath))
	if path.isdir(filepath) then
		return filepath
	end

	local lk_path = filepath .. ".lk"
    if not fs.exist(lk_path) then
        return filepath
	end

    local packer_path = find_packer(filepath)
	if not packer_path then
		-- local assetmgr = require "asset"
		-- local lkcontent = assetmgr.load(lk_path)
		-- packer_path = lkcontent.packer
		-- if packer_path == nil then
		-- 	return nil, filepath .. ': could not found packer to convert lk path'
		-- end
		error(string.format("found lk file %s, but could not find packer", lk_path))
		return
	end

	local packer = require(packer_path)
	return packer(lk_path)
end
