local fs = require "filesystem"

local function gen_shader_filepath(filename)
    filename = fs.path(filename)
	assert(filename:equal_extension(''))
	local shadername_withext = filename .. ".sc"
	if fs.exists(shadername_withext) then
		return shadername_withext 
    end
    local pkgdir = fs.path("/pkg") / shadername_withext:package_name()
	shadername_withext = pkgdir / "shaders" / "src" / fs.relative(shadername_withext, pkgdir)
	if fs.exists(shadername_withext) then
		return shadername_withext 
    end
end

local function load_shader(filename)
	local filepath = gen_shader_filepath(filename)
	if filepath == nil then
		error(string.format("not found shader file: [%s]", filename))
	end

	if not __ANT_RUNTIME__ then
        assert(fs.exists(filepath .. ".lk"))
	end	

	local f = assert(fs.open(filepath, "rb"))
	local data = f:read "a"
	f:close()
	local h = bgfx.create_shader(data)
	bgfx.set_name(h, filename)
	return h
end

return {
    loader = function (filename)
        local handle = load_shader(filename)
        local uniforms = bgfx.get_shader_uniforms(handle)
        return {
            handle = handle,
            uniforms = uniforms,
        }
    end,
    unloader = function (res)
		bgfx.destroy(assert(res.handle))
		res.handle = nil
    end,
}