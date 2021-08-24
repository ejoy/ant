//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "Camera.h"

#include "..\\Utility.h"

namespace SampleFramework11
{

//=================================================================================================
// Camera
//=================================================================================================
Camera::Camera(float nearClip, float farClip) : nearZ(nearClip),
                                                farZ(farClip)
{
    world = XMMatrixIdentity();
    view = XMMatrixIdentity();
    position = Float3(0.0f, 0.0f, 0.0f);
    orientation = XMQuaternionIdentity();
}

Camera::~Camera()
{

}

void Camera::WorldMatrixChanged()
{
    view = Float4x4::Invert(world);
    viewProjection = view * projection;
}

Float3 Camera::Forward() const
{
    return world.Forward();
}

Float3 Camera::Back() const
{
    return world.Back();
}

Float3 Camera::Up() const
{
    return world.Up();
}

Float3 Camera::Down() const
{
    return world.Down();
}

Float3 Camera::Right() const
{
    return world.Right();
}

Float3 Camera::Left() const
{
    return world.Left();
}

void Camera::SetLookAt(const Float3 &eye, const Float3 &lookAt, const Float3 &up)
{
    view = XMMatrixLookAtLH(eye.ToSIMD(), lookAt.ToSIMD(), up.ToSIMD());
    world = Float4x4::Invert(view);
    position = eye;
    orientation = XMQuaternionRotationMatrix(world.ToSIMD());

    WorldMatrixChanged();
}

void Camera::SetWorldMatrix(const Float4x4& newWorld)
{
    world = newWorld;
    position = world.Translation();
    orientation = XMQuaternionRotationMatrix(world.ToSIMD());

    WorldMatrixChanged();
}

void Camera::SetPosition(const Float3& newPosition)
{
    position = newPosition;
    world.SetTranslation(newPosition);

    WorldMatrixChanged();
}

void Camera::SetOrientation(const Quaternion& newOrientation)
{
    world = XMMatrixRotationQuaternion(newOrientation.ToSIMD());
    orientation = newOrientation;
    world.SetTranslation(position);

    WorldMatrixChanged();
}

void Camera::SetNearClip(float newNearClip)
{
    nearZ = newNearClip;
    CreateProjection();
}

void Camera::SetFarClip(float newFarClip)
{
    farZ = newFarClip;
    CreateProjection();
}

void Camera::SetProjection(const Float4x4& newProjection)
{
    projection = newProjection;
    viewProjection = view * projection;
}

//=================================================================================================
// OrthographicCamera
//=================================================================================================

OrthographicCamera::OrthographicCamera(float minX, float minY, float maxX,
                                       float maxY, float nearClip, float farClip) : Camera(nearClip, farClip),
                                                                                    xMin(minX),
                                                                                    yMin(minY),
                                                                                    xMax(maxX),
                                                                                    yMax(maxY)

{
    Assert_(xMax > xMin && yMax > yMin);

    CreateProjection();
}

OrthographicCamera::~OrthographicCamera()
{

}

void OrthographicCamera::CreateProjection()
{
    projection = XMMatrixOrthographicOffCenterLH(xMin, xMax, yMin, yMax, nearZ, farZ);
    viewProjection = view * projection;
}

void OrthographicCamera::SetMinX(float minX)
{
    xMin = minX;
    CreateProjection();
}

void OrthographicCamera::SetMinY(float minY)
{
    yMin = minY;
    CreateProjection();
}

void OrthographicCamera::SetMaxX(float maxX)
{
    xMax = maxX;
    CreateProjection();
}

void OrthographicCamera::SetMaxY(float maxY)
{
    yMax = maxY;
    CreateProjection();
}

//=================================================================================================
// PerspectiveCamera
//=================================================================================================

PerspectiveCamera::PerspectiveCamera(float aspectRatio, float fieldOfView,
                                     float nearClip, float farClip) :   Camera(nearClip, farClip),
                                                                        aspect(aspectRatio),
                                                                        fov(fieldOfView)
{
    Assert_(aspectRatio > 0);
    Assert_(fieldOfView > 0 && fieldOfView <= 3.14159f);
    CreateProjection();
}

PerspectiveCamera::~PerspectiveCamera()
{

}

void PerspectiveCamera::SetAspectRatio(float aspectRatio)
{
    aspect = aspectRatio;
    CreateProjection();
}

void PerspectiveCamera::SetFieldOfView(float fieldOfView)
{
    fov = fieldOfView;
    CreateProjection();
}

void PerspectiveCamera::CreateProjection()
{
    projection = XMMatrixPerspectiveFovLH(fov, aspect, nearZ, farZ);
    viewProjection = view * projection;
}

//=================================================================================================
// FirstPersonCamera
//=================================================================================================

FirstPersonCamera::FirstPersonCamera(float aspectRatio, float fieldOfView,
                                     float nearClip, float farClip) : PerspectiveCamera(aspectRatio, fieldOfView,
                                                                                        nearClip, farClip),
                                                                                        xRot(0),
                                                                                        yRot(0)
{

}

FirstPersonCamera::~FirstPersonCamera()
{

}

void FirstPersonCamera::SetXRotation(float xRotation)
{
    xRot = Clamp(xRotation, -XM_PIDIV2, XM_PIDIV2);
    SetOrientation(XMQuaternionRotationRollPitchYaw(xRot, yRot, 0));
}

void FirstPersonCamera::SetYRotation(float yRotation)
{
    yRot = XMScalarModAngle(yRotation);
    SetOrientation(XMQuaternionRotationRollPitchYaw(xRot, yRot, 0));
}

}