//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "..\\PCH.h"
#include "..\\SF11_Math.h"

namespace SampleFramework11
{

// Abstract base class for camera types
class Camera
{

protected:

    Float4x4 view;
    Float4x4 projection;
    Float4x4 viewProjection;

    Float4x4 world;
    Float3 position;
    Quaternion orientation;

    float nearZ;
    float farZ;

    virtual void CreateProjection() = 0;
    void WorldMatrixChanged();

public:

    Camera(float nearZ, float farZ);
    ~Camera();

    const Float4x4& ViewMatrix() const { return view; };
    const Float4x4& ProjectionMatrix() const { return projection; };
    const Float4x4& ViewProjectionMatrix() const { return viewProjection; };
    const Float4x4& WorldMatrix() const { return world; };
    const Float3& Position() const { return position; };
    const Quaternion& Orientation() const { return orientation; };
    const float& NearClip() const { return nearZ; };
    const float& FarClip() const { return farZ; };

    Float3 Forward() const;
    Float3 Back() const;
    Float3 Up() const;
    Float3 Down() const;
    Float3 Right() const;
    Float3 Left() const;

    void SetLookAt(const Float3& eye, const Float3& lookAt, const Float3& up);
    void SetWorldMatrix(const Float4x4& newWorld);
    void SetPosition(const Float3& newPosition);
    void SetOrientation(const Quaternion& newOrientation);
    void SetNearClip(float newNearClip);
    void SetFarClip(float newFarClip);
    void SetProjection(const Float4x4& newProjection);
};

// Camera with an orthographic projection
class OrthographicCamera : public Camera
{

protected:

    float xMin;
    float xMax;
    float yMin;
    float yMax;

    virtual void CreateProjection() override;

public:

    OrthographicCamera(float minX, float minY, float maxX, float maxY, float nearClip, float farClip);
    ~OrthographicCamera();

    float MinX() const { return xMin; };
    float MinY() const { return yMin; };
    float MaxX() const { return xMax; };
    float MaxY() const { return yMax; };

    void SetMinX(float minX);
    void SetMinY(float minY);
    void SetMaxX(float maxX);
    void SetMaxY(float maxY);
};

// Camera with a perspective projection
class PerspectiveCamera : public Camera
{

protected:

    float aspect;
    float fov;

    virtual void CreateProjection() override;

public:

    PerspectiveCamera(float aspectRatio, float fieldOfView, float nearClip, float farClip);
    ~PerspectiveCamera();

    float AspectRatio() const { return aspect; };
    float FieldOfView() const { return fov; };

    void SetAspectRatio(float aspectRatio);
    void SetFieldOfView(float fieldOfView);
};

// Perspective camera that rotates about Z and Y axes
class FirstPersonCamera : public PerspectiveCamera
{

protected:

    float xRot;
    float yRot;

public:

    FirstPersonCamera(float aspectRatio = 16.0f / 9.0f, float fieldOfView = Pi_4, float nearClip = 0.01f, float farClip = 100.0f);
    ~FirstPersonCamera();

    float XRotation() const { return xRot; };
    float YRotation() const { return yRot; };

    void SetXRotation(float xRotation);
    void SetYRotation(float yRotation);
};

}