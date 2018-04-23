CXXFLAGS = -O2 -Wall
CXX = g++
AR= ar rcu
OBJDIR = o

all : libozz.a

mingw : all

$(OBJDIR) :
	mkdir $(OBJDIR)

SRC = \
 src/animation/offline/raw_skeleton.cc \
 src/animation/offline/skeleton_builder.cc \
 src/animation/runtime/skeleton.cc \
 src/base/memory/allocator.cc \
 src/base/io/archive.cc \
 src/base/log.cc \
 src/base/maths/math_archive.cc \
 src/base/maths/simd_math.cc \
 src/base/maths/simd_math_archive.cc \
 src/base/maths/soa_math_archive.cc \
# animation/runtime/animation.cc \
# animation/runtime/blending_job.cc \
# animation/runtime/local_to_model_job.cc \
# animation/runtime/sampling_job.cc \
# animation/runtime/skeleton.cc \
# animation/runtime/skeleton_utils.cc \
# geometry/skinning_job.cc \
# base/box.cc \
# base/stream.cc \
# base/string_archive.cc \


define OBJ_TEMP
  $(OBJDIR)/$$(basename $$(notdir $(1))).o : $(1) | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c -o $$@ $$< -I include
endef

$(foreach v, $(SRC), $(eval $(call OBJ_TEMP,$(v))))

OBJS := $(addprefix o/,$(notdir $(patsubst %.cc,%.o,$(SRC))))

libozz.a : $(OBJS)
	$(AR) $@ $^

clean :
	rm -rf *.a o
