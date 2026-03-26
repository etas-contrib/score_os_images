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

#include "output.h"

#include <stdio.h>
#include <string.h>

void dump_bootargs(const char *bootargs)
{
    if (bootargs) {
        printf("%s\n", bootargs);
    }
}

int output_keys(const kv_pair_t *pairs, const bootargs_opts_t *opts)
{
    if (!pairs || !opts) {
        return 0;
    }

    int missing = 0;

    for (int i = 0; i < opts->num_keys; i++) {
        const char *key = opts->keys[i];

        /* Search the parsed pairs for this key */
        const char *value    = NULL;
        int         found    = 0;

        for (int j = 0; pairs[j].key != NULL; j++) {
            if (strcmp(pairs[j].key, key) == 0) {
                value = pairs[j].value; /* may be NULL for bare flags */
                found = 1;
                break;
            }
        }

        if (!found) {
            if (opts->strict) {
                fprintf(stderr,
                        "bootargs_fdt: key '%s' not found in bootargs\n", key);
            }
            missing++;
            continue;
        }

        /* Print the key=value pair in the requested format */
        const char *val_str = value ? value : "";
        if (opts->export_mode) {
            printf("export %s=%s\n", key, val_str);
        } else {
            printf("%s=%s\n", key, val_str);
        }
    }

    return missing;
}
