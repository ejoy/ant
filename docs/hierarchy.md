## Hierarchy

### Hierarchy在ecs系统中的表示
> 
    Hierarchy是一个层次化结构;    
    目前有两种hierarchy的结构，分别用于editor和runtime：
    editable_hierarchy component用于editor，hierarchy component用于runtime。两者的关系是：hierarchy通过build_hierarchy_system对editable_hierarchy调用hierarchy.build函数获得。
    其中editable_hierarchy包含的是ozz中的Raw_skeleton，而hierarchy保存的是ozz中的skeleton数据
    
### 关于name mapper
hierarchy结构中，只包含两项数据，分别是name和transform
将hierarchy中的node映射到具体的数据是用过hierarchy_name_mapper component来完成的。由于将这项数据拆分到component中，故其能够序列化，也能够在runtime的时候修改数据并保存

### 运行时相关
1. hierarchy和hierarchy_name_mapper是runtime数据。原则上，hierarchy在runtime的时候不会被修改。而hierarchy_name_mapper则是为runtime时候数据绑定而添加的。如，hierarchy_name_mapper会根据服务发起的请求，对某个层次节点进行修改（包括替换和删除，但不能够添加，而所谓的删除只是映射到不存在的物体中，实际上只有替换操作）。目前hierarchy_name_mapper绑定到world中的entity id中。
2. hierarchy的序列化中，save的操作是把builddata数据直接序列化，即获取其name和srt的属性；而在load的阶段中，把之前序列化的node和srt直接调用build操作后获得；editable_hierarchy的方式类似，也是通过获取所有的数据，生成table/从table中生成，分别对应save和load的过程；
3. 生成的Skeleton结构为ozz绑定的数据结构，而引擎中能够使用的数据应该有一种转换的格式能够让math3d和bgfx能够一拼使用，##todo（具体还没有想好怎么实现）；


