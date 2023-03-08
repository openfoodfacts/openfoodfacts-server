# How to use VSCode

VSCode (or better the open source version [VSCodium](https://github.com/VSCodium/vscodium/))
may be used to edit files.

Here are some useful tricks.

## Perlcritic

One way to have perlcritic work is the following:

* install the [perlcritic](https://marketplace.visualstudio.com/items?itemName=sfodje.perlcritic)
  extension
* add a `perlcritic.sh` at the root of your project with following content:
  ```bash
  #!/usr/bin/env bash
  . .envrc >/dev/null 2>&1
  docker-compose run --rm --no-deps backend perlcritic "$@" 2>/dev/null
  ```
  the second line is useful only if you [use direnv](how-to-use-direnv.md)
* `chmod +x perlcritic.sh`
* patch perlcritic by editing its files, following [sfodje/perlcritic issue #26](https://github.com/sfodje/perlcritic/issues/26#issuecomment-1006411268)
* the edit perlcritic configuration in workspace to set those values:
  * Executable: `/home/alex/docker/off-server/perlcritic.sh`


## Perl Language Server

The extension [Language Server and Debugger](https://marketplace.visualstudio.com/items?itemName=richterger.perl) is less easy to work with !

**Note:** This setup does not work yet, but might not be so far. It is probably due to https://github.com/richterger/Perl-LanguageServer/issues/131

* install the extension
* add a script `shell-into-appserver.sh` in the project:
  ```bash
  #!/usr/bin/env bash
  declare -x PATH=$PATH:/usr/local/bin/
  source .envrc
  COMMAND=$(echo "$@" | sed 's/^.*perl /perl /')
  >&2 echo "launching $COMMAND"
  docker-compose run --rm --no-deps -T -p 127.0.0.  1:13603:13603 backend $COMMAND
  ```
  Note: the second line is useful only if you [use direnv](how-to-use-direnv.md)
* `chmod +x shell-into-appserver.sh`
* Edit workspace settings to have those settings:
  ```json
      "perl": {
          "enable": true,
          "perlInc": ["/opt/product-opener/lib", "/opt/perl/local/lib/perl5"],
          "ignoreDirs": ["/opt/perl/local/lib/perl5", ".  vscode"],
          "fileFilter": [".pm", ".pl", ".t"],
          "sshAddr": "dummy",
          "sshUser": "dummy",
          "sshCmd": "./shell-into-appserver.sh",
          "sshWorkspaceRoot": "/opt/product-opener",
          "logLevel": 2
      },
  ```

## Remote container ?

**Note:** at the moment we do not support the
[Remote Container](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
extension.
While we can consider using it,
it has some drawback because not all the project is contained within the "backend" container.
For example all that concern nodejs is in the "frontend" container.
So it means making a quite complete Docker image on its own with all the tooling necessary.