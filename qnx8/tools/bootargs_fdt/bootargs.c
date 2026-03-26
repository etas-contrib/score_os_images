/*
 * Copyright (c) 2025 Contributors to the Eclipse Foundation
 *
 * See the NOTICE file(s) distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "bootargs.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Initial capacity for the kv_pair_t array (grows dynamically if needed) */
#define INITIAL_CAPACITY 32

const char *get_bootargs(const void *fdt, const libfdt_api_t *api)
{
    if (!fdt || !api) {
        return NULL;
    }

    int chosen = api->fdt_path_offset(fdt, "/chosen");
    if (chosen < 0) {
        return NULL;
    }

    int         len = 0;
    const char *val = (const char *)api->fdt_getprop(fdt, chosen, "bootargs", &len);

    return (val && len > 0) ? val : NULL;
}

kv_pair_t *parse_bootargs(const char *bootargs)
{
    if (!bootargs) {
        return NULL;
    }

    /* Work on a copy because strtok_r modifies the string */
    char *copy = strdup(bootargs);
    if (!copy) {
        return NULL;
    }

    /* Allocate initial array (+1 for the sentinel NULL entry) */
    size_t     capacity = INITIAL_CAPACITY;
    size_t     count    = 0;
    kv_pair_t *pairs    = malloc((capacity + 1) * sizeof(kv_pair_t));
    if (!pairs) {
        free(copy);
        return NULL;
    }

    char *saveptr = NULL;
    char *token   = strtok_r(copy, " \t\n", &saveptr);

    while (token) {
        /* Grow array if needed */
        if (count >= capacity) {
            capacity *= 2;
            kv_pair_t *tmp = realloc(pairs, (capacity + 1) * sizeof(kv_pair_t));
            if (!tmp) {
                /* Free what we have so far */
                for (size_t i = 0; i < count; i++) {
                    free(pairs[i].key);
                    free(pairs[i].value);
                }
                free(pairs);
                free(copy);
                return NULL;
            }
            pairs = tmp;
        }

        char *eq = strchr(token, '=');
        if (eq) {
            *eq = '\0';
            pairs[count].key   = strdup(token);
            pairs[count].value = strdup(eq + 1);
        } else {
            pairs[count].key   = strdup(token);
            pairs[count].value = NULL;
        }

        if (!pairs[count].key) {
            /* strdup failed */
            free(pairs[count].value);
            for (size_t i = 0; i < count; i++) {
                free(pairs[i].key);
                free(pairs[i].value);
            }
            free(pairs);
            free(copy);
            return NULL;
        }

        count++;
        token = strtok_r(NULL, " \t\n", &saveptr);
    }

    /* NULL-terminate the array */
    pairs[count].key   = NULL;
    pairs[count].value = NULL;

    free(copy);
    return pairs;
}

void free_kv_pairs(kv_pair_t *pairs)
{
    if (!pairs) {
        return;
    }

    for (size_t i = 0; pairs[i].key != NULL; i++) {
        free(pairs[i].key);
        free(pairs[i].value);
    }
    free(pairs);
}

const char *find_key(const kv_pair_t *pairs, const char *key)
{
    if (!pairs || !key) {
        return NULL;
    }

    for (size_t i = 0; pairs[i].key != NULL; i++) {
        if (strcmp(pairs[i].key, key) == 0) {
            return pairs[i].value; /* may be NULL for bare flags */
        }
    }

    return NULL;
}
