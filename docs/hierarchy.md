## Hierarchy

> 
    Hierarchy是一个层次化结构;
    *.hierarchy是该层次化结构序列化之后的结果;
    hierarchy component包含从*.hierarchy读取回来的结果，并带有name映射器，将对应节点处，在运行时进行绑定;
    

### *.hierarchy文件结构
1. 包含RawSkeleton序列化后的讯息。而RawSkeleton中包含了名称和节点的变换；
2. 其他还需要序列化的数据；

### 运行时相关
1. assemgr.load读取*.hierarchy文件后，会将RawSkeleton转换为Skeleton结构，该结构为更为紧凑，而RawSkeleton结构在编辑器模型下仍然有效；
2. 编辑器中，能够编辑运行时数据，即名称转换器，将绑定在name上的joint映射到实际的数据中，通常为一个eid。这个运行时绑定的数据实际上也是需要序列化的，序列化后，该数据就不能够保存为eid了，而是应该将整个entity下的component进行序列化，在序列化该runtime数据时，将entity进行创建，并绑定相应的eid；
3. 生成的Skeleton结构为ozz绑定的数据结构，而引擎中能够使用的数据应该有一种转换的格式能够让math3d和bgfx能够一拼使用，##todo（具体还没有想好怎么实现）；


