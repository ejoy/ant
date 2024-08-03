local ecs = ...

local setting   = import_package "ant.settings"

--------------------------------------------------------------------------------------------------------------

-- postprocess_object

-- () optional [] fixed
-- (bloom)                  input:  main                                 output:    bloom_last_upsample
-- [tonemapping]            input:  main, (bloom_last_upsample)          output:    tonemapping
-- (effect)                 input:  tonemapping                          output:    effect
-- [fxaa/taa]               input:  effect/tonemapping                   output:    fxaa/taa/present
-- (fsr)                    input:  fxaa/taa                             output:    present

--------------------------------------------------------------------------------------------------------------

local function check_enable(name)
    local stage = string.format("graphic/postprocess/%s/enable", name)
    return setting:get(stage)
end

local STAGES = {
    main = {
        enable = true,
    },
    bloom = {
        enable = check_enable "bloom",
    },
    tonemapping = {
        enable = true,
    },
    effect = {
        enable = check_enable "effect",
    },
    fxaa = {
        enable = check_enable "fxaa",
    },
    taa = {
        enable = check_enable "taa",
    },
    fsr = {
        enable = check_enable "fsr",
    }
}

local function is_stage_enable(name)
    local s = STAGES[name]
    return s.enable and s.output
end

local function print_stages()
    for n, s in pairs(STAGES) do
        print("stage:", n, "enable: ", is_stage_enable(n))
        if s.depend then
            print("depend:", table.concat(s.depend, ","))
        end
    end
end

local function resolve_stages()
    local function add_depend(name, ...)
        STAGES[name].depend = {...}
    end

    -- we use 'output' feild to check this system is valid or not
    if is_stage_enable "bloom" then
        add_depend("bloom",         "main")
        add_depend("tonemapping",   "main", "bloom")
    else
        add_depend("tonemapping",   "main")
    end

    assert(is_stage_enable "tonemapping")

    if is_stage_enable "effect" then
        add_depend("effect",    "tonemapping")
        add_depend("fxaa",      "effect")
        add_depend("taa",       "effect")
    else
        add_depend("fxaa",      "tonemapping")
        add_depend("taa",       "tonemapping")
    end

    assert(#STAGES.fxaa.depend > 0)

    if is_stage_enable "fsr" then
        if is_stage_enable "fxaa" then
            add_depend("fsr", "fxaa")
        elseif is_stage_enable "taa" then
            add_depend("fsr", "taa")
        else
            add_depend("fsr", "tonemapping")
        end
    end

    --print_stages()
end

local ipps = {}  -- post process stage

function ipps.stage(name)
    return STAGES[name]
end

function ipps.depend_output(name, idx)
    idx = idx or 1
    return ipps.stage(ipps.stage(name).depend[idx]).output
end

ipps.input = ipps.depend_output

ipps.resolve = resolve_stages

return ipps