# Use direnv

As a developper, it can be better not to think too much about setting right env variables as you enter a project.
[`direnv`](https://direnv.net/) aims at providing a solution.

As a quick guide as an openfoodfacts developper:

- install direnv on your system using usual package manager
- in your .bashrc add:
    ```bash
    # direnv
    eval "$(direnv hook bash)"
    # docker-compose specific env file
    alias docker-compose=docker-compose --env-file=${ENV_FILE:-.env}
    ```
  you have adapt the direnv line according to what you use, see [direnv doc](https://direnv.net/docs/hook.html)
- to use `my-env`, in your project directory add a file:
```
echo "setting up .my-env"
export ENV_FILE=.my-env
```
- in project directory, run `direnv allow .`
- in a new shell:
  - go in project directory
  - you should have direnv trigger and load `ENV_FILE`