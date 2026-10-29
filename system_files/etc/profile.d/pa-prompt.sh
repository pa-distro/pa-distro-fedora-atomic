# PA Desktop — prompt bash in stile Parrot (verde/rosso), solo shell interattive.
# Non sostituisce /etc/bashrc né ~/.bashrc: si aggiunge e resta sovrascrivibile.

[ -n "${BASH_VERSION:-}" ] || return 0
case $- in
    *i*) ;;
    *) return 0 ;;
esac

pa_prompt_command() {
    local exit=$?
    local user_color='\[\e[0;39m\]'
    local user='\u'

    if [ "${EUID}" -eq 0 ]; then
        user_color='\[\e[01;31m\]'
        user='root'
    fi

    local status=''
    if [ "${exit}" -ne 0 ]; then
        status='\[\e[0;37m\][✗]\[\e[0;31m\]─'
    fi

    PS1="\[\e[0;31m\]┌──${status}${user_color}${user}\[\e[01;33m\]@\[\e[01;96m\]\h\[\e[0;31m\]]─[\[\e[0;32m\]\w\[\e[0;31m\]]\n\[\e[0;31m\]└──╼ \[\e[0m\]\[\e[01;33m\]\$\[\e[0m\] "
}
PROMPT_COMMAND="pa_prompt_command${PROMPT_COMMAND:+;${PROMPT_COMMAND}}"
