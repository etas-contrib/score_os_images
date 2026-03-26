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

#include "args.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void print_usage(const char *prog_name)
{
    fprintf(stderr,
            "Usage: %s [OPTIONS] [KEY ...]\n"
            "\n"
            "Read key=value pairs from the FDT /chosen/bootargs node.\n"
            "\n"
            "Options:\n"
            "  -d, --dump    Dump the entire raw bootargs string to stdout.\n"
            "                Mutually exclusive with -e.\n"
            "  -e, --export  Print matched pairs as 'export KEY=VALUE' (shell eval).\n"
            "                Mutually exclusive with -d.\n"
            "  -s, --strict  Treat a missing KEY as an error (exit code 1).\n"
            "  -h, --help    Print this help and exit 0.\n"
            "\n"
            "At least one KEY must be provided unless -d is used.\n"
            "\n"
            "Exit codes:\n"
            "  0  Success\n"
            "  1  Logical error (missing key in strict mode, bad arguments)\n"
            "  2  System error (FDT not found, mmap failed, libfdt not loaded, etc.)\n"
            "\n"
            "Examples:\n"
            "  %s -d\n"
            "  %s IP_ADDRESS HOSTNAME\n"
            "  eval $(%s -e IP_ADDRESS GATEWAY)\n"
            "  eval $(%s -e -s IP_ADDRESS) || echo 'FATAL: no IP_ADDRESS'\n",
            prog_name, prog_name, prog_name, prog_name, prog_name);
}

int parse_args(int argc, char *argv[], bootargs_opts_t *opts)
{
    if (!opts) {
        return -1;
    }

    opts->dump_all    = false;
    opts->export_mode = false;
    opts->strict      = false;
    opts->keys        = NULL;
    opts->num_keys    = 0;

    /* Handle long options manually before getopt(), then use getopt() for short. */
    /* Pre-process: translate long options to their short equivalents. */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--dump") == 0) {
            argv[i] = (char *)"-d";
        } else if (strcmp(argv[i], "--export") == 0) {
            argv[i] = (char *)"-e";
        } else if (strcmp(argv[i], "--strict") == 0) {
            argv[i] = (char *)"-s";
        } else if (strcmp(argv[i], "--help") == 0) {
            argv[i] = (char *)"-h";
        }
    }

    int opt;
    while ((opt = getopt(argc, argv, "desh")) != -1) {
        switch (opt) {
            case 'd':
                opts->dump_all = true;
                break;
            case 'e':
                opts->export_mode = true;
                break;
            case 's':
                opts->strict = true;
                break;
            case 'h':
                print_usage(argv[0]);
                exit(0);
            default:
                print_usage(argv[0]);
                return -1;
        }
    }

    /* Validate mutual exclusivity of -d and -e */
    if (opts->dump_all && opts->export_mode) {
        fprintf(stderr, "%s: error: -d and -e are mutually exclusive\n", argv[0]);
        print_usage(argv[0]);
        return -1;
    }

    /* Collect positional KEY arguments */
    int num_keys = argc - optind;
    if (num_keys > 0) {
        opts->keys     = (const char **)&argv[optind];
        opts->num_keys = num_keys;
    }

    /* If not dumping and no keys given, it's an error */
    if (!opts->dump_all && opts->num_keys == 0) {
        fprintf(stderr, "%s: error: at least one KEY must be specified unless -d is used\n",
                argv[0]);
        print_usage(argv[0]);
        return -1;
    }

    return 0;
}
