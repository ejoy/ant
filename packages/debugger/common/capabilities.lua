return {
    supportsConfigurationDoneRequest = true,
    supportsFunctionBreakpoints = true,
    supportsConditionalBreakpoints = true,
    supportsHitConditionalBreakpoints = true,
    supportsEvaluateForHovers = true,
    supportsSetVariable = true,
    supportsRestartFrame = true,
    supportsRestartRequest = true,
    supportsExceptionInfoRequest = true,
    supportsDelayedStackTraceLoading = true,
    supportsLoadedSourcesRequest = true,
    supportsLogPoints = true,
    supportsTerminateRequest = true,
    supportsClipboardContext = true,
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
