# How to use VSCode

VSCode (or better the open source version [VSCodium](https://github.com/VSCodium/vscodium/))
may be used to edit files.

Here are some useful tricks.

## Perlcritic

* **Dev container:** the [perlcritic extension](https://marketplace.visualstudio.com/items?itemName=sfodje.perlcritic)
  is installed automatically, with `--profile /opt/product-opener/.perlcriticrc`
  pinned in settings. The pin matters: the extension pipes buffer text to
  `perlcritic` via stdin from the language server's own working directory, so
  without an explicit `--profile` the repo's `.perlcriticrc` is never found and
  you get default-profile violations (e.g. `RequireUseStrict` firing on files
  using `Modern::Perl`, `ProhibitSubroutinePrototypes` firing although the
  profile disables it). The pin also stops the extension from appending its
  default `--gentle` severity flag. This matches `make check_critic` (same
  binary, same profile, same repo root).
* **Host-side VS Code:** install the extension and add a `perlcritic.sh` at the root of your project with following content:
  ```bash
  #!/usr/bin/env bash
  . .envrc >/dev/null 2>&1
  docker compose run --rm --no-deps backend perlcritic "$@" 2>/dev/null
  ```
  the second line is useful only if you [use direnv](how-to-use-direnv.md)
* `chmod +x perlcritic.sh`
* patch perlcritic by editing its files, following [sfodje/perlcritic issue #26](https://github.com/sfodje/perlcritic/issues/26#issuecomment-1006411268)
* edit the perlcritic configuration in workspace to set the value (after adjusting the pathname for your own OFF setup):
  * Executable: `/path/to/your/own/OFF-server/perlcritic.sh`


## Perl Language Server

We use [perl-lsp](https://github.com/tree-sitter-perl/perl-lsp) (Rust, via
[Perl (perl-lsp)](https://marketplace.visualstudio.com/items?itemName=tree-sitter-perl.vscode-perl-lsp)
on the Marketplace): type inference, go-to-definition, find-references and
completion across files, with Moo/Moose/Mojolicious/DBIC awareness. It
replaces the old `richterger.perl` + `Perl::LanguageServer` setup (removed
from `cpanfile`), so no CPAN language server is installed anymore.

The server needs the container's `PERL5LIB` (`/opt/perl/local/lib/perl5`,
built from `cpanfile`) to resolve CPAN modules, so it always runs against
the backend Docker image used by `make up`.

* **Dev container** (`.devcontainer/devcontainer.json`): the extension is
  installed automatically and `perl-lsp.path` is pinned to
  `/usr/local/bin/perl-lsp`, which is baked into the image (see
  `Dockerfile`). No further setup — rebuild the image (`make build`) to
  pick up server updates.
* **Local VS Code** (editing from the host): install the `Perl (perl-lsp)`
  extension and point it at the Docker wrapper, which mounts the repo at
  the same absolute path inside and outside the container so `file://`
  URIs match:
  ```json
  {
      "perl-lsp.path": "/path/to/your/own/openfoodfacts-server/docker/perl-lsp-docker.sh"
  }
  ```
  (in your personal `.vscode/settings.json`, which is gitignored).
  Prerequisite: the backend image exists (`make build` or `make up`).
  OpenCode users get the same wiring out of the box via `opencode.jsonc`.
* **CLI** (CI-style batch diagnostics, no editor needed):
  ```bash
  ./docker/perl-lsp-docker.sh --check . --severity warning
  ```

## Perltidy (kaktus.perltidy-more)

The [perltidy-more extension](https://marketplace.visualstudio.com/items?itemName=kaktus.perltidy-more)
is installed automatically in the dev container, with
`"perltidy-more.profile": "/opt/product-opener/.perltidyrc"` pinned in
settings. The pin matters: the extension pipes buffer text to `perltidy` via
stdin with the *file's directory* as cwd, and perltidy does not search upwards
for `.perltidyrc` — so without the pin, files under `lib/` etc. are formatted
with perltidy defaults (e.g. `if ( $x == 1 )`) instead of the repo style (e.g.
`if ($x == 1)`), and `make check_perltidy` then fails on the result.

* **Host-side VS Code (no dev container):** there is no usable host `perltidy`
  to point at, so route through Docker with `docker/perltidy-docker.sh` (same
  backend image — and therefore same perltidy version — as CI). In your
  personal `.vscode/settings.json`:
  ```json
  {
      "perltidy-more.executable": "/path/to/your/own/openfoodfacts-server/docker/perltidy-docker.sh",
      "perltidy-more.profile": "/path/to/your/own/openfoodfacts-server/.perltidyrc"
  }
  ```
  The wrapper mounts the repo at the same absolute path inside and outside the
  container, so the absolute profile path resolves on both sides. (A
  workspace-relative `"docker/perltidy-docker.sh"` works too: the extension
  resolves it against the workspace.) Prerequisite: the image exists (`make
  build` or `make up`).

## Debugging Perl (dev container)

The dev container also installs the [Perl Debug
Adapter](https://marketplace.visualstudio.com/items?itemName=Nihilus118.perl-debugger)
(`Nihilus118.perl-debugger`, a `perl -d` Debug Adapter Protocol client; needs
`PadWalker`, which is in the `develop` section of `cpanfile`, so rebuild after
changing it). It only supports `launch` — no attach — which covers exactly the
Makefile-driven flow from the agent guide (`make test-unit test=additives.t
TEST_CMD="perl -d"` runs the `.t` directly under `perl -d`, no yath wrapper).

Inside the dev container you are already on the backend image: `perl`,
`PERL5LIB` (`/opt/product-opener/lib` + `/opt/perl/local/lib/perl5`) and the
workspace path (`/opt/product-opener`) are all correct, so no wrapper is
needed. Add to your **personal** `.vscode/launch.json` (gitignored, not
shareable):

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "perl",
            "request": "launch",
            "name": "Debug current Perl file",
            "program": "${workspaceFolder}/${relativeFile}",
            "cwd": "${workspaceFolder}",
            "stopOnEntry": true,
            "transport": "socket"
        },
        {
            "type": "perl",
            "request": "launch",
            "name": "Debug unit test (like make test-unit TEST_CMD=\"perl -d\")",
            "program": "${workspaceFolder}/tests/unit/${fileBasename}",
            "cwd": "${workspaceFolder}",
            "stopOnEntry": false,
            "transport": "socket"
        }
    ]
}
```

Open a `.pl`/`.pm`/`.t` file and start the matching configuration. `socket`
is the default transport and the only one that follows forks. Integration
tests get their services from the dev container itself (`postgres`,
`memcached`, `frontend`, … via `runServices`) plus the dependency stacks
(MongoDB, Keycloak, …) that `initializeCommand: make run_deps` starts.

Limits, stated plainly:

* **Live Apache/mod_perl workers cannot be breakpoint-debugged** with this
  adapter (no `attach` support). For those, the terminal-based remote flow
  (`Apache::DB` + `socat`, see `conf/apache2-docker/apache.conf` `PERLDB`
  block and `docker/perldb.yml`) is the only option — but `perldb.yml` is
  currently stale (it references a `perldb` build target and a `webnet`
  network that no longer exist), so expect to repair it first.
* Upstream's agent guide describes `make agent` worktree isolation, which this
  checkout predates. Launch debugging needs no fixed ports (loopback only),
  so it adds no new collision surface beyond what `make dev` already has.
  From plain host-side VS Code (no dev container), the adapter would need a
  Docker-wrapping `wrapperCommand` plus the same-path mount trick the LSP
  wrapper uses — not implemented; use the dev container.

## Remote container ?

**Note:** at the moment we do not support the
[Remote Container](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
extension.
While we can consider using it,
it has some drawbacks because not all the project is contained within the "backend" container.
For example everything related to nodejs is in the "frontend" container.
So it means making a quite complete Docker image on its own with all the tooling necessary.
