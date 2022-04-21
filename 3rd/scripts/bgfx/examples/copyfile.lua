local lm = require "luamake"

local function compile(fullpath)
    local dir, name = fullpath:match "/([^/]+)/([^/]+)$"
    local target_name = ("copy-%s-%s"):format(dir, name)
    lm:copy (target_name) {
        input = lm.BgfxDir / fullpath,
        output = ("$bin/%s/%s"):format(dir, name),
    }
    return target_name
end

return {
    compile = compile,
}
