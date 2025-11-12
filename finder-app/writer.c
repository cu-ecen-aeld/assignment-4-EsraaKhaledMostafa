#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <sys/stat.h>
#include <libgen.h>
#include <errno.h>

int main(int argc, char *argv[]) {
    openlog("writer", LOG_PID | LOG_CONS, LOG_USER);

    // Check if the correct number of arguments is provided
    if (argc != 3) {
        syslog(LOG_ERR, "Error: Two arguments required. Usage: %s <file-path> <write-string>", argv[0]);
        fprintf(stderr, "Error: Two arguments required. Usage: %s <file-path> <write-string>\n", argv[0]);
        return 1;
    }

    const char *writefile = argv[1];
    const char *writestr = argv[2];

    // Duplicate the writefile to avoid modifying the original path
    char *writefile_copy = strdup(writefile);
    if (!writefile_copy) {
        syslog(LOG_ERR, "Error: Memory allocation failed.");
        closelog();
        return 1;
    }

    char *dirpath = dirname(writefile_copy);
    
    // Attempt to create the directory path if it doesn't exist
    struct stat st = {0};
    if (stat(dirpath, &st) == -1) {
        // If directory doesn't exist, attempt to create it
        if (mkdir(dirpath, 0755) != 0 && errno != EEXIST) {
            syslog(LOG_ERR, "Error: Could not create directory %s. %m", dirpath);
            free(writefile_copy);
            closelog();
            return 1;
        }
    }

    free(writefile_copy);   // Cleanup

    // Open the file for writing, overwriting if it exists
    FILE *file = fopen(writefile, "w");
    if (file == NULL) {
        syslog(LOG_ERR, "Error: File could not be created. %m");
        closelog();
        return 1;
    }

    // Write the contents to the file
    fprintf(file, "%s", writestr);
    syslog(LOG_DEBUG, "Writing %s to %s", writestr, writefile);

    fclose(file);
    closelog();

    return 0;
}
