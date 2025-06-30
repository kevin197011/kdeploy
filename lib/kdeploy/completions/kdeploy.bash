# kdeploy bash completion
_kdeploy_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Main commands
    opts="init execute help version"

    # Handle different cases
    case "${prev}" in
        kdeploy)
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        execute)
            # Complete with .rb files
            COMPREPLY=( $(compgen -f -X '!*.rb' -- ${cur}) )
            return 0
            ;;
        init)
            # Complete with directories
            COMPREPLY=( $(compgen -d -- ${cur}) )
            return 0
            ;;
        help)
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        *)
            # If we have a .rb file, suggest options
            if [[ "${COMP_WORDS[@]}" =~ "execute" ]] && [[ "${COMP_WORDS[@]}" =~ ".rb" ]]; then
                COMPREPLY=( $(compgen -W "--dry-run --limit --parallel" -- ${cur}) )
                return 0
            fi
            ;;
    esac
}

complete -F _kdeploy_completion kdeploy