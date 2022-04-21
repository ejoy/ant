local lm = require "luamake"

require "tools.geometryc"

local geometryc_rule <const> = {
    bunny = "compile_geometry_barycentric",
    bunny_decimated = "compile_geometry_compressed",
    bunny_patched = "compile_geometry",
    column = "compile_geometry",
    cube = "compile_geometry",
    hollowcube = "compile_geometry_barycentric",
    orb = "compile_geometry_barycentric",
    platform = "compile_geometry",
    tree = "compile_geometry_compressed",
    tree1b_lod0_1 = "compile_geometry_compressed",
    tree1b_lod0_2 = "compile_geometry_compressed",
    tree1b_lod1_1 = "compile_geometry_compressed",
    tree1b_lod1_2 = "compile_geometry_compressed",
    tree1b_lod2_1 = "compile_geometry_compressed",
    tree1b_lod2_2 = "compile_geometry_compressed",
    test_scene = "compile_geometry",
}

local geometryc_args <const> = {
    compile_geometry = {},
    compile_geometry_compressed = {"-c"},
    compile_geometry_barycentric = {"--barycentric"},
}

local m = {}
local rule = {}

local function set_rule(rulename)
    if rule[rulename] then
        return
    end
    rule[rulename] = true
    lm:rule (rulename) {
        "$bin/geometryc",
        "-f", "$in","-o", "$out",
        "--packnormal", "1",
        geometryc_args[rulename],
        description = "Convert geometry $in"
    }
end

local function compile(fullpath)
    local name = fullpath:match "/([^/]+)%.obj$"
    local target_name = ("mesh-%s"):format(name)
    if m[target_name] then
        return target_name
    end
    m[target_name] = true
    local rulename = assert(geometryc_rule[name], "unknown mesh: "..name)
    set_rule(rulename)
    lm:build (target_name) {
        rule = rulename,
        input = lm.BgfxDir / fullpath,
        output = ("$bin/meshes/%s.bin"):format(name),
        deps = "geometryc",
    }
    return target_name
end

return {
    compile = compile,
}
