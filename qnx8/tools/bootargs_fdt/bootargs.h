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

#ifndef BOOTARGS_FDT_BOOTARGS_H
#define BOOTARGS_FDT_BOOTARGS_H

#include "libfdt_loader.h"

/**
 * A parsed key=value pair from the bootargs string.
 *
 * Tokens without '=' are treated as bare flags: key is set and value is NULL.
 */
typedef struct {
    char *key;   /* NUL-terminated key string, heap-allocated  */
    char *value; /* NUL-terminated value string, or NULL        */
} kv_pair_t;

/**
 * Retrieve the raw bootargs string from the /chosen/bootargs FDT property.
 *
 * The returned pointer references memory inside the mapped FDT; do NOT free it.
 *
 * @param fdt  Pointer to the mapped FDT blob.
 * @param api  Loaded libfdt function pointers.
 * @return Pointer to the NUL-terminated bootargs string, or NULL on failure.
 */
const char *get_bootargs(const void *fdt, const libfdt_api_t *api);

/**
 * Tokenize a space-separated bootargs string into an array of kv_pair_t.
 *
 * The returned array is heap-allocated and NULL-terminated (the struct after
 * the last valid entry has key == NULL).  Free it with free_kv_pairs().
 *
 * @param bootargs  The raw bootargs string (not modified).
 * @return Heap-allocated NULL-terminated array, or NULL on allocation failure.
 */
kv_pair_t *parse_bootargs(const char *bootargs);

/**
 * Free a kv_pair_t array previously returned by parse_bootargs().
 */
void free_kv_pairs(kv_pair_t *pairs);

/**
 * Look up a key in the parsed pairs array (case-sensitive).
 *
 * @param pairs  NULL-terminated array from parse_bootargs().
 * @param key    Key to search for.
 * @return The associated value string (may be NULL for bare flags), or NULL
 *         if the key was not found.  Use pairs[i].key == key to distinguish
 *         "found with NULL value" from "not found" when necessary — but the
 *         callers in this program do not need that distinction.
 */
const char *find_key(const kv_pair_t *pairs, const char *key);

#endif /* BOOTARGS_FDT_BOOTARGS_H */
