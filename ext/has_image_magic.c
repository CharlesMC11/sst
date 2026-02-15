#include <fcntl.h>
#include <string.h>
#include <sysexits.h>
#include <unistd.h>

int has_image_magic(const char filename[]) {
  const unsigned char magic[8] = {0x89, 0x50, 0x4e, 0x47,
                                  0x0d, 0xa,  0x1a, 0x0a};
  unsigned char buf[8];
  int fd;
  int bytes_read;

  fd = open(filename, O_RDONLY);
  if (fd < 0) return 0;

  bytes_read = read(fd, buf, sizeof(buf));
  close(fd);

  if (bytes_read != 8) return 0;

  return memcmp(buf, magic, sizeof(buf)) == 0;
}
