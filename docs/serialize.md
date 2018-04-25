### **Entity的序列化**
Entity的序列化实际上就是将Entity中的Component都序列化即可，此外，还需携带部分头部信息，用以标识有多少个Component什么的

### **Component的序列化**
Component的序列化与Component本身息息相关。包含不同数据类型的，需要对特定的数据类型进行序列化操作。

### **ECS系统的支持**

### **Envelop概念**
Envelop的概念类似于Unity引擎中的Prefab。一个Envelop能够包含一个或多个Entity，主要的目的是对runtime某个时刻的数据进行序列化，理论上不应该只限于Entity。

