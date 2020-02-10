RP3DROOT = $(ANT3RD)
RP3DINC = -I$(RP3DROOT)/reactphysics3d/src
RP3DLIB = -L$(RP3DROOT)/build/reactphysics3d/$(PLAT)/$(MODE)/lib

ifeq "$(MODE)" "debug"
RP3DLIB += -lreactphysics3d_Debug
else
RP3DLIB += -lreactphysics3d
endif
