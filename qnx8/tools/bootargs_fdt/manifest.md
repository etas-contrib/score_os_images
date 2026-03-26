# Your role
You are a QNX/Posix/BSP expert and shall implement a C program named "bootargs_fdt".

# Functions of the program
The program is intended to be executed at the startup phase of a QNX OS and
shall enable a system integrator or a tester to pass options in form of "key=value"
from the boot phase to the QNX OS startup phase. For example one should be able
to pass "IP_ADDRESS=192.168.100.41/24" by the boot command line to the startup 
scripts of the OS so that they can evaluate dedicated option keys for potential values
by executing the program in the context of the scripts.

The program can assume that the options are available in the "/chosen/bootargs" node
of a device tree which resides in memory.

## Function details

The program:

- identifies the physical address of a flattened device tree file in memory
- maps it into the programs address space
- parse it for the "chosen/bootargs" node
- and then based on the users's needs:
  - dump the whole bootargs string.
  - dump only key-value pairs for user-provided list of keys it finds in the bootargs.
  - export key-value pairs as environment variable for user-provided list of keys it finds in the bootargs.

## Error cases
The behavior on error shall be as specified:
- if it cannot identify the device tree or cannot map the memory it shall always fail with exit code != 0.
- if it does not find a user-provided key it shall by default silently ignore this and return exit code=0.
- Only if instructed by special command line option it shall treat the previous case as error and fail 
  with exit code != 0 if it does not find one of the given keys.

# Constraints

- The program is only required to run on QNX 8.0 arm64 targets.
- The program shall utilize the "libfdt.so" provided by QNX by using "dlopen()" and "dlsym()". 
  This library is not documented at QNX but we assume it contains the same symbols as the public 
  https://git.kernel.org/pub/scm/utils/dtc/dtc.git/tree/libfdt
- The location of the FDT (flattened device tree) can be found by investigating the "asinfo" area
  in the QNX "system page". See function documented at: https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.lib_ref/topic/w/walk_asinfo.html?hl=asinfo
  An example asinfo dumped by "pidin syspage=asinfo" system utility looks like this:
    ```
    # pidin syspage=asinfo
    Header size=0x000000f0, Total Size=0x00000b10, Version=2.0, #Cpu=2, Type=4353
    Section:asinfo offset:0x00000938 size:0x00000138 elsize:0x00000018
    0000) 0000000000000000-00000fffffffffff o:ffff /memory
    0018) 0000000000000000-00000000ffffffff o:0000 /memory/below4G
    0030) 0000000040000000-000000007fffffff o:0018 /memory/below4G/ram
    0048) 0000000048000000-00000000480fffff o:0030 /memory/below4G/ram/fdt
    0060) 0000000008000000-0000000008000fff o:0000 /memory/gicd
    0078) 0000000008010000-0000000008010fff o:0000 /memory/gicc
    0090) 00000000400ac0e8-0000000041fde273 o:0000 /memory/imagefs
    00a8) 0000000040080fa0-00000000400ac0e7 o:0000 /memory/startup
    00c0) 00000000400ac0e8-0000000041fde273 o:0000 /memory/bootram
    00d8) 0000000040000000-000000004000bfff o:0030 /memory/below4G/ram/sysram
    00f0) 0000000040017000-000000004007ffff o:0030 /memory/below4G/ram/sysram
    0108) 0000000041fdf000-0000000047ffffff o:0030 /memory/below4G/ram/sysram
    0120) 0000000048100000-000000007f3f1fff o:0030 /memory/below4G/ram/sysram
    ```
  The FDT memory location is in this example is in line `    0048) 0000000048000000-00000000480fffff o:0030 /memory/below4G/ram/fdt` and is located at physical address 0x48000000..0x480fffff. 
  It can be identified by the "fdt" name.



# Detailed design
  
Here is the detailed design for the `bootargs_fdt` program, ready to hand to a POSIX/QNX C developer.

---

## `bootargs_fdt` — Program Design Document

### 1. Purpose

A small CLI utility executed during QNX 8.0 startup (from initscript / shell scripts). It reads key=value options from the FDT (Flattened Device Tree) node `/chosen/bootargs` and makes them available to startup scripts — either by printing them to stdout or exporting them as environment variables (via `exec`-style shell eval).

---

### 2. Command-Line Interface

```
bootargs_fdt [OPTIONS] [KEY ...]
```

| Option | Long form | Description |
|---|---|---|
| `-d` | `--dump` | Dump the entire raw bootargs string to stdout and exit. Mutually exclusive with `-e`. |
| `-e` | `--export` | Print each matched key-value pair as `export KEY=VALUE` (shell-evaluable). Mutually exclusive with `-d`. |
| `-s` | `--strict` | Treat a missing key as an error (exit code 1). Without this, missing keys are silently ignored. |
| `-h` | `--help` | Print usage and exit 0. |

**Positional arguments (KEY …):** Zero or more key names to look up. When `-d` is not given and no keys are provided, it is an error (print usage, exit 1). When keys are provided without `-e`, print each match as `KEY=VALUE` (one per line) to stdout.

#### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Logical error (missing key in strict mode, bad arguments) |
| 2 | System error (FDT not found, mmap failed, libfdt load failed, etc.) |

#### Usage examples (in startup scripts)

```sh
# Dump entire bootargs string
bootargs_fdt -d

# Print selected keys
bootargs_fdt IP_ADDRESS HOSTNAME

# Export into current shell (use eval)
eval $(bootargs_fdt -e IP_ADDRESS GATEWAY)

# Strict mode — fail script if key missing
eval $(bootargs_fdt -e -s IP_ADDRESS) || display_msg "FATAL: no IP_ADDRESS"
```

---

### 3. Architecture Overview

```
main()
  │
  ├─ parse_args()              – parse CLI options and key list
  │
  ├─ load_libfdt()             – dlopen/dlsym for libfdt.so
  │
  ├─ locate_fdt_phys()         – walk_asinfo() to find "fdt" region
  │
  ├─ map_fdt()                 – mmap_device_memory() of FDT physical address
  │
  ├─ read_bootargs()           – libfdt: parse "/chosen" → "bootargs" property
  │
  ├─ process_bootargs()        – tokenize, filter, and output
  │
  └─ cleanup()                 – munmap, dlclose
```

---

### 4. Module / Function Design

#### 4.1 `main.c` — Entry point and orchestration

```c
int main(int argc, char *argv[]);
```

Calls the functions below in order. On any system error, prints a diagnostic to stderr and returns exit code 2. On logical errors (missing keys in strict mode), returns exit code 1.

---

#### 4.2 `args.h / args.c` — Argument parsing

```c
/* Parsed command-line arguments */
typedef struct {
    bool        dump_all;    /* -d */
    bool        export_mode; /* -e */
    bool        strict;      /* -s */
    const char **keys;       /* NULL-terminated array of requested key names */
    int         num_keys;
} bootargs_opts_t;

/*
 * Parse argc/argv into opts.
 * Returns 0 on success, -1 on error (prints usage to stderr).
 */
int parse_args(int argc, char *argv[], bootargs_opts_t *opts);
```

Implementation notes:
- Use `getopt()` (POSIX) with option string `"desh"`.
- Validate mutual exclusivity of `-d` and `-e`.
- If neither `-d` is set nor any keys are provided, print usage and return error.

---

#### 4.3 `libfdt_loader.h / libfdt_loader.c` — Dynamic loading of libfdt

```c
/* Function pointers mirroring the required libfdt API */
typedef struct {
    void       *handle;                         /* dlopen handle           */
    int       (*fdt_check_header)(const void *fdt);
    int       (*fdt_path_offset)(const void *fdt, const char *path);
    const void*(*fdt_getprop)(const void *fdt, int nodeoffset,
                              const char *name, int *lenp);
    uint32_t  (*fdt_totalsize)(const void *fdt);
} libfdt_api_t;

/*
 * Load libfdt.so via dlopen and resolve required symbols.
 * Returns 0 on success, -1 on failure (diagnostic to stderr).
 */
int load_libfdt(libfdt_api_t *api);

/*
 * Close the library handle.
 */
void unload_libfdt(libfdt_api_t *api);
```

Implementation notes:
- `dlopen("libfdt.so", RTLD_NOW)` — fail fast if any symbol missing.
- Resolve each function pointer with `dlsym()`. Check for NULL after each.
- Use `dlerror()` for diagnostics.
- Only the four symbols above are needed (minimise coupling).

---

#### 4.4 `fdt_locate.h / fdt_locate.c` — Locating the FDT in physical memory

```c
typedef struct {
    uint64_t phys_addr;  /* start physical address */
    uint64_t size;       /* length in bytes        */
} fdt_region_t;

/*
 * Walk asinfo entries via SYSPAGE_ENTRY / walk_asinfo() to find the
 * region whose name ends with "/fdt".
 * Returns 0 on success, -1 if no FDT region found.
 */
int locate_fdt(fdt_region_t *region);
```

Implementation notes:
- Include `<sys/syspage.h>` and `<sys/asinfo.h>`.
- Call `walk_asinfo("fdt", _CS_MACHINE, callback, &region)` — or manually iterate `SYSPAGE_ENTRY(asinfo)` entries.
- The callback (or loop) inspects each `asinfo_entry` name; look for a trailing path component equal to `"fdt"`.
- Use `__hwi_find_string()` or the string lookup macro from syspage to resolve the name index to a C string.
- Extract `entry->start` and `entry->end` → compute size = end - start + 1.

**Recommended approach — manual iteration** (more portable within QNX):
```c
struct asinfo_entry *as = SYSPAGE_ENTRY(asinfo);
unsigned num = _syspage_ptr->asinfo.entry_size
               ? (SYSPAGE_ENTRY_SIZE(asinfo) / _syspage_ptr->asinfo.entry_size)
               : 0;
for (unsigned i = 0; i < num; i++) {
    const char *name = __hwi_find_string(as[i].name);
    if (name && ends_with(name, "/fdt")) {
        region->phys_addr = as[i].start;
        region->size      = as[i].end - as[i].start + 1;
        return 0;
    }
}
```

---

#### 4.5 `fdt_map.h / fdt_map.c` — Memory-mapping the FDT

```c
/*
 * Map the FDT physical region into the process virtual address space.
 * Sets *fdt_ptr to the mapped base.
 * Returns 0 on success, -1 on failure.
 */
int map_fdt(const fdt_region_t *region, const libfdt_api_t *api,
            void **fdt_ptr, size_t *mapped_size);

/*
 * Unmap a previously mapped FDT.
 */
void unmap_fdt(void *fdt_ptr, size_t mapped_size);
```

Implementation notes:
- Use `mmap_device_memory(NULL, region->size, PROT_READ | PROT_NOCACHE, 0, region->phys_addr)`.
  - Requires `#include <sys/mman.h>` (QNX extension).
  - The process needs `PROCMGR_AID_MEM_PHYS` ability or root privilege (expected at startup).
- After mapping, call `api->fdt_check_header(fdt_ptr)` — if non-zero, the mapped memory is not a valid FDT → unmap and fail.
- Optionally re-map with the exact size from `api->fdt_totalsize(fdt_ptr)` if the asinfo region is much larger. This is an optimization, not a requirement.

---

#### 4.6 `bootargs.h / bootargs.c` — Extracting and processing bootargs

```c
/*
 * Retrieve the raw bootargs string from the FDT.
 * Returns a pointer into the mapped FDT (do NOT free).
 * Returns NULL on failure (node or property not found).
 */
const char *get_bootargs(const void *fdt, const libfdt_api_t *api);

/*
 * Tokenize bootargs into key=value pairs.
 * Bootargs is a space-separated string: "console=ttyS0 IP_ADDRESS=10.0.0.1/24 quiet"
 * Tokens without '=' are treated as flags (value is empty string).
 * Returns a dynamically allocated NULL-terminated array of kv_pair_t.
 */
typedef struct {
    char *key;
    char *value;   /* NULL if token has no '=' */
} kv_pair_t;

kv_pair_t *parse_bootargs(const char *bootargs);
void        free_kv_pairs(kv_pair_t *pairs);

/*
 * Lookup a key in the parsed pairs. Returns the value or NULL.
 */
const char *find_key(const kv_pair_t *pairs, const char *key);
```

Implementation of `get_bootargs()`:
```c
const char *get_bootargs(const void *fdt, const libfdt_api_t *api) {
    int chosen = api->fdt_path_offset(fdt, "/chosen");
    if (chosen < 0) return NULL;
    int len;
    const char *val = api->fdt_getprop(fdt, chosen, "bootargs", &len);
    return (val && len > 0) ? val : NULL;
}
```

---

#### 4.7 `output.h / output.c` — Formatting output

```c
/*
 * Dump the raw bootargs string to stdout, followed by newline.
 */
void dump_bootargs(const char *bootargs);

/*
 * Print selected key=value pairs to stdout.
 * In export mode:  "export KEY=VALUE\n" (shell-evaluable).
 * In normal mode:  "KEY=VALUE\n".
 *
 * Returns: number of keys NOT found.
 */
int output_keys(const kv_pair_t *pairs, const bootargs_opts_t *opts);
```

---

### 5. Data-Flow Diagram

```
┌──────────────┐      ┌──────────────┐      ┌──────────────────┐
│  walk_asinfo │─────▶│mmap_device_  │─────▶│  libfdt parsing  │
│  find "fdt"  │      │  memory()    │      │  /chosen/bootargs│
│  phys addr   │      │  → void *fdt │      │  → const char *  │
└──────────────┘      └──────────────┘      └────────┬─────────┘
                                                     │
                                              ┌──────▼──────┐
                                              │  tokenize   │
                                              │  key=value  │
                                              └──────┬──────┘
                                                     │
                          ┌──────────────────────────┬┘
                          │                          │
                    ┌─────▼─────┐            ┌───────▼───────┐
                    │ -d: dump  │            │ keys: filter  │
                    │ raw string│            │ & format out  │
                    └───────────┘            └───────────────┘
```

---

### 6. Header Dependencies and Build

#### Required QNX / POSIX headers

| Header | Used for |
|---|---|
| `<stdio.h>` | printf, fprintf |
| `<stdlib.h>` | exit, malloc, free |
| `<string.h>` | strdup, strtok_r, strcmp, strrchr |
| `<stdbool.h>` | bool type |
| `<unistd.h>` | getopt |
| `<dlfcn.h>` | dlopen, dlsym, dlclose, dlerror |
| `<sys/mman.h>` | mmap_device_memory, munmap |
| `<sys/syspage.h>` | SYSPAGE_ENTRY, syspage_ptr |
| `<sys/asinfo.h>` | asinfo_entry, walk_asinfo |
| `<stdint.h>` | uint64_t, uint32_t |
| `<errno.h>` | errno for error diagnostics |

#### Compilation (single translation unit is acceptable; multi-file for clarity)

```
qcc -Vgcc_ntoaarch64le -o bootargs_fdt \
    main.c args.c libfdt_loader.c fdt_locate.c fdt_map.c bootargs.c output.c \
    -ldl
```

- No direct linkage against `libfdt` — it is loaded at runtime via `dlopen`.
- Link with `-ldl` for dlopen/dlsym.
- Target: `aarch64le` (QNX 8.0 arm64).

#### File listing

```
qnx8/tools/bootargs_fdt/
├── main.c              # Entry point, orchestration
├── args.h / args.c     # CLI argument parsing
├── libfdt_loader.h/c   # dlopen/dlsym wrapper for libfdt.so
├── fdt_locate.h/c      # Locate FDT via syspage asinfo
├── fdt_map.h/c         # mmap FDT physical memory
├── bootargs.h/c        # Extract & parse bootargs from FDT
├── output.h/c          # Format and print results
└── Makefile / BUILD    # Build definition
```

---

### 7. Pseudocode for `main()`

```c
int main(int argc, char *argv[]) {
    bootargs_opts_t opts = {0};
    if (parse_args(argc, argv, &opts) != 0)
        return 1;

    libfdt_api_t api = {0};
    if (load_libfdt(&api) != 0) {
        fprintf(stderr, "bootargs_fdt: failed to load libfdt.so\n");
        return 2;
    }

    fdt_region_t region;
    if (locate_fdt(&region) != 0) {
        fprintf(stderr, "bootargs_fdt: FDT region not found in syspage asinfo\n");
        unload_libfdt(&api);
        return 2;
    }

    void  *fdt = NULL;
    size_t mapped_size = 0;
    if (map_fdt(&region, &api, &fdt, &mapped_size) != 0) {
        fprintf(stderr, "bootargs_fdt: failed to map FDT at 0x%lx\n",
                (unsigned long)region.phys_addr);
        unload_libfdt(&api);
        return 2;
    }

    const char *bootargs = get_bootargs(fdt, &api);
    if (!bootargs) {
        fprintf(stderr, "bootargs_fdt: /chosen/bootargs not found in FDT\n");
        unmap_fdt(fdt, mapped_size);
        unload_libfdt(&api);
        return 2;
    }

    int rc = 0;
    if (opts.dump_all) {
        dump_bootargs(bootargs);
    } else {
        kv_pair_t *pairs = parse_bootargs(bootargs);
        int missing = output_keys(pairs, &opts);
        if (opts.strict && missing > 0)
            rc = 1;
        free_kv_pairs(pairs);
    }

    unmap_fdt(fdt, mapped_size);
    unload_libfdt(&api);
    return rc;
}
```

---

### 8. Key Design Decisions & Rationale

| Decision | Rationale |
|---|---|
| **Dynamic loading of libfdt** (`dlopen`) | Manifest requirement. Avoids build-time dependency on an undocumented QNX library; fails gracefully if absent. |
| **Minimal libfdt surface** (4 symbols) | Only `fdt_check_header`, `fdt_path_offset`, `fdt_getprop`, `fdt_totalsize` are needed — reduces coupling. |
| **`mmap_device_memory` instead of mem** | QNX-idiomatic way to map physical memory. Works without devfs for mem. Required for startup context. |
| **Separate exit codes (0/1/2)** | Distinguishes "key not found" (recoverable) from "system failure" (fatal) — scripts can react differently. |
| **Shell-evaluable export mode (`-e`)** | Enables `eval $(bootargs_fdt -e KEY)` pattern — standard POSIX idiom for injecting variables into the calling shell. |
| **No heap allocation in FDT path** | The bootargs pointer is directly into the mmap'd FDT — only the tokenization step allocates (via `strdup`). Keeps memory footprint minimal for early boot. |
| **Silent ignore of missing keys by default** | Matches manifest requirement. Scripts that don't need strict checking can call without error handling. |

---

### 9. Testing Strategy (for developer reference)

| Test | Method |
|---|---|
| Argument parsing | Unit test `parse_args()` with various argv combinations on host |
| Bootargs tokenization | Unit test `parse_bootargs()` with sample strings: `"console=ttyS0 IP_ADDRESS=10.0.0.1/24 quiet debug"` |
| End-to-end on QEMU | Boot qemu-arm64virt with custom `-append` bootargs, run `bootargs_fdt -d` and `bootargs_fdt -e IP_ADDRESS` from initscript |
| Error paths | Verify exit code 2 when FDT is absent; exit code 1 with `-s` for missing key |

---

This design covers all requirements from the manifest: FDT discovery via asinfo, physical memory mapping, libfdt dynamic loading, bootargs parsing, and the three output modes (dump / print / export) with strict and non-strict error handling. A developer can implement each module independently and integrate via the `main()` orchestrator. 

Completed: *Produce detailed C design* (3/3)