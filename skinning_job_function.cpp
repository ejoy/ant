void SkinningPNTITN(const SkinningJob& _job) {
    (void)( (!!(_job.vertex_count&& _job.in_positions.begin&& _job.in_normals .begin&& _job.in_tangents.begin)) || (_wassert(L"_job.vertex_count&& _job.in_positions.begin&& _job.in_normals .begin&& _job.in_tangents.begin", L"D:\\Work\\ant\\3rd\\ozz-animation\\src\\geometry\\runtime\\skinning_job.cc", (unsigned)(452)), 0) );
    (void)( (!!(_job.joint_inverse_transpose_matrices.begin)) || (_wassert(L"_job.joint_inverse_transpose_matrices.begin", L"D:\\Work\\ant\\3rd\\ozz-animation\\src\\geometry\\runtime\\skinning_job.cc", (unsigned)(452)), 0) ); 
    const uint16_t* joint_indices = _job.joint_indices.begin;
     const float* in_positions = _job.in_positions.begin;
     float* out_positions = _job.out_positions.begin;;
     const float* in_normals = _job.in_normals.begin;
     float* out_normals = _job.out_normals.begin;; 
    const float* in_tangents = _job.in_tangents.begin; 
    float* out_tangents = _job.out_tangents.begin; 
    const math::SimdFloat4 one = math::simd_float4::one(); 
    const float* joint_weights = _job.joint_weights.begin; 
    const int loops = _job.vertex_count - 1; 
    for (int i = 0; i < loops; ++i) { 
        math::SimdFloat4 wsum = math::simd_float4::Load1PtrU(joint_weights + 0); 
        const uint16_t i0 = joint_indices[0]; 
        math::Float4x4 transform = math::ColumnMultiply(_job.joint_matrices[i0], wsum); 
        math::Float4x4 it_transform = math::ColumnMultiply(_job.joint_inverse_transpose_matrices[i0], wsum); 
        const int last = _job.influences_count - 1; 
        for (int j = 1; j < last; ++j) { 
            const uint16_t ij = joint_indices[j]; 
            const math::SimdFloat4 w = math::simd_float4::Load1PtrU(joint_weights + j); 
            wsum = wsum + w; 
            transform = transform + math::ColumnMultiply(_job.joint_matrices[ij], w); 
            it_transform = it_transform + math::ColumnMultiply(_job.joint_inverse_transpose_matrices[ij], w); 
        } 
        const math::SimdFloat4 wlast = one - wsum; 
        
        const int ilast = joint_indices[last]; 
        transform = transform + math::ColumnMultiply(_job.joint_matrices[ilast], wlast); 
        it_transform = it_transform + math::ColumnMultiply( _job.joint_inverse_transpose_matrices[ilast], wlast); 

        const math::SimdFloat4 in_p = math::simd_float4::LoadPtrU(in_positions); 
        const math::SimdFloat4 out_p = TransformPoint(transform, in_p); 
        math::Store3PtrU(out_p, out_positions);; 

        const math::SimdFloat4 in_n = math::simd_float4::LoadPtrU(in_normals); 
        const math::SimdFloat4 out_n = TransformVector(it_transform, in_n); 
        math::Store3PtrU(out_n, out_normals);; 

        const math::SimdFloat4 in_t = math::simd_float4::LoadPtrU(in_tangents); 
        const math::SimdFloat4 out_t = TransformVector(it_transform, in_t); 
        math::Store3PtrU(out_t, out_tangents); 

        joint_indices = reinterpret_cast<const uint16_t*>(reinterpret_cast<uintptr_t>(joint_indices) + _job.joint_indices_stride); 

        in_positions = reinterpret_cast<const float*>(reinterpret_cast<uintptr_t>(in_positions) + _job.in_positions_stride); 
        out_positions = reinterpret_cast<float*>(reinterpret_cast<uintptr_t>(out_positions) + _job.out_positions_stride);; 

        in_normals = reinterpret_cast<const float*>(reinterpret_cast<uintptr_t>(in_normals) + _job.in_normals_stride); 
        out_normals = reinterpret_cast<float*>(reinterpret_cast<uintptr_t>(out_normals) + _job.out_normals_stride);; 

        in_tangents = reinterpret_cast<const float*>(reinterpret_cast<uintptr_t>(in_tangents) + _job.in_tangents_stride); 
        out_tangents = reinterpret_cast<float*>(reinterpret_cast<uintptr_t>(out_tangents) + _job.out_tangents_stride); 

        joint_weights = reinterpret_cast<const float*>(reinterpret_cast<uintptr_t>(joint_weights) + _job.joint_weights_stride); 
    } 
    math::SimdFloat4 wsum = math::simd_float4::Load1PtrU(joint_weights + 0); 
    const uint16_t i0 = joint_indices[0]; 
    math::Float4x4 transform = math::ColumnMultiply(_job.joint_matrices[i0], wsum); 
    math::Float4x4 it_transform = math::ColumnMultiply(_job.joint_inverse_transpose_matrices[i0], wsum); 
    const int last = _job.influences_count - 1; 
    for (int j = 1; j < last; ++j) 
    { 
        const uint16_t ij = joint_indices[j]; 
        const math::SimdFloat4 w = math::simd_float4::Load1PtrU(joint_weights + j); 
        wsum = wsum + w; 
        transform = transform + math::ColumnMultiply(_job.joint_matrices[ij], w); 
        it_transform = it_transform + math::ColumnMultiply(_job.joint_inverse_transpose_matrices[ij], w); 
    } 
    const math::SimdFloat4 wlast = one - wsum;
    const int ilast = joint_indices[last]; 
    transform = transform + math::ColumnMultiply(_job.joint_matrices[ilast], wlast); 
    it_transform = it_transform + math::ColumnMultiply( _job.joint_inverse_transpose_matrices[ilast], wlast); 

    const math::SimdFloat4 in_p = math::simd_float4::Load3PtrU(in_positions); 
    const math::SimdFloat4 out_p = TransformPoint(transform, in_p); 
    math::Store3PtrU(out_p, out_positions);; 

    const math::SimdFloat4 in_n = math::simd_float4::Load3PtrU(in_normals); 
    const math::SimdFloat4 out_n = TransformVector(it_transform, in_n); 
    math::Store3PtrU(out_n, out_normals);; 

    const math::SimdFloat4 in_t = math::simd_float4::Load3PtrU(in_tangents); 
    const math::SimdFloat4 out_t = TransformVector(it_transform, in_t); 
    math::Store3PtrU(out_t, out_tangents); 
}