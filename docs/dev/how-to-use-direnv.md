# How to use direnv

As a developer, it can be better not to think too much about setting the right env variables as you enter a project.
[`direnv`](https://direnv.net/) aims at providing a solution.

As a quick guide as an openfoodfacts developer:

- install direnv on your system using the usual package manager
- For Mac users you need to know if you are in zsh or bash, since 10.15 (Catalina) zsh is set by default but to be sure type in terminal
  ```bash
  echo $SHELL
  #if it returns /bin/zsh You are in a zsh terminal, otherwise it's bash
  ```
- in your .bashrc (if you are in bash) add:
    ```bash
    # direnv
    eval "$(direnv hook bash)"
    ```
- in your .zshrc (if you are in zsh) add:
    ```bash
    # direnv
    eval "$(direnv hook zsh)"
    ```
  You have to adapt the direnv line according to what you use; see [direnv doc](https://direnv.net/docs/hook.html).
- in your project directory add a file, where you override variables from `.env`
  that you want to:

```
echo "setting up docker compose env"
export DOCKER_BUILDKIT=1
# The next two lines do the same thing in different ways; choose one.
export USER_UID=${UID}
export USER_UID=$(id -g)
```

- in your project directory, run `direnv allow .`
- in a new shell:
  - go to the project directory
  - direnv should trigger and load your variables
