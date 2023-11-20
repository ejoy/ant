local L = import_package "ant.render.core".layout

local SHADER_VERSION<const> = 11
local SHADER_TYPES<const> = {
    C = SHADER_VERSION, F = SHADER_VERSION, V = SHADER_VERSION
}

local BGFX_PREDEFINED_NAMES<const> = {
    u_viewRect      = true,
    u_viewTexel     = true,
    u_view          = true,
    u_invView       = true,
    u_proj          = true,
    u_invProj       = true,
    u_viewProj      = true,
    u_invViewProj   = true,
    u_model         = true,
    u_modelView     = true,
    u_modelViewProj = true,
    u_alphaRef4     = true,
}

local function isShaderBin(magic)
    local t = magic:sub(1, 1)
    return magic:sub(2, 3) == "SH" and (nil ~= SHADER_TYPES[t])
end

local function isShaderVersionValid(magic)
    local t, v = magic:sub(1, 1), magic:sub(4, 4)
    return v:byte() == SHADER_TYPES[t]
end

local function create_reader(c)
    return {
        content = c,
        offset = 1,
        read = function (self, size)
            local last = self.offset + size - 1
            if last > #self.content then
                error(("Data out of bound, content size:%d, read:%d"):format(#self.content, last))
            end
            local d = self.content:sub(self.offset, last)
            self.offset = last+1
            return d
        end,
        readUint32 = function (self)
            return ("I"):unpack(self:read(4))
        end,
        readUint8 = function(self)
            return ("B"):unpack(self:read(1))
        end,
        readUint16 = function (self)
            return ("H"):unpack(self:read(2))
        end,
        skip = function (self, s)
            local o = self.offset + s
            if o > #self.content then
                log.info(("skip distance:%d, over the content:%d, current offset:%d"):format(o, self.content, self.offset))
            end
            self.offset = o
        end
    }
end

local kUniformMask<const> = 0xf0
local reservedType<const> = 1 --bgfx_ph.h Line 4219

local ID2INPUTNAMES<const> = {
    [0x0001] = "a_position",
    [0x0002] = "a_normal",
    [0x0003] = "a_tangent",
    [0x0004] = "a_bitangent",
    [0x0005] = "a_color0",
    [0x0006] = "a_color1",
    [0x0018] = "a_color2",
    [0x0019] = "a_color3",
    [0x000e] = "a_indices",
    [0x000f] = "a_weight",
    [0x0010] = "a_texcoord0",
    [0x0011] = "a_texcoord1",
    [0x0012] = "a_texcoord2",
    [0x0013] = "a_texcoord3",
    [0x0014] = "a_texcoord4",
    [0x0015] = "a_texcoord5",
    [0x0016] = "a_texcoord6",
    [0x0017] = "a_texcoord7",
}

local function parse_shaderbin(c, renderer)
    local reader = create_reader(c)
    local magic = reader:read(4)
    if not isShaderBin(magic) then
        error "Invalid shader binary"
    end

    if not isShaderVersionValid(magic) then
        error(("Invalid shader version, only support bgfx shader version: compute:%d, vertex:%d, fragment:%d"):format(SHADER_TYPES.C, SHADER_TYPES.V, SHADER_TYPES.F))
    end

    local hashIn, hashOut = reader:read(4), reader:read(4)

    local count = reader:readUint16()

    local uniforms = {}

    for ii=1, count do
        local nameSize = reader:readUint8()

        local name = reader:read(nameSize)

        local type = reader:readUint8()
        type = type & ~kUniformMask;

        local num = reader:readUint8()

        local regIndex = reader:readUint16()
        local regCount = reader:readUint16()

        local texInfo = reader:readUint16()
        local texFormat = reader:readUint16()

        if not BGFX_PREDEFINED_NAMES[name] and (type ~= reservedType) then
            local u = uniforms[name]
            local nu = {
                name = name,
                type = type,
                num = num,
                regIndex = regIndex,
                regCount = regCount,
                texInfo = texInfo,
                texFormat = texFormat,
            }
            if u then
                local function uniform_equal(lhs, rhs)
                    for k, v in pairs(lhs) do
                        if rhs[k] ~= v then
                            return false
                        end
                    end
                    return true
                end
                assert(uniform_equal(u, nu))
            else
                uniforms[name] = nu
            end
        end
    end

    local inputs = {}
    if renderer == "metal" then
        if magic:sub(1, 1) == 'C' then
            --see: bgfx/renderer_mtl.mm:void ShaderMtl::create(const Memory* _mem)
            for i=1, 3 do
                reader:readUint16()
            end
        end
    elseif renderer == "direct3d11" or renderer == "direct3d12" or renderer == "vulkan" then
        --pass through
    else
        error(("Not support renderer: %s to pasre shader"):format(renderer))
    end

    local shadersize = reader:readUint32()
    reader:skip(shadersize+1)   -- +1 for skip file's eol

    --read layout input attribs
    local attribnum = reader:readUint8()
    
    for i=1, attribnum do
        local id = reader:readUint16()
        inputs[i] = ID2INPUTNAMES[id]
    end

    return {
        magic   = magic,
        hashIn  = hashIn,
        hashOut = hashOut,
        inputs  = inputs,
        uniforms= uniforms,
    }
end


return {
    parse = parse_shaderbin,
}