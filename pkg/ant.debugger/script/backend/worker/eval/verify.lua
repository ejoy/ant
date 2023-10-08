local source = ...
if _VERSION == "Lua 5.1" then
	load = loadstring
end
assert(load("return " .. source, '=(EVAL)'))
