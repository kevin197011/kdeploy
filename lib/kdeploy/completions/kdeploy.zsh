#compdef kdeploy

_kdeploy() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    local -a commands
    commands=(
        'init:Initialize a new deployment project'
        'execute:Execute deployment tasks from file'
        'help:Show help information'
        'version:Show version information'
    )

    local -a options
    options=(
        '--dry-run[Show what would be done without executing]'
        '--limit[Limit to specific hosts (comma-separated)]'
        '--parallel[Number of parallel executions (default: 5)]'
    )

    _arguments \
        '1: :->command' \
        '*: :->args'

    case $state in
        command)
            _describe -t commands 'kdeploy commands' commands
            ;;
        args)
            case $words[2] in
                execute)
                    if [[ $CURRENT -eq 3 ]]; then
                        _files -g "*.rb"
                    else
                        _values 'options' $options
                    fi
                    ;;
                init)
                    _files -/
                    ;;
                help)
                    _describe -t commands 'kdeploy commands' commands
                    ;;
            esac
            ;;
    esac
}

compdef _kdeploy kdeploy