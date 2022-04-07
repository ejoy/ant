local bgfx = require "bgfx"
local lfs = require "filesystem.local"
local stringify = require "stringify"
local compile = require "compile"
local config = require "config"
local fxsetting = require "editor.fx.setting"

local CACHE = {}


local function merge(a, b)
    for k, v in pairs(b) do
        if not a[k] then
            a[k] = v
        end
    end
    return a
end

local function mergeCfgSetting(setting)
    merge(setting, config.get "sc".setting)
    return fxsetting.deldef(setting)
end

local function createStage(stageFile, setting)
    return stageFile .. "?" .. stringify(setting)
end

local function initFX(fx)
    local s = mergeCfgSetting(fx.setting)
    s.varying_path = fx.varying_path
    local res = {}
    local function updateStage(stage)
        if fx[stage] then
            s.stage = stage
            res[stage] =  {
                createStage(fx[stage], s),
            }
        end
    end
    updateStage "cs"
    updateStage "fs"
    updateStage "vs"
    s.stage = nil
    s.varying_path = nil
    res.setting = fx.setting
    return res
end

local function getHash(fx)
    if fx.cs then
        return fx.cs[1]
    end
    return fx.vs[1]..fx.fs[1]
end

local function create_uniform(h, mark)
    local name, type, num = bgfx.get_uniform_info(h)
    if mark[name] then
        return
    end
    mark[name] = true
    return { handle = h, name = name, type = type, num = num }
end

local function uniform_info(shader, uniforms, mark)
    for _, h in ipairs(bgfx.get_shader_uniforms(shader)) do
        uniforms[#uniforms+1] = create_uniform(h, mark)
    end
end

local function createRenderProgram(vs, fs)
    local prog = bgfx.create_program(vs, fs, false)
    if prog then
        local uniforms = {}
        local mark = {}
        uniform_info(vs, uniforms, mark)
        uniform_info(fs, uniforms, mark)
        return prog, uniforms
    else
        error(string.format("create program failed, vs:%d, fs:%d", vs, fs))
    end
end

local function createComputeProgram(cs)
    local prog = bgfx.create_program(cs, false)
    if prog then
        local uniforms = {}
        local mark = {}
        uniform_info(cs, uniforms, mark)
        return prog, uniforms
    else
        error(string.format("create program failed, cs:%d", cs))
    end
end

local function compile_shader(shader)
    return compile.compile_dir(shader, "main.bin")
end

local function read_shader(shader)
	local f = assert(lfs.open(compile_shader(shader), "rb"))
	local data = f:read "a"
	f:close()
	return data
end

local function loadShader_(shader)
    local h = bgfx.create_shader(read_shader(shader))
    bgfx.set_name(h, shader[1])
    return h
end

local function createProgram(fx)
    local function loadFxShader(stage)
        local shader = fx[stage]
        if shader == nil then
            error(("invalid stage:%s in fx file"):format(stage))
        end
        return loadShader_(shader)
    end

    local result = {}
    if fx.cs then
        result.cs = loadFxShader "cs"
        result.prog, result.uniforms = createComputeProgram(result.cs)
    else
        result.vs, result.fs = loadFxShader "vs", loadFxShader "fs"
        result.prog, result.uniforms = createRenderProgram(result.vs, result.fs)
    end
    return result
end

local function load(fx)
    fx = initFX(fx)
    local schash = getHash(fx)
    local res = CACHE[schash]
    if res then
        return res
    end
    res = createProgram(fx)
    res.setting = fxsetting.adddef(fx.setting)
    CACHE[schash] = res
    return res
end

local function unload(res)
    bgfx.destroy(assert(res.prog))
end

return {
    load = load,
    unload = unload,
}
