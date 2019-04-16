return {
    supportsConfigurationDoneRequest = true,
    supportsSetVariable = true,
    supportsConditionalBreakpoints = true,
    supportsHitConditionalBreakpoints = true,
    supportsDelayedStackTraceLoading = true,
    supportsExceptionInfoRequest = true,
    supportsLogPoints = true,
    supportsEvaluateForHovers = true,
    supportsLoadedSourcesRequest = true,
    supportsTerminateRequest = true,
    exceptionBreakpointFilters = {
        {
            default = false,
            filter = 'pcall',
            label = 'Exception: Lua pcall',
        },
        {
            default = false,
            filter = 'xpcall',
            label = 'Exception: Lua xpcall',
        },
        {
            default = true,
            filter = 'lua_pcall',
            label = 'Exception: C lua_pcall',
        },
        {
            default = true,
            filter = 'lua_panic',
            label = 'Exception: C lua_panic',
        }
    }
}
