local fs 	= require "filesystem"
local bgfx 	= require "bgfx"

local function gen_shader_filepath(filename)
    filename = fs.path(filename)
	assert(filename:equal_extension('sc'))
	if fs.exists(filename) then
		return filename 
	end
	
	error(string.format("shader file not found:%s", filename))
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
	bgfx.set_name(h, filename:string())
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
		res.uniforms = nil
    end,
}