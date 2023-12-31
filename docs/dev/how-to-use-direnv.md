# How to use direnv

As a developer, it can be better not to think too much about setting right env variables as you enter a project.
[`direnv`](https://direnv.net/) aims at providing a solution.

As a quick guide as an openfoodfacts developer:

- install direnv on your system using usual package manager
- in your .bashrc add:
    ```bash
    # direnv
    eval "$(direnv hook bash)"
    ```
  you have adapt the direnv line according to what you use, see [direnv doc](https://direnv.net/docs/hook.html)
- In your project directory add a file, where you superseed variables from `.env`
  that you wan't to

```
echo "setting up docker compose env"
export DOCKER_BUILDKIT=1
export USER_UID=${UID}
export USER_UID=$(id -g)
```

- in project directory, run `direnv allow .`
- in a new shell:
  - go in project directory
  - you should have direnv trigger and load your variables
