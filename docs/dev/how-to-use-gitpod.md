# How to using Gitpod for Remote Development

If your computer performance restricts you from developing, you can use [Gitpod](https://gitpod.io). 
Gitpod allows you to do the devs on an ephemeral environment. It is free for a maximum of 500 credits or 
50 hours per months (https://www.gitpod.io/pricing).

Gitpod provides a robust ready-to-code developer environment in the cloud eliminating the friction
of setting up local environments and IDEs with Perl, Docker and plugins, making it possible for even new contributors to
OpenFoodFacts Server to get started in minutes instead of hours!



Note that while this how-to is tailored for Gitpod, using alternatives like [GitHub Codespaces][github-codespaces] should be
similar.

For the most part, development on Gitpod is similar to developing locally as documented
in the [quickstart guide](how-to-quick-start-guide.md)
and [docker-developer-guide](how-to-develop-using-docker.md), however accessing your dev-deployment of
`openfoodfacts-server` requires an extra step.

## Connect GitHub and Gitpod
When you use Gitpod, you allow Gitpod to use your GitHub account.

In GitHub, you can review (and revoke if you stop using Gitpod) the access granted to Gitpod: click on your avatar on top right of the screen, then, Settings. In the left panel, under Integrations, click on Applications, then, Authorized OAuth Apps.

On the Gitpod side, you can also update what Gitpod is allowed to do with your GitHub account: click on your avatar on the top right of the screen, then, Settings. In the left panel, click on Integrations. The line for GitHub should be green. At the end of this line, click on the three dots, then Edit Permissions. '''If you want to create a pull request via Gitpod, you need to grant public_repo access.'''

## Get Started

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/openfoodfacts/openfoodfacts-server/)
> Gitpod will automatically clone and open the repository for you in VSCode by default. It will also automatically build
> the project for you on opening and comes with Docker and other tools pre-installed making it one of the fastest ways
> to spin up an environment for `openfoodfacts-server`.

Once the repository is open in Gitpod, other instructions in the
[quick-start guide](how-to-quick-start-guide.md) can be generally followed.

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

**Remark:** for some Linux distributions, the port 80 is reserved. A workaround is to switch to port 8080: in gitpod, open the .env file and replace the line PRODUCT_OPENER_PORT=80 by PRODUCT_OPENER_PORT=8080, then replace -L 80:localhost:80 by -L 8080:localhost:8080. **Rollback the changes on .env before to make a pull request!***  

**Remark:** the address to connect with ssh can change after few days. If you get a ```Connection closed by ... port 22``` simply go back to https://gitpod.io/workspaces and copy the new address.  

**Remark:** if you load the page after some changes but get a ```502 Bad Gateway``` check again your code. Something may be wrong with it. Eventually, try to comment the part you just coded to see if it works. 

Create an account to be able to edit products.

## Some commands
After you made devs and want to apply changes and see them on the website, you can run:  
```
$ docker compose restart 
```
```
$ make up  
```

If you face some difficulties, you can always look at the logs (use ctrl + c, to quit):  
```
$ make log  
```
```
$ make tail  
```
After development, before opening a pull request, run the following command:  
```
$ make checks  
```  