local content = ...
local f = load(content)
if not f then
    return
end
return string.dump(f)
