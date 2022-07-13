# Using Gitpod for Remote Development

[Gitpod](https://gitpod.io) provides powerful ready-to-code developer environments in the cloud eliminating the friction
of setting up local environments and IDEs with Perl, Docker and plugins, making it possible for even new contributors to
OpenFoodFacts Server to get started in minutes instead of hours!

Note that while this how-to is tailored for Gitpod, using alternatives like [GitHub Codespaces][github-codespaces] should be
similar.

For the most part, development on Gitpod is similar to developing locally as documented
in the [quickstart guide](../introduction/dev-environment-quick-start-guide.md)
and [docker-developer-guide](docker-developer-guide.md), however accessing your dev-deployment of
`openfoodfacts-server` requires an extra step.

## Get Started

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/https://github.com/openfoodfacts/openfoodfacts-server/)
> Gitpod will automatically clone and open the repository for you in VSCode by default. It will also automatically build
> the project for you on opening and comes with Docker and other tools pre-installed making it one of the fastest ways
> to spin up an environment for `openfoodfacts-server`.

Once the repository is open in Gitpod, other instructions in the
[quick-start guide](../introduction/dev-environment-quick-start-guide.md) can be generally followed.

## Accessing your development instance of OpenFoodFacts Web

Since Gitpod runs your code in a remote machine, your dev-deployment spun up with `make dev` or `make up` will not
accessible when you open the default http://openfoodfacts.localhost in your browser. This occurs because the server
running on the remote machine is not accessible on your local network interface.

To overcome this, we can make use of SSH tunnel that listens to your local port 80 and forwards traffic to the port 80
of the remote machine. Gitpod makes it really simple to SSH into your dev environment by letting you copy the `ssh`
command required to reach your remote environment. To start, follow the ssh instructions on Gitpod's official
guide: [SSH for workspaces as easy as copy/paste][gitpod-ssh-guide]. Once you have copied the ssh command and ensure it
works as-is, add a `-L 80:localhost:80` to the command to make it look like:
`ssh -L 80:localhost:80 'openfoodfac-openfoodfac-tok-openfoodfac-r9f61214h9vt.ssh.ws-c.gitpod.io'`.

Once you execute the altered command in your terminal, you should be able to access OpenFoodFacts
on http://openfoodfacts.localhost just as documented in the quickstart guide!

[gitpod-ssh-guide]: https://www.gitpod.io/blog/copy-paste-ssh-workspace-access
[github-codespaces]: https://github.com/features/codespaces
