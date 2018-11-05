local function check_enable_pack()
	local env_ENABLE_PACK = os.getenv "ENABLE_PACK"
	if env_ENABLE_PACK == nil then
		return true
	end

	return env_ENABLE_PACK == "ON"
end

local enable_pack = check_enable_pack()

function enable_packfile(state)
	if state then
		enable_pack = state
	end

	return enable_pack
end