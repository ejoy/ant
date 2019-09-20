1. 目前CSM的多级shadowmap是独立的framebuffer，缺点是，每次绘制会多一次framebuffer的切换以及阴影接收对象在shader中需要更多的分支判断，所以将多个shadowmap合拼到单个shadowmap，并通过调整shadow matrix来找到正确的shadowmap即可。带来的缺点就是shadow边缘位置需要额外的fru处理；
2. shadow coordinate理论上只需要在vs中计算，目前还是在fs中计算；
3. shadow matrix的near和far范围还是太广，导致采样走样的问题相对还是比较严重。微软的例子里面有相应的near/far的紧凑计算，可以参考，此外，最优的near/far的距离是使用类似与occlusion query的方式，通过渲染场景的depth后，获取到depth值的min/max值，用于设定shadow matrix的near/far值（这种方式是intel SDSM文章中用到的）；
4. 目前的split distance是直接手动填写的，需要使用相应的算法进行计算，常用的方式是log(far-near)的方式计算；
5. shadow cull的方式目前是不对的，直接使用light view frustum进行剔除了，应该使用：camera view frustum & light view frustum & scene bounding的并集进行计算；
6. CSM 稳定性方面。目前使用的light view volume本质上是无法避免边沿闪烁的。但令shadowmap中的阴影有固定的移动范围，还是能够一定程度上解决闪烁的问题的；
7. 软阴影方面也需要添加，目前PCF和VSM是常用的方式。PCF应该优先考虑，桌面级的GPU在DX10的时代已经有硬件支持。移动平台应该也有比较好的支持了；