# source it before launching platform
set -o allexport; source env.obf; set +o allexport

set_ps1 () {
    export PS1=${PS1:-}"(obf) "
}
set_ps1;
