local import_gltf = require "model.import_gltf"
local fs = require "filesystem.local"

return function (config, sourcefile, outpath, localpath)
    local arguments = {
        input       = localpath(sourcefile),
        outfolder   = outpath:parent_path(),
        to_localpath= function (self, virualpath)
            return fs.path(virualpath:string():gsub(self.outfolder:string(), self.input:string()))
        end,
        to_virualpath=function (self, localpath)
            return fs.path(localpath:string():gsub(self.input:string(), self.outfolder:string()))
        end,
        make_subrespath = function (self, subrespath)
            return fs.path(self.input:string() .. "|" .. subrespath)
        end
    }
    import_gltf(arguments)
end