//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#ifndef QAUTERNION_HLSL_
#define QAUTERNION_HLSL_

typedef float4 Quaternion;

float3 QuatRotate(in float3 v, in Quaternion q)
{
    float3 t = 2 * cross(q.xyz, v);
    return v + q.w * t + cross(q.xyz, t);
}

Quaternion QuatFrom3x3(in float3x3 m)
{
    float3x3 a = transpose(m);
    Quaternion q;
    float trace = a[0][0] + a[1][1] + a[2][2];
    if(trace > 0)
    {
        float s = 0.5f / sqrt(trace + 1.0f);
        q.w = 0.25f / s;
        q.x = (a[2][1] - a[1][2]) * s;
        q.y = (a[0][2] - a[2][0]) * s;
        q.z = (a[1][0] - a[0][1]) * s;
    }
    else
    {
        if(a[0][0] > a[1][1] && a[0][0] > a[2][2])
        {
            float s = 2.0f * sqrt(1.0f + a[0][0] - a[1][1] - a[2][2]);
            q.w = (a[2][1] - a[1][2]) / s;
            q.x = 0.25f * s;
            q.y = (a[0][1] + a[1][0]) / s;
            q.z = (a[0][2] + a[2][0]) / s;
        }
        else if(a[1][1] > a[2][2])
        {
            float s = 2.0f * sqrt(1.0f + a[1][1] - a[0][0] - a[2][2]);
            q.w = (a[0][2] - a[2][0]) / s;
            q.x = (a[0][1] + a[1][0]) / s;
            q.y = 0.25f * s;
            q.z = (a[1][2] + a[2][1]) / s;
        }
        else
        {
            float s = 2.0f * sqrt(1.0f + a[2][2] - a[0][0] - a[1][1]);
            q.w = (a[1][0] - a[0][1]) / s;
            q.x = (a[0][2] + a[2][0]) / s;
            q.y = (a[1][2] + a[2][1]) / s;
            q.z = 0.25f * s;
        }
    }
    return q;
}

float3x3 QuatTo3x3(in Quaternion q)
{
    float3x3 m = float3x3(1.0f - 2.0f * q.y * q.y - 2.0f * q.z * q.z, 2.0f * q.x * q.y - 2.0f * q.z * q.w, 2.0f * q.x * q.z + 2.0f * q.y * q.w,
                          2.0f * q.x * q.y + 2.0f * q.z * q.w, 1.0f - 2.0f * q.x * q.x - 2.0f * q.z * q.z, 2.0f * q.y * q.z - 2.0f * q.x * q.w,
                          2.0f * q.x * q.z - 2.0f * q.y * q.w, 2.0f * q.y * q.z + 2.0f * q.x * q.w, 1.0f - 2.0f * q.x * q.x - 2.0f * q.y * q.y);
    return transpose(m);
}

float4x4 QuatTo4x4(in Quaternion q)
{
    float3x3 m3x3 = QuatTo3x3(q);
    return float4x4(m3x3._m00, m3x3._m01, m3x3._m02, 0.0f,
                    m3x3._m10, m3x3._m11, m3x3._m12, 0.0f,
                    m3x3._m20, m3x3._m21, m3x3._m22, 0.0f,
                    0.0f, 0.0f, 0.0f, 1.0f);
}

float4 PackQuaternion(in Quaternion q)
{
    Quaternion absQ = abs(q);
    float absMaxComponent = max(max(absQ.x, absQ.y), max(absQ.z, absQ.w));

    uint maxCompIdx = 0;
    float maxComponent = q.x;

    [unroll]
    for(uint i = 0; i < 4; ++i)
    {
        if(absQ[i] == absMaxComponent)
        {
            maxCompIdx = i;
            maxComponent = q[i];
        }
    }

    if(maxComponent < 0.0f)
        q *= -1.0f;

    float3 components;
    if(maxCompIdx == 0)
        components = q.yzw;
    else if(maxCompIdx == 1)
        components = q.xzw;
    else if(maxCompIdx == 2)
        components = q.xyw;
    else
        components = q.xyz;

    const float maxRange = 1.0f / sqrt(2.0f);
    components /= maxRange;
    components = components * 0.5f + 0.5f;

    return float4(components, maxCompIdx / 3.0f);
}

Quaternion UnpackQuaternion(in float4 packed)
{
    uint maxCompIdx = uint(packed.w * 3.0f);
    packed.xyz = packed.xyz * 2.0f - 1.0f;
    const float maxRange = 1.0f / sqrt(2.0f);
    packed.xyz *= maxRange;
    float maxComponent = sqrt(1.0f - saturate(packed.x * packed.x + packed.y * packed.y + packed.z * packed.z));

    Quaternion q;
    if(maxCompIdx == 0)
        q = Quaternion(maxComponent, packed.xyz);
    else if(maxCompIdx == 1)
        q = Quaternion(packed.x, maxComponent, packed.yz);
    else if(maxCompIdx == 2)
        q = Quaternion(packed.xy, maxComponent, packed.z);
    else
        q = Quaternion(packed.xyz, maxComponent);

    return q;
}

Quaternion ShortestArcRotation(in float3 v1, in float3 v2)
{
    Quaternion q;
    q.xyz = cross(v1, v2);
    q.w = dot(v1, v2);

    return q;
}

#endif // QAUTERNION_HLSL_