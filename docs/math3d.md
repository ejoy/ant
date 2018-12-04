## 默认坐标
目前坐标方向如下：
Z轴：朝向屏幕内部方向
Y轴：面向屏幕，自底往上的方向
X轴：面向屏幕，自左往右的方向

构成的是**左右系**坐标

## 矩阵的表示形式
目前使用列向量的方式保存矩阵（内部使用glm，glm默认使用列向量）
即：
有矩阵m0，m1，已经顶点p0。矩阵m0先作用顶点p0，得到p1,；矩阵m1再作用p1，得到p2。
假设数学栈是stack，上述方式为：
```
local p0 = {1, 2, 3, 1}
local p1 = stack(m0, p0, "*P")
local p2 = stack(m1, p1, "*P")

--[[ same as above code
	local mm = stack(m1, m0, "*P")
	local p2 = stack(mm, p0, "*P")
]]
```


