#ifndef vfs_h
#define vfs_h

struct vfs;

struct vfs * vfs_init(const char *firmware, const char *dir);
const char * vfs_load(struct vfs *V, const char *path);
void vfs_exit(struct vfs *V);

#endif
