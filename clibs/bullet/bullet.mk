BULLETROOT = $(ANT3RD)
BULLETINC = -I$(BULLETROOT)/bullet3/src 
BULLETLIB = -L$(BULLETROOT)/build/bullet3/$(PLAT)/lib -lBulletDynamics -lBulletCollision -lLinearMath -lstdc++
