#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>

static char g_input_absolute_path[PATH_MAX];

extern int has_image_magic(const char filename[]);

int is_image(const struct dirent* entry);
int compare_filenames(const struct dirent** a, const struct dirent** b);

int main(const int argc, const char* argv[]) {
  struct dirent** entries = NULL;
  int entry_count;

  if (realpath((argc >= 2) ? argv[1] : ".", g_input_absolute_path) == NULL)
    return EX_NOINPUT;

  entry_count =
      scandir(g_input_absolute_path, &entries, is_image, compare_filenames);
  if (entry_count <= 0) {
    if (entry_count == 0 || errno == ENOENT) return EX_NOINPUT;
    if (errno == EACCES) return EX_NOPERM;
    return EX_OSERR;
  }

  for (int i = 0; i < entry_count; ++i) {
    printf("%s/%s\n", g_input_absolute_path, entries[i]->d_name);

    free(entries[i]);
  }
  free(entries);

  return EX_OK;
}

/*!
 * Validate if a directory entry is an image
 *
 * @param entry
 * An entry to validate
 *
 * @result
 * `1` if `entry` is an image; `0` otherwise
 */
int is_image(const struct dirent* entry) {
  char absolute_path[PATH_MAX];

  if (entry->d_type != DT_REG || entry->d_name[0] == '.') return 0;

  snprintf(absolute_path, sizeof(absolute_path), "%s/%s", g_input_absolute_path,
           entry->d_name);
  return has_image_magic(absolute_path);
}

/*!
 * Compare the names of two directory entries, ensuring `name 1.ext` comes after
 * `name.ext`.
 *
 * @param d1
 * An address of a directory entry
 *
 * @param d2
 * An address of a directory entry
 *
 * @result
 * `-1` if `d1` is lexigraphically less than `d2`; `0` if they are the same; `1`
 * if `d1` is lexigraphically greater than `d2`
 */
int compare_filenames(const struct dirent** d1, const struct dirent** d2) {
  const char* name1;
  const char* name2;

  name1 = (*d1)->d_name;
  name2 = (*d2)->d_name;

  while (*name1 && (*name1 == *name2)) {
    name1++;
    name2++;
  }

  if ((*name1 == ' ' && *name2 == '.') || (*name1 == '.' && *name2 == ' '))
    return (*name1 == ' ') ? 1 : -1;
  return *(unsigned char*)name1 - *(unsigned char*)name2;
}
