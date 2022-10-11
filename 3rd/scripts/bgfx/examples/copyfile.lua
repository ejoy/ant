local lm = require "luamake"

local m = {}

local function compile(fullpath)
    local dir, name = fullpath:match "/([^/]+)/([^/]+)$"
    local target_name = ("copy-%s-%s"):format(dir, name)
    if m[target_name] then
        return target_name
    end
    m[target_name] = true
    lm:copy (target_name) {
        input = lm.BgfxDir / fullpath,
        output = ("$bin/%s/%s"):format(dir, name),
    }
    return target_name
end

return {
    compile = compile,
}
