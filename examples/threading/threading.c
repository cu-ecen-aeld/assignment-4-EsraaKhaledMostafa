#include "threading.h"
#include <unistd.h>     // For usleep
#include <stdlib.h>     // For malloc, free
#include <stdio.h>      // For printf (used by ERROR_LOG)
#include <pthread.h>    // For pthread functions

// Optional: use these functions to add debug or error prints to your application
// #define DEBUG_LOG(msg,...)
#define DEBUG_LOG(msg,...) printf("threading: " msg "\n" , ##__VA_ARGS__)
#define ERROR_LOG(msg,...) printf("threading ERROR: " msg "\n" , ##__VA_ARGS__)

void* threadfunc(void* thread_param)
{
    // Cast the void* parameter back to our thread_data structure
    struct thread_data* thread_func_args = (struct thread_data *) thread_param;

    // Initialize success flag to false; it will be set to true only if all steps complete successfully.
    thread_func_args->thread_complete_success = false;

    DEBUG_LOG("Thread starting, waiting %d ms to obtain mutex", thread_func_args->wait_to_obtain_ms);

    // TODO: wait, obtain mutex, wait, release mutex as described by thread_data structure
    // 1. Wait for specified milliseconds before trying to obtain the mutex
    usleep(thread_func_args->wait_to_obtain_ms * 1000); // usleep takes microseconds

    DEBUG_LOG("Attempting to obtain mutex...");
    // 2. Obtain the mutex
    if (pthread_mutex_lock(thread_func_args->mutex) != 0) {
        ERROR_LOG("Failed to obtain mutex in thread.");
        return thread_param; // Return with thread_complete_success still false
    }
    DEBUG_LOG("Mutex obtained, waiting %d ms to release it", thread_func_args->wait_to_release_ms);

    // 3. Hold the mutex for specified milliseconds
    usleep(thread_func_args->wait_to_release_ms * 1000); // usleep takes microseconds

    DEBUG_LOG("Attempting to release mutex...");
    // 4. Release the mutex
    if (pthread_mutex_unlock(thread_func_args->mutex) != 0) {
        ERROR_LOG("Failed to release mutex in thread.");
        // Even if unlock fails, we return the param, indicating an error.
        return thread_param;
    }
    DEBUG_LOG("Mutex released. Thread completed successfully.");

    // If we reached here, all operations were successful
    thread_func_args->thread_complete_success = true;

    // Return the thread_data pointer so the joiner can access results and free memory
    return thread_param;
}


bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex,int wait_to_obtain_ms, int wait_to_release_ms)
{
    /**
     * TODO: allocate memory for thread_data, setup mutex and wait arguments, pass thread_data to created thread
     * using threadfunc() as entry point.
     *
     * return true if successful.
     *
     * See implementation details in threading.h file comment block
     */

    // 1. Allocate memory for thread_data
    struct thread_data *data = (struct thread_data *)malloc(sizeof(struct thread_data));
    if (data == NULL) {
        ERROR_LOG("Failed to allocate memory for thread_data.");
        return false; // Memory allocation failed
    }

    // 2. Setup mutex and wait arguments
    data->mutex = mutex;
    data->wait_to_obtain_ms = wait_to_obtain_ms;
    data->wait_to_release_ms = wait_to_release_ms;
    data->thread_complete_success = false; // Initialize to false, threadfunc will set it to true on success

    // 3. Pass thread_data to created thread using threadfunc() as entry point.
    // pthread_create returns 0 on success, an error number on failure.
    int rc = pthread_create(thread, NULL, threadfunc, data);
    if (rc != 0) {
        ERROR_LOG("Failed to create thread: %d", rc);
        free(data); // Free allocated memory if thread creation fails
        return false; // Thread creation failed
    }

    // 4. Return true if successful.
    return true; // Thread successfully started
}
