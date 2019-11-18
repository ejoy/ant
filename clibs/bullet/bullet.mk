BULLETROOT = $(ANT3RD)
BULLETINC = -I$(BULLETROOT)/bullet3/src
BULLETLIB = -L$(BULLETROOT)/build/bullet3/$(PLAT)/$(MODE)/lib
ifeq "$(MODE)" "debug"
BULLETLIB += -lBulletDynamics_Debug -lBulletCollision_Debug -lLinearMath_Debug
else
BULLETLIB += -lBulletDynamics -lBulletCollision -lLinearMath
endif
BULLETLIB += -lstdc++
