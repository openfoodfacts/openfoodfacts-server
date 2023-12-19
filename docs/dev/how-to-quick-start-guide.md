# How to setup the Dev environment (quick start guide)

This guide will allow you to rapidly build a ready-to-use development environment for **Product Opener** running in Docker.
As an alternative to setting up your environment locally, follow the [Gitpod how-to guide](how-to-use-gitpod.md)
to instantly provision a ready-to-code development environment in the cloud.

First setup time estimate is `~10min` with the following specs:
* `8 GB` of RAM dedicated to Docker client
* `6` cores dedicated to Docker client
* `12 MB/s` internet speed

## 1. Prerequisites

**Docker** is the easiest way to install the Open Food Facts server, play with it, and even modify the code.

Docker provides an isolated environment, very close to a Virtual Machine. This environment contains everything required to launch the Open Food Facts server. There is **no need to install** Perl, Perl modules, Nginx, nor Apache separately.

> **_NOTE:_**  New to Perl? Check [how to learn perl](how-to-learn-perl.md)!

**Installation steps:**
- [Install Docker CE](https://docs.docker.com/install/#supported-platforms)
> If you run e.g. Debian, don't forget to add your user to the `docker` group!
- [Install Docker Compose](https://docs.docker.com/compose/install/)
- [Enable command-line completion](https://docs.docker.com/compose/completion/)

### Windows Prerequisites

When running with Windows, install [Docker Desktop](https://www.docker.com/products/docker-desktop/) **which will cover all of the above**.

The Make tasks use a number of Linux commands, such as rm and nproc, so it is recommeded to run Make commands from the Git Bash shell. In addition, the following need to be installed and included in the PATH:

- [Make for Windows](http://gnuwin32.sourceforge.net/packages/make.htm)
- [wget for windows](https://eternallybored.org/misc/wget/) (In order to download the full product database). If you want to download wget with the executable, copy the wget.exe file to C:/Windows/System32 and you are done.

The process of cloning the repository will create a number of symbolic links which require specific permissions under Windows. In order to do this you can use any one of these alternatives:

 - Use an Administrative command prompt for all Git commands
 - Completely disable UAC
 - Specifically grant the [Create symbolic links](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/create-symbolic-links) permission to your user

Make sure you also activated the [Developper mode](https://learn.microsoft.com/en-us/windows/apps/get-started/enable-your-device-for-development) on your device.

## 2. Clone the repository from GitHub

> _You must have a GitHub account if you want to contribute to Open Food Facts development, but it’s not required if you just want to see how it works._


> _Be aware Open Food Facts server takes more than 1.3 GB (2019/11)._

Choose your prefered way to clone, either:

### On Windows:

If you are running Docker on Windows, please use the following git clone command:

```console
git clone -c core.symlinks=true https://github.com/openfoodfacts/openfoodfacts-server.git
```
or
```console
git clone -c core.symlinks=true git@github.com:openfoodfacts/openfoodfacts-server.git
```

### On other systems:

```console
git clone git@github.com:openfoodfacts/openfoodfacts-server.git
```

or

```console
git clone https://github.com/openfoodfacts/openfoodfacts-server.git
```

Go to the cloned directory:

```console
cd openfoodfacts-server/
```

## 3. [Optional] Review Product Opener's environment

> _Note: you can skip this step for the first setup since the default `.env` in the repo contains all the default values required to get started._

Before running the `docker-compose` deployment, you can review and configure
Product Opener's environment (`.env` file).

The `.env` file contains ProductOpener default settings:

| Field | Description |
| ----------------------------------------------------------------- | --- |
| `PRODUCT_OPENER_DOMAIN`                                           | Can be set to different values based on which **OFF flavor** is run.|
| `PRODUCT_OPENER_PORT`                                             | can be modified to run NGINX on a different port. Useful when running **multiple OFF flavors** on different ports on the same host. <br> Default port: `80`.|
| `PRODUCT_OPENER_FLAVOR`                                           | Can be modified to run different flavors of OpenFoodFacts, amongst `openfoodfacts` (default), `openbeautyfacts`, `openpetfoodfacts`, `openproductsfacts`.|
| `PRODUCT_OPENER_FLAVOR_SHORT`                                     | can be modified to run different flavors of OpenFoodFacts, amongst `off` (default), `obf`, `oppf`, `opf`.|
| `PRODUCERS_PLATFORM`                                              | can be set to `1` to build / run the **producer platform**.|
| `ROBOTOFF_URL`                                                    | can be set to **connect with a Robotoff instance**.|
| `QUERY_URL`                                                       | can be set to **connect with a Query instance**.|
| `REDIS_URL` | can be set to **connect with a Redis instance for populating the search index**.|
| `GOOGLE_CLOUD_VISION_API_KEY`                                     | can be set to **enable OCR using Google Cloud Vision**.|
| `CROWDIN_PROJECT_IDENTIFIER` and `CROWDIN_PROJECT_KEY`            | can be set to **run translations**.|
| `GEOLITE2_PATH`, `GEOLITE2_ACCOUNT_ID` and `GEOLITE2_LICENSE_KEY` | can be set to **enable Geolite2**.|
| `TAG`                                                             | Is set to `latest` by default, but you can specify any Docker Hub tag for the `frontend` / `backend` images. <br> Note that this is useful only if you use pre-built images from the Docker Hub (`docker/prod.yml` override); the default dev setup (`docker/dev.yml`) builds images locally|

The `.env` file also contains some useful Docker Compose variables:
* `COMPOSE_PROJECT_NAME` is the compose project name that sets the **prefix to every container name**. Do not update this unless you know what you're doing.
* `COMPOSE_FILE` is the `;`-separated list of Docker compose files that are included in the deployment:
  * For a **development**-like environment, set it to `docker-compose.yml;docker/dev.yml` (default)
  * For a **production**-like environment, set it to `docker-compose.yml;docker/prod.yml;docker/mongodb.yml`
  * For more features, you can add:
    * `docker/admin-uis.yml`: add the Admin UIS container
    * `docker/geolite2.yml`: add the Geolite2 container
    * `docker/perldb.yml`: add the Perl debugger container
* `COMPOSE_SEPARATOR` is the separator used for `COMPOSE_FILE`.

**Note:**
Instead of modifying `.env` (with the risk commit it inadvertently),
You can also set needed variables in your shell, they will override `.env` values.
Consider creating a `.envrc` file that you source each time you need to work on the project.
On linux and macOS, you can automatically do it if you [use direnv](how-to-use-direnv.md).

## 4. Build your dev environment

From the repository root, run:

```console
make dev
```

> **Note:**
> 
> If you are using Windows, you may encounter issues regarding this command. Take a look at the **Troubleshooting** section further in this tutorial.

> **Note:**
>
> If docker complains about
> ```
> ERROR: could not find an available, non-overlapping IPv4 address pool among the defaults to assign to the network
> ```
> It can be solved by adding `{"base": "172.80.0.0/16","size": 24}, {"base": "172.90.0.0/16","size": 24}` to `default-address-pools` in `/etc/docker/daemon.json` and then restarting the docker daemon.
> _Credits to https://theorangeone.net/posts/increase-docker-ip-space/ for this solution._

The command will run 2 subcommands:
* `make up`: **Build and run containers** from the local directory and bind local code files, so that you do not have to rebuild everytime.
* `make import_sample_data`: **Load sample data** into `mongodb` container (~100 products).

***Notes:***

* The first build can take between 10 and 30 minutes depending on your machine and internet connection (broadband connection heavily recommended, as this will download Docker base images, install Debian and Perl modules in preparation of the final container image).

* You might not immediately see the test products: create an account, login, and they should appear.

* For a full description of available make targets, see [Docker / Makefile commands](ref-docker-commands.md)

**Hosts file:**

Since the default `PRODUCT_OPENER_DOMAIN` in the `.env` file is set to `openfoodfacts.localhost`, add the following to your hosts file (Windows: `C:\Windows\System32\drivers\etc\hosts`; Linux/MacOSX: `/etc/hosts`):

```text
127.0.0.1 world.openfoodfacts.localhost fr.openfoodfacts.localhost static.openfoodfacts.localhost ssl-api.openfoodfacts.localhost fr-en.openfoodfacts.localhost
```

**You're done ! Check http://openfoodfacts.localhost/ !**

### Going further

To learn more about developing with Docker, see the [Docker developer's guide](how-to-develop-using-docker.md).

To have all site page on your dev instance, see [Using pages from openfoodfacts-web](how-to-use-pages-from-openfoodfacts-web.md)

[Using Repl](how-to-use-repl.md) offers you a way to play with perl.

Specific notes are provide on [applying AGRIBALYSE updates to support the Ecoscore](how-to-update-agribalyse-ecoscore.md) calculation.

## Visual Studio Code

**WARNING**: Devcontainer support is currently experimental. It's recommended to run the normal docker commands before, and stop the containers: `make dev down`. Note that `make dev`, `make test`, and so on may currently conflict with the devcontainer.

This repository comes with a configuration for Visual Studio Code (VS Code) [development containers (devcontainer)](https://code.visualstudio.com/docs/remote/containers). This enables some Perl support in VS Code without the need to install the correct Perl version and modules on your local machine.

To use the devcontainer, install [prerequisites](#1-prerequisites), [clone the repository from GitHub](#2-clone-the-repository-from-github), and [(optionally) review Product Opener's environment](#3-optional-review-product-openers-environment). Additionally, install [Visual Studio Code](https://code.visualstudio.com/). VS Code will automatically recommend some extensions, but if you don't want to install all of them, please do install [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) manually. You can then use the extension command **Remote-Containers: Reopen Folder in Container**, which will automatically build the container and start the services. No need to use `make`!

## Troubleshooting

### make dev error: make: command not found

When running `make dev`:

```console
bash: make: command not found
```

**Solution:** 
Click the Windows button, then type “environment properties” into the search bar and hit Enter. Click Environment Variables, then under System variables choose Path and click Edit. Click New and insert C:\Program Files (x86)\GnuWin32\bin, then save the changes. Open a new terminal and test that the command works.
(see [Make Windows](https://pakstech.com/blog/make-windows/) for more)

### make dev error: [build_lang] Error 2 - Could not load taxonomy: /mnt/podata/taxonomies/traces.result.sto

When running `make dev`:

```console
<h1>Software error:</h1>
<pre>Could not load taxonomy: /mnt/podata/taxonomies/traces.result.sto at /opt/product-opener/lib/ProductOpener/Tags.pm line 1976.
Compilation failed in require at /opt/product-opener/scripts/build_lang.pl line 31, &lt;DATA&gt; line 2104.
BEGIN failed--compilation aborted at /opt/product-opener/scripts/build_lang.pl line 31, &lt;DATA&gt; line 2104.
</pre>
<p>
For help, please send mail to this site's webmaster, giving this error message
and the time and date of the error.
</p>
[Tue Apr  5 19:36:40 2022] build_lang.pl: Could not load taxonomy: /mnt/podata/taxonomies/traces.result.sto at /opt/product-opener/lib/ProductOpener/Tags.pm line 1976.
[Tue Apr  5 19:36:40 2022] build_lang.pl: Compilation failed in require at /opt/product-opener/scripts/build_lang.pl line 31, <DATA> line 2104.
[Tue Apr  5 19:36:40 2022] build_lang.pl: BEGIN failed--compilation aborted at /opt/product-opener/scripts/build_lang.pl line 31, <DATA> line 2104.
make: *** [build_lang] Error 2
```

**Solution:**
Project needs Symlinks to be enabled.
traces.result.sto is a symlink to allergens.result.sto

You have to enable the 'Developer Mode' in order to use the symlinks.
To enable Developer Mode:

* on windows 10: Settings > Update & Security > 'For developers' …
* on windows 11: Settings > Privacy & Security > 'For developers' …

and turn on the toggle for *Developer Mode*.

On Windows systems, the git repository needs to be cloned with symlinks enabled.

You need to remove current directory where you clone the project, and clone the project again, using right options:

```console
git clone -c core.symlinks=true git@github.com:openfoodfacts/openfoodfacts-server.git
```

### 'rm' is not recognized as an internal or external command

When running `make import_prod_data` or some other commands.

**Solution:**

Use the Git Bash shell to run the make commands in windows so that programs like nproc and rm are found.

### System cannot find wget

When running `make import_prod_data`.

```console
process_begin: CreateProcess(NULL, wget --no-verbose https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.tar.gz, ...) failed.
make (e=2): The system cannot find the file specified.
```

You need to install [wget for windows](https://eternallybored.org/misc/wget/). The referenced version is able to use the Windows Certificate Store, whereas the standard [gnuwin32 version](https://gnuwin32.sourceforge.net/packages/wget.htm) will give errors about not being able to verify the server certificate.

### make: *** [Makefile:154: import_sample_data] Error 22 

When running `make import_sample_data`

```console
<hl>Software error:</h1>
<pre>MongoDB: :SelectionError: No writable server available. MongoDB server status:
Topology type: Single; Member status:
mongodb:27017 (type: Unknown, error: MongoDB::NetworkError: Could not connect to 'mongodb:27017': Temporary failure in name resolution )
</pre>
<p>
For help, please send mail to this site's webmaster, giving this error message
and the time and date of the error.
<p>
[Sat Dec 17 19:52:21 2022] update_all_products from_dir_in_mongodb.pl: MongoDB::SelectionError: No writable server available. MongoDB server status:

[Sat Dec 17 19:52:21 2022] update_all_products from_dir_in_mongodb.pl: Topology type: Single; Member status:

[Sat Dec 17 19:52:21 2022] update_all_products from_dir_in_mongodb.pl: mongodb:27017 (type: Unknown, error: MongoDB::NetworkError: Could not connect to 'mongodb:27017': Temporary failure in name resolution )

make: *** [Makefile:154: import_sample data] Error 22
```

**Solution:**
The cause of this issue is that you already have the mongodb database server running on your local machine at port 27017. 

*For linux users:*

First stop the MongoDB server from your OS
```console
sudo systemctl stop mongod
```

Then check that mongod is stopped with:
```console
systemctl status mongod | grep Active
```
> **Note:**
> The output of this command should be:
  `Active: inactive (dead)`

Then, executed this:
```console
docker-compose up 
```
> **Note:**
> To know more about docker-compose commands do read [this guide](how-to-develop-using-docker.md)

### make dev error: [build_lang] Error 13 - can't write into /mnt/podata/data/Lang.openfoodfacts.localhost.sto

When running `make dev`:

```console
<h1>Software error:</h1>
<pre>can't write into /mnt/podata/data/Lang.openfoodfacts.localhost.sto: Permission denied at /opt/product-opener/lib/ProductOpener/Store.pm line 234.
</pre>
<p>
For help, please send mail to this site's webmaster, giving this error message
and the time and date of the error.

</p>
make: *** [Makefile:126: build_lang] Error 13
```

**Solution:**

Use the powershell/cmd to run the make dev commands in windows.
