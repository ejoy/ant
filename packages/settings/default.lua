return {
    graphic = {
        ao = {
            enable      = true,
            bent_normal = false,
            quality      = "low",
            radius      = 0.3,      -- Ambient Occlusion radius in meters, between 0 and ~10.
            power       = 1.0,      -- Controls ambient occlusion's contrast. Must be positive.
            bias        = 0.0005,   -- Self-occlusion bias in meters. Use to avoid self-occlusion. Between 0 and a few mm.
            resolution  = 0.5,      -- How each dimension of the AO buffer is scaled. Must be either 0.5 or 1.0.
            intensity   = 1.0,      -- Strength of the Ambient Occlusion effect.
            bilateral_threshold = 0.05,     -- depth distance that constitute an edge for filtering
            min_horizon_angle = 0.0,      -- min angle in radian to consider
        }
    }
}