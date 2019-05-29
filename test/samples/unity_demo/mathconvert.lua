local mathconv = {}
mathconv.__index = mathconv

function mathconv.getQuatFromEuler( angles, order)
    local cos = math.cos 
    local sin = math.sin 
    local x,y,z = angles[1],angles[2],angles[3]

    x = x*math.pi/180;
    y = y*math.pi/180;
    z = z*math.pi/180;

    local c1 = cos(x/2);
    local c2 = cos(y/2);
    local c3 = cos(z/2);
    local s1 = sin(x/2);
    local s2 = sin(y/2);
    local s3 = sin(z/2);
    local q = {}
    if order == "XYZ" then 
        q.x = s1 * c2 * c3 + c1 * s2 * s3;
		q.y = c1 * s2 * c3 - s1 * c2 * s3;
		q.z = c1 * c2 * s3 + s1 * s2 * c3;
		q.w = c1 * c2 * c3 - s1 * s2 * s3;
    elseif order == "ZXY" then 
        q.x = s1 * c2 * c3 - c1 * s2 * s3;
		q.y = c1 * s2 * c3 + s1 * c2 * s3;
		q.z = c1 * c2 * s3 + s1 * s2 * c3;
        q.w = c1 * c2 * c3 - s1 * s2 * s3;
    elseif order == "YXZ" then 
        q.x = s1 * c2 * c3 + c1 * s2 * s3;
		q.y = c1 * s2 * c3 - s1 * c2 * s3;
		q.z = c1 * c2 * s3 - s1 * s2 * c3;
        q.w = c1 * c2 * c3 + s1 * s2 * s3;
    elseif order == "ZYX" then 
        q.w = c1 * c2 * c3 + s1 * s2 * s3;                
        q.x = s1 * c2 * c3 - c1 * s2 * s3;
        q.y = c1 * s2 * c3 + s1 * c2 * s3;
        q.z = c1 * c2 * s3 - s1 * s2 * c3;
    end 
    return q 
end 

function mathconv.getQuatFromAxisAngle(axis,angle)
    local halfAngle = (angle*math.pi/180)/2 
    local s = math.sin( halfAngle );

    this._x = axis[1] * s;
    this._y = axis[2] * s;
    this._z = axis[3] * s;
    this._w = Math.cos( halfAngle );

    return this;
end 

function mathconv.getMatrixFromQuat( quat, order)
    local scale = {1,1,1}

    local m = {} 

    local  x = quat.x
    local  y = quat.y
    local  z = quat.z
    local  w = quat.w

    local x2 = x + x  
    local y2 = y + y 
    local z2 = z + z

    local xx = x * x2  
    local xy = x * y2  
    local xz = x * z2

    local yy = y * y2 
    local yz = y * z2 
    local zz = z * z2

    local wx = w * x2  
    local wy = w * y2  
    local wz = w * z2

    local sx = scale[1] 
    local sy = scale[2]
    local sz = scale[3]

    m[ 1 ] = ( 1 - ( yy + zz ) ) * sx;
    m[ 2 ] = ( xy + wz ) * sx;  
    m[ 3 ] = ( xz - wy ) * sx;
    m[ 4 ] = 0;

    m[ 5 ] = ( xy - wz ) * sy;
    m[ 6 ] = ( 1 - ( xx + zz ) ) * sy;
    m[ 7 ] = ( yz + wx ) * sy;
    m[ 8 ] = 0;

    m[ 9 ] = ( xz + wy ) * sz;
    m[ 10 ] = ( yz - wx ) * sz;
    m[ 11 ] = ( 1 - ( xx + yy ) ) * sz;
    m[ 12 ] = 0;

    m[ 13 ] = 0;
    m[ 14 ] = 0;
    m[ 15 ] = 0;
    m[ 16 ] = 1;

    --  m[3]  = -m[3];
    --  m[7]  = -m[7];
    --  m[9]  = -m[9];
    --  m[10] = -m[10];

    --  00 01 02 03
    --  10 11 12 13
    --  20 21 22 23
    --  30 31 32 33
    --  local a = {
    --      1,0,0,0,
    --      0,1,1,0,
    --      0,0,-1,0,
    --      0,0,0,1
    --  }

    return m;    
    -- local r = {
    --     m[1 ], m[5], -m[9],  m[13],
    --     m[2],  m[6], -m[10], m[14],
    --     -m[3], -m[7], m[11], m[15],
    --     m[4],  m[8], -m[12], m[16],
    -- }
    -- return r
end



-- invalid function
function mathconv.getMatrixDirectFromEulerLH( angles, order)
    -- glm zxy
    local cos = math.cos 
    local sin = math.sin 
    local x,y,z = angles[1],angles[2],angles[3]

    x = x*math.pi/180;
    y = y*math.pi/180;
    z = z*math.pi/180;

    local c1 = cos(x)
    local c2 = cos(y)
    local c3 = cos(z)
    local s1 = sin(x)
    local s2 = sin(y)
    local s3 = sin(z)

    local m = {}

    m[1]  = c1*c2 - s1*s2*s3   m[2]  = -c2*s1    m[3]  = c1*s3 + c3*s1*s2    m[4]  = 0
    m[5]  = c3*s1 + c1*s2*s3   m[6]  = c1*c2     m[7]  = s1*s3 - c1*c3*s2    m[8]  = 0
    m[9]  = -c2*s3             m[10] = s2        m[11] = c2*c3               m[12] = 0
    m[13] = 0                  m[14] = 0         m[15] = 0                   m[16] = 1

    return m
end 
-- invalid function
function mathconv.getMatrixDirectFromEulerRH( angles, order)


end 

function mathconv.getQuatFromMatrix( q,m ) 
    local  m11,m12,m13  = m[1], m[5], m[9]
    local  m21,m22,m23  = m[2], m[6], m[10]
    local  m31,m32,m33  = m[3], m[7], m[11]

    local  ray = m11 + m22 + m33
    local  scl

    if ray  > 0 then 
        scl = 0.5 / math.sqrt( ray + 1.0 )
        q.w  = 0.25 / scl
        q.x = (m32-m23) * scl
        q.y = (m13-m31) * scl
        q.z = (m21-m12) * scl
    elseif  m11>m22 and m11>m33 then 
        scl = 2.0 * math.sqrt( 1.0 + m11-m22-m33 )
        q.w = (m32-m23) / scl
        q.x = 0.25 * scl
        q.y = (m12+m21) / scl
        q.z = (m13+m31) / scl
    elseif  m22>m33 then 
        scl = 2.0 * math.sqrt( 1.0 + m22-m11-m33 )
        q.w = (m13-m31) / scl
        q.x = (m12+m21) / scl
        q.y = 0.25 * scl
        q.z = (m23+m32 ) / scl
    else 
        scl = 2.0 * math.sqrt( 1.0 + m33-m11-m22 )
        q.w = (m21-m12) / scl
        q.x = (m13+m31) / scl
        q.y = (m23+m32 ) / scl
        q.z = 0.25*scl
    end 
    return q    
end 

function mathconv.getMatrixFromEuler( angles,order)
    local q = mathconv.getQuatFromEuler(angles,order)
    return mathconv.getMatrixFromQuat(q,order)
end 

function mathconv.getEulerFromMatrix(m,order)

    local clamp = math.clamp

    function clamp(v,min,max)
        if v < min then v = min end 
        if v > max then v = max end 
        return v         
    end 

    local m11 = m[ 1 ] 
    local m12 = m[ 5 ]  
    local m13 = m[ 9 ]
    local m21 = m[ 2 ] 
    local m22 = m[ 6 ]  
    local m23 = m[ 10 ]
    local m31 = m[ 3 ]
    local m32 = m[ 7 ]  
    local m33 = m[ 11 ]

    local angles = { }

    if  order == 'XYZ' then 

        angles[2] =  math.asin( clamp( m13, -1, 1 ) )

        if ( math.abs( m13 ) < 1-1e-6 ) then 
            angles[1] = math.atan( - m23, m33 );
            angles[3] = math.atan( - m12, m11 );
        else 
            angles[1] = math.atan( m32, m22 );
            angles[3] = 0;
        end 
        -- glm does'not work，only two function protocols are correct. 
        -- local T1 = math.atan(m32,m33);
        -- local C2 = math.sqrt(m11*m11+m21*m21)
        -- local T2 = math.atan(-m31,C2)
        -- local S1 = math.sin(T1)
        -- local C1 = math.cos(T1)
        -- local T3 = math.atan(m13*S1-C1*m12,C1*m22-S1*m23)
        -- angles[1] = - T1  -- x2
        -- angles[2] = - T2
        -- angles[3] = - T3 

    elseif ( order == 'ZYX') then 
        angles[2] = math.asin( -clamp(m31,-1,1))
        if( math.abs(m31)< 1-1e-6) then 
            angles[1] = math.atan(m32,m33)
            angles[3] = math.atan(m21,m11)
        else 
            angles[1] = 0
            angles[3] = math.atan(-m12,m22);
        end 

    elseif ( order == 'ZXY' ) then 

        angles[1] = math.asin( clamp( m32, -1, 1 ) );

        if ( math.abs( m32 ) < 1-1e-6 ) then
            angles[2] = math.atan( - m31, m33 );
            angles[3] = math.atan( - m12, m22 );
        else 
            angles[2] = 0;
            angles[3] = math.atan( m21, m11 );
        end
    elseif( order == "YXZ") then 

        angles[1] = math.asin(-clamp(m23,-1,1));
        if( math.abs(m23)<1-1e-6 ) then 
            angles[2] = math.atan(m13,m33)
            angles[3] = math.atan(m21,m22)
        else 
            angles[2] = math.atan(-m31,m11)
            angles[3] = 0
        end 
    end 

    angles[1] = angles[1]*180/math.pi;
    angles[2] = angles[2]*180/math.pi;
    angles[3] = angles[3]*180/math.pi;
	return angles;
end 

function mathconv.transpose(m)
        local m1 = { 
            m[1], m[2], m[3], m[4],
            m[5], m[6], m[7], m[8],
            m[9], m[10],m[11],m[12],
            m[13],m[14],m[15],m[16]
        }
		local tmp 
		tmp = m1[ 2 ];  m1[ 2 ]  = m1[ 5 ];   m1[ 5 ]  = tmp;
		tmp = m1[ 3 ];  m1[ 3 ]  = m1[ 9 ];   m1[ 9 ]  = tmp;
		tmp = m1[ 7 ];  m1[ 7 ]  = m1[ 10 ];  m1[ 10 ] = tmp;

		tmp = m1[ 4 ];  m1[ 4 ]  = m1[ 13 ];  m1[ 13 ] = tmp;
		tmp = m1[ 8 ];  m1[ 8 ]  = m1[ 14 ];  m1[ 14 ] = tmp;
		tmp = m1[ 12 ]; m1[ 12 ] = m1[ 15 ];  m1[ 15 ] = tmp;
        return m1 
end 

function determinant(m) 
    local a , b , c ,
          d , e , f ,
          g , h , i = 
          m[ 1 ], m[ 2 ], m[ 3 ],
          m[ 4 ], m[ 5 ], m[ 6 ],
          m[ 7 ], m[ 8 ], m[ 9 ]

       return a * e * i - a * f * h - b * d * i + b * f * g + c * d * h - c * e * g;
end 

function mathconv.recompose(m, position, quaternion, scale )

    local te = m 

    local x = { m[1],m[2],m[3] }
    local y = { m[5],m[6],m[7] }
    local z = { m[9],m[10],m[11] }
    local sx = math.sqrt(x[1]*x[1] + x[2]*x[2] + x[3]*x[3] )
    local sy = math.sqrt(y[1]*y[1] + y[2]*y[2] + y[3]*y[3] )
    local sz = math.sqrt(z[1]*z[1] + z[2]*z[2] + z[3]*z[3] )

    local det = determinant(m);
    if  det < 0  then 
        sx = - sx;
    end 

    position[1] = m[ 13 ]
    position[2] = m[ 14 ]
    position[3] = m[ 15 ]


    local matrix = { 
        m[1],m[2],m[3],m[4],
        m[5],m[6],m[7],m[8],
        m[9],m[10],m[11],m[12],
        m[13],m[14],m[15],m[16],
     }


    local  invSX = 1 / sx;
    local  invSY = 1 / sy;
    local  invSZ = 1 / sz;

    matrix[ 1 ] = matrix[ 1 ]* invSX;
    matrix[ 2 ] = matrix[ 2 ]* invSX;
    matrix[ 3 ] = matrix[ 3 ]* invSX;

    matrix[ 5 ] = matrix[ 5 ]* invSY;
    matrix[ 6 ] = matrix[ 6 ]* invSY;
    matrix[ 7 ] = matrix[ 7 ]* invSY;

    matrix[ 9 ] = matrix[ 9 ]* invSZ;
    matrix[ 10 ] = matrix[ 10 ]* invSZ;
    matrix[ 11 ] = matrix[ 11 ]* invSZ;

    quaternion.setFromRotationMatrix( matrix );

    scale[1] = sx;
    scale[2] = sy;
    scale[3] = sz;

end 

function mathconv.mulMatrices( m1, m2 ) 

    local m = { }
    local a11,a12,a13,a14 = m1[ 0 ],  m1[ 4 ],  m1[ 8 ], m1[ 12 ]
    local a21,a22,a23,a24 = m1[ 1 ],  m1[ 5 ],  m1[ 9 ], m1[ 13 ]
    local a31,a32,a33,a34 = m1[ 2 ],  m1[ 6 ],  m1[ 10 ],m1[ 14 ]
    local a41,a42,a43,a44 = m1[ 3 ],  m1[ 7 ],  m1[ 11 ],m1[ 15 ]

    local b11,b12,b13,b14 = m2[ 0 ],  m2[ 4 ],  m2[ 8 ], m2[ 12 ]
    local b21,b22,b23,b24 = m2[ 1 ],  m2[ 5 ],  m2[ 9 ], m2[ 13 ]
    local b31,b32,b33,b34 = m2[ 2 ],  m2[ 6 ],  m2 [10 ],m2[ 14 ]
    local b41,b42,b43,b44 = m2[ 3 ],  m2[ 7 ],  m2[ 11 ],m2[ 15 ]

    m[ 0 ] = a11 * b11 + a12 * b21 + a13 * b31 + a14 * b41;
    m[ 4 ] = a11 * b12 + a12 * b22 + a13 * b32 + a14 * b42;
    m[ 8 ] = a11 * b13 + a12 * b23 + a13 * b33 + a14 * b43;
    m[ 12 ] = a11 * b14 + a12 * b24 + a13 * b34 + a14 * b44;

    m[ 1 ] = a21 * b11 + a22 * b21 + a23 * b31 + a24 * b41;
    m[ 5 ] = a21 * b12 + a22 * b22 + a23 * b32 + a24 * b42;
    m[ 9 ] = a21 * b13 + a22 * b23 + a23 * b33 + a24 * b43;
    m[ 13 ] = a21 * b14 + a22 * b24 + a23 * b34 + a24 * b44;

    m[ 2 ] = a31 * b11 + a32 * b21 + a33 * b31 + a34 * b41;
    m[ 6 ] = a31 * b12 + a32 * b22 + a33 * b32 + a34 * b42;
    m[ 10 ] = a31 * b13 + a32 * b23 + a33 * b33 + a34 * b43;
    m[ 14 ] = a31 * b14 + a32 * b24 + a33 * b34 + a34 * b44;

    m[ 3 ] = a41 * b11 + a42 * b21 + a43 * b31 + a44 * b41;
    m[ 7 ] = a41 * b12 + a42 * b22 + a43 * b32 + a44 * b42;
    m[ 11 ] = a41 * b13 + a42 * b23 + a43 * b33 + a44 * b43;
    m[ 15 ] = a41 * b14 + a42 * b24 + a43 * b34 + a44 * b44;

    return m
end 


return mathconv


