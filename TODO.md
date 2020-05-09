### 目前需要先完成的

1. animation 里面的cache数据存放到bindpose里面即可；(2020.03.16)
2. 将所有的transform component里面的s, r, t单独用一句矩阵来完成；(2020.03.16)
3. 数学库里面的frusutm和bounding的表示，使用矩阵来储存，尤其是aabb直接使用一个矩阵来保存，能给后续的优化带来帮助；(2020.03.18)
4. 修改模型导入，导入sub mesh的时候，计算local transform，该local transform是相对模型的local 坐标，并且与scene scale相乘；(2020.03.19)
5. 使用aabbcache，减少不必要的aabb计算；(2020.03.19)
6. 将方向光下的transform换成direction，并且该direction应该是与从光源位置相反的（目的是为了在传到shader的时候，不需要额外的计算）；(2020.03.19)
7. gltf导入进来的蒙皮是不对的；(2020.03.26, 导入到ozz下的skeleton与gltf skin节点定义的joints信息不对称)；
8. 重新整理uniform的格式，全部使用math3d的vector和matrix来表示（2020.03.26，包括全局uniform的数据表示。目前uniform数据是存放在uniformdata component的value和value_array中的）
9. update_follow不能正常工作了;(2020.03.27)
10. pickup不能够正确选中物件了；(2020.03.27)
11. 拆分出动画采样后，顶点数据更新前的一个stage。即目前的ik和fix root的位置；(2020.03.30)
12. 添加普通object的locktarget功能；（2020.04.03）
13. 将pipeline下的stage按照包的功能进行拆分；(2020.04.20)
14. 修改viewid和rendertarget的关系；(2020.04.21)
15. 目前ik在使用了rp3d物理库后，不正确；(2020.04.13)
16. 重新整理scenespace；（2020.04.13）
17. 利用新的resource管理，重整共享资源的问题，例如cpu skinning时候的vertex buffer以及gpu skinning的skinning matrices；(2020.04.14)
18. 将framebuffer、renderbuffer存放到resource里面管理；
19. 需要一个新的资源导入工具，输入一个glb文件，出来一个entity序列化的文件；(2020.04.26)
20. 需要区分skinning是CPU还是GPU，如果是CPU的话，indices和weights都不应该用于创建vertex_buffer，否则创建；
21. 需要GPU动画；
22. 需要点光源；
23. ik目前计算会有误差，误差会导致蒙皮的抖动；
24. 使用新的resource模块后，目前想同的动态的mesh无法共享。可以考虑将这种rendermesh作为一个文件注册到相应的key里面，在加载出来之后，调用这个函数；(2020.04.26)
25. 目前的阴影会监听是否有平行光创建出来，之后会更新阴影。而实际上不应该监听是否有平行光创建，而应该监听场景是否有平行光激活。延申出目前world需要一个场景相关的entity用于保存于场景相关的信息。目前world并不是一个scene，scene包含可以序列化的entity，并且包含某些entity之间共用的数据；

### 修改math3d、aabb和frusutm导致的bug

1. 阴影现在错了；(2020.04.21)
2. ik不对，原因很可能是使用的rp3d导致ik raycast出来的bug；(2020.04.14)

### 地形、阴影和pbr都需要继续优化

1. 目前阴影的精度非常低， 低的原因是csm选择的lighting bounding实在太大了。目前直接将view frustum进行平行拆分，但由于fov和aspect比较大的原因，导致精度很低。最直接的解决办法是，算出lighting bounding下scene bounding的大小，将bounding设定到更合适的大小中去；
2. 地形目前最重要的功能是从hieght field文件中导入整个地形。实际上，可以认为程序生成的也是height field数据，应该统一处理；
3. 地形的渲染。打算使用一张mask图，结合多层纹理（一张mask图4个通道，带上4层纹理）；
4. pbr的间接光必须引入；