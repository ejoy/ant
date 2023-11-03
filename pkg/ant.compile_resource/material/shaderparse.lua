local SHADER_TYPES<const> = {
    C = 10, F = 10, V = 10
}

local BGFX_PREDEFINED_NAMES<const> = {
    u_viewRect = true,
    u_viewTexel = true,
    u_view = true,
    u_invView = true,
    u_proj = true,
    u_invProj = true,
    u_viewProj = true,
    u_invViewProj = true,
    u_model = true,
    u_modelView = true,
    u_modelViewProj = true,
    u_alphaRef4 = true,
}

local function isShaderBin(magic)
    local t = magic:sub(1, 1)
    return magic:sub(2, 3) == "SH" and (nil ~= SHADER_TYPES[t])
end

local function isShaderVersionValid(magic)
    local t, v = magic:sub(1, 1), magic:sub(4, 4)
    return v:byte() >= SHADER_TYPES[t]
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
        end
    }
end

local kUniformMask<const> = 0xf0

local function parse_shaderbin(c)
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

        if not BGFX_PREDEFINED_NAMES[name] then
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

    return {
        magic = magic,
        hashIn = hashIn,
        hashOut = hashOut,
        uniforms = uniforms,
    }
end


return {
    parse = parse_shaderbin,
}