dofile "libs/init.lua"

local asset = require "asset"
local fs = require "filesystem"
local rawtable = require "asset.rawtable"

print_r = require "../common/print_r"

asset.insert_searchdir(nil, "libs/asset")
--will change defautl material loader function
asset.add_loader("material", function (filename)
	return assert(rawtable(filename))	
end)

local material = asset.load("test.material")
print_r(material)
