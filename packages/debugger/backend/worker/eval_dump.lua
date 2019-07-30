local content = ...
local f, err = load(content)
if not f then
    return nil, err
end
return string.dump(f)
