### **序列化的save和load**
使用save和load对需要序列化的数据进行序列化。
> 
    world中包含了场景的save和load函数，负责对整个world进行序列化。
    entity的序列化方法存放在world:save_entity()和world:load_entity()函数中。
    componet的序列化通过两个途径实现。component会为基础的数据完成save和load的操作，而userdata需要自定义自己的save和load方法，在定义component的时候给出。之后，ecs系统在构建改component的时候，会通过gen_save和gen_load再进行一次封装，完成实际上的序列化工作。


### **Entity的序列化**
Entity的序列化实际上就是将Entity中的Component都序列化即可，此外，还需携带部分头部信息，用以标识有多少个Component什么的

### **Component的序列化**
Component的序列化与Component本身息息相关。包含不同数据类型的，需要对特定的数据类型进行序列化操作。

### **ECS系统的支持**

### **Envelop概念**
Envelop的概念类似于Unity引擎中的Prefab。一个Envelop能够包含一个或多个Entity，主要的目的是对runtime某个时刻的数据进行序列化，理论上不应该只限于Entity。

