local util = {}; util.__index = util
function util.generate_bones(ske)
	local bones = {}
	for i=1, #ske do
		if not ske:isroot(i) then
			table.insert(bones, {ske:parent(i), i})
		end
	end
	return bones
end
return util