GEO_PATH='C:/Users/ejoy/Documents/geometry'
FILES='project_entry.lua libs/debug_drawing.lua libs/geometry_generator.lua libs/util.lua'
DST_FOLDER='D:/Work/ant/test/samples/editor/geometry'
for f in $FILES 
do
	cp $GEO_PATH/$f $DST_FOLDER/$f
done
