#compdef kdeploy

_kdeploy() {
    local -a commands options

    commands=(
        'init:Initialize a new deployment project'
        'execute:Execute deployment tasks from file'
        'help:Show help information'
        'version:Show version information'
    )

    options=(
        '--dry-run[Show what would be done without executing]'
        '--limit[Limit to specific hosts (comma-separated)]'
        '--parallel[Number of parallel executions (default: 5)]'
    )

    _arguments -C \
        '1: :->cmds' \
        '*:: :->args'

    case "$state" in
        cmds)
            _describe -t commands 'kdeploy commands' commands
            ;;
        args)
            case $words[1] in
                execute)
                    if (( CURRENT == 2 )); then
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

_kdeploy "$@"