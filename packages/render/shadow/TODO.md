1. 目前CSM的多级shadowmap是独立的framebuffer，缺点是，每次绘制会多一次framebuffer的切换以及阴影接收对象在shader中需要更多的分支判断，所以将多个shadowmap合拼到单个shadowmap，并通过调整shadow matrix来找到正确的shadowmap即可。带来的缺点就是shadow边缘位置需要额外的fru处理；(2019.09.24已经完成)
2. shadow coordinate理论上只需要在vs中计算，目前还是在fs中计算；（2019.09.24：目前选择cascade的方式是使用viewspace distance来选择，如果阴影纹理坐标在vs中计算，导致在vs中选择的cascade就会出现偏差，这会导致后面的阴影计算直接出错，即本该在第二层上的阴影，却选择了第一层，或者相反，而阴影的坐标却插值到fs中，导致选择阴影图比较阴影时候出错）
3. shadow matrix的near和far范围还是太广，导致采样走样的问题相对还是比较严重。微软的例子里面有相应的near/far的紧凑计算，可以参考，此外，最优的near/far的距离是使用类似与occlusion query的方式，通过渲染场景的depth后，获取到depth值的min/max值，用于设定shadow matrix的near/far值（这种方式是intel SDSM文章中用到的）；
4. 目前的split distance是直接手动填写的，需要使用相应的算法进行计算，常用的方式是log(far-near)的方式计算（2019.09.26：已经完成，目前通过pssm_lambda值，通过对数的形式自动计算split distance，原始算法在pssm的paper里面可以看到，GPU Gems里面也能够查到）；
5. shadow cull的方式目前是不对的，直接使用light view frustum进行剔除了，应该使用：camera view frustum & light view frustum & scene bounding的并集进行计算；
6. CSM 稳定性方面。目前使用的light view volume本质上是无法避免边沿闪烁的。但令shadowmap中的阴影有固定的移动范围，还是能够一定程度上解决闪烁的问题的；
7. 软阴影方面也需要添加，目前PCF和VSM是常用的方式。PCF应该优先考虑，桌面级的GPU在DX10的时代已经有硬件支持。移动平台应该也有比较好的支持了；