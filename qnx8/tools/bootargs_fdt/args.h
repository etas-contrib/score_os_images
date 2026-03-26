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

#ifndef BOOTARGS_FDT_ARGS_H
#define BOOTARGS_FDT_ARGS_H

#include <stdbool.h>

/**
 * Parsed command-line arguments for bootargs_fdt.
 */
typedef struct {
    bool         dump_all;    /* -d / --dump   : dump full bootargs string   */
    bool         export_mode; /* -e / --export : print as "export KEY=VALUE" */
    bool         strict;      /* -s / --strict : missing key is an error     */
    const char **keys;        /* NULL-terminated array of requested key names */
    int          num_keys;
} bootargs_opts_t;

/**
 * Parse argc/argv into opts.
 *
 * @param argc  Argument count from main().
 * @param argv  Argument vector from main().
 * @param opts  Output structure; must not be NULL.
 * @return 0 on success, -1 on error (usage printed to stderr).
 */
int parse_args(int argc, char *argv[], bootargs_opts_t *opts);

/**
 * Print usage information to the given file (stdout or stderr).
 */
void print_usage(const char *prog_name);

#endif /* BOOTARGS_FDT_ARGS_H */
