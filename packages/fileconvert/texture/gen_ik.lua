--[[
    this file for generate texture ik file, according to the texture is compress or not
    ex: 
        if texture abc.dds with compress format "dxt1", then it will generate compress info in ik file as
        ...
        compress = {
            blocksize = 4x4,
            component = "RGB"   -- compress RGB components
            --ios = {type = "astc"},
            --android = {type = "astc"},
            window = {type = "BC"}, --default is astc format
        }
        ...
]]