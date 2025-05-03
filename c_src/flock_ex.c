// flock_ex.c - Elixir NIF for Linux flock integration

#define _GNU_SOURCE
#include <erl_nif.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <unistd.h>

typedef struct {
    int fd;
    ErlNifPid owner;
    ErlNifMonitor monitor;
    int monitor_active;
} flock_handle_t;

static ErlNifResourceType* flock_handle_type = NULL;

static void flock_handle_dtor(ErlNifEnv* env, void* obj) {
    flock_handle_t* handle = (flock_handle_t*)obj;
    if (handle->fd >= 0) {
        flock(handle->fd, LOCK_UN);
        close(handle->fd);
        handle->fd = -1;
    }
}

static void flock_handle_down(ErlNifEnv* env, void* obj, ErlNifPid* pid, ErlNifMonitor* mon) {
    flock_handle_t* handle = (flock_handle_t*)obj;
    if (handle->fd >= 0) {
        flock(handle->fd, LOCK_UN);
        close(handle->fd);
        handle->fd = -1;
    }
}

static ErlNifResourceTypeInit flock_resource_callbacks = {
    .dtor = flock_handle_dtor,
    .down = flock_handle_down,
};

static int flock_resource_load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
    const char* name = "flock_handle";
    int flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
    ErlNifResourceFlags tried;

    flock_handle_type = enif_open_resource_type_x(env, name, &flock_resource_callbacks, flags, &tried);
    return flock_handle_type ? 0 : 1;
}

static ERL_NIF_TERM make_error(ErlNifEnv* env, const char* reason) {
    return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, reason));
}

static ERL_NIF_TERM flock_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    if (argc != 2) return make_error(env, "badarity");

    char path[256];
    unsigned len;
    ErlNifBinary bin;
    if (!enif_get_list_length(env, argv[0], &len) && !enif_is_binary(env, argv[0]) && !enif_inspect_binary(env, argv[0], &bin)) {
        return make_error(env, "badpath");
    }
    if (bin.size >= sizeof(path)) {
        return make_error(env, "path_too_long");
    }
    memcpy(path, bin.data, bin.size);
    path[bin.size] = '\0';

    int exclusive = 1;
    int wait = 1;

    if (!enif_is_list(env, argv[1])) {
        return make_error(env, "badopts");
    }

    ERL_NIF_TERM head, tail = argv[1];
    while (enif_get_list_cell(env, tail, &head, &tail)) {
        const ERL_NIF_TERM* tuple;
        int arity;
        if (enif_get_tuple(env, head, &arity, &tuple) && arity == 2) {
            if (enif_compare(tuple[0], enif_make_atom(env, "wait")) == 0) {
                if (tuple[1] == enif_make_atom(env, "false")) wait = 0;
            } else if (enif_compare(tuple[0], enif_make_atom(env, "exclusive")) == 0) {
                if (tuple[1] == enif_make_atom(env, "false")) exclusive = 0;
            }
        }
    }

    int fd = open(path, O_RDWR | O_CREAT, 0666);
    if (fd < 0) return make_error(env, "open_failed");

    int flags = exclusive ? LOCK_EX : LOCK_SH;
    if (!wait) flags |= LOCK_NB;
    if (flock(fd, flags) != 0) {
        int err = errno;
        close(fd);
        if (err == EWOULDBLOCK) return make_error(env, "eagain");
        return make_error(env, strerror(err));
    }

    flock_handle_t* handle = enif_alloc_resource(flock_handle_type, sizeof(flock_handle_t));
    handle->fd = fd;
    handle->monitor_active = 0;

    if (!enif_self(env, &handle->owner)) {
        flock_handle_dtor(env, handle);
        return make_error(env, "self_failed");
    }

    if (enif_monitor_process(env, handle, &handle->owner, &handle->monitor)) {
        handle->monitor_active = 1;
    }

    ERL_NIF_TERM result = enif_make_resource(env, handle);
    enif_release_resource(handle);

    return enif_make_tuple2(env, enif_make_atom(env, "ok"), result);
}

static ERL_NIF_TERM unflock_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    flock_handle_t* handle;
    if (!enif_get_resource(env, argv[0], flock_handle_type, (void**)&handle)) {
        return make_error(env, "badhandle");
    }
    if (handle->fd >= 0) {
        flock(handle->fd, LOCK_UN);
        close(handle->fd);
        handle->fd = -1;
    }
    return enif_make_atom(env, "ok");
}

static ErlNifFunc nif_funcs[] = {
    {"do_flock", 2, flock_nif, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"unflock", 1, unflock_nif, 0}};

ERL_NIF_INIT(Elixir.FlockEx, nif_funcs, flock_resource_load, NULL, NULL, NULL);
