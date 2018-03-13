local function check_append_dir(src, ref)
    local dir, file = src:match("(.*/)(.*)")
    if dir == nil then
        local r_dir = ref:match(".*/")
        if r_dir then 
            return r_dir .. src
        end
    end
    return src
end

local function read_render_elem(ff, rootfile, assetlib)
    assert(type(ff) == "string")
    return assetlib[check_append_dir(ff, rootfile)]
end

function recurse_read(source, src_filename, recurse_elems, assetlib)
    local e = {}
    for _, v in ipairs(recurse_elems) do
        e[v] = true
    end

    local t = {}
    for k, v in pairs(source) do
        if e[k] then
            t[k] = read_render_elem(v, src_filename, assetlib)
        else
            t[k] = v
        end
    end

    return t
end