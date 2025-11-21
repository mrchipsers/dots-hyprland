function fish_prompt -d "Write out the prompt"
    # This shows up as USER@HOST /home/user/ >, with the directory colored
    # $USER and $hostname are set by fish, so you can just use them
    # instead of using `whoami` and `hostname`
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

#From fishbang: https://github.com/BrewingWeasel/fishbang/tree/master

function last_history_item
  echo $history[1]
end

function sudo_last_history_item
  echo sudo $history[1]
end

function nth_history_item
  # Times by negative one because in fish $history[1] is the last used command
  # while running !1 in bash returns the first command in your history ($history[-1] in fish)
  set index (math (echo $argv[1] | cut -c 2- ) x -1)
  echo $history[$index]
end

function _nth_history_arg
  echo $history[1] | read -t --list args
  echo $args[(math $argv[1] + 1)]
end

function last_history_arg
  echo $history[1] | read -t --list args
  echo $args[-1]
end

function first_history_arg
  echo $history[1] | read -t --list args
  echo $args[2]
end

function history_args
  echo (string split --max 1 " " $history[1])[2]
end

function nth_history_arg
  _nth_history_arg (echo $argv[1] | cut -c 3-)
end

function history_prefix_search
  set cmd (echo $argv[1] | cut -c 2- )
  history -p $cmd | head -n 1
end

function history_search
  set cmd (echo $argv[1] | cut -c 3- )
  history $cmd | head -n 1
end


# Commmands
abbr -a bang_history_prefix_search --position anywhere --regex '!([a-zA-Z0-9_.-]+)' --function history_prefix_search # !dnf returns the last command that started with dnf
abbr -a bang_history_search --position anywhere --regex '!\?([a-zA-Z0-9_.-]+)' --function history_search # !?abc returns the last command that included abc

abbr -a bang_negative_nth_history_item --position anywhere --regex '!-?([0-9]+)' --function nth_history_item # !3 returns the 3rd command used. !-3 returns the 3rd most recent command used.
abbr -a !! --position anywhere --function last_history_item # !! returns the last command. Taken from the fish documentation
abbr -a please --position anywhere --function sudo_last_history_item # !! returns the last command as sudo.

# Arguments
abbr -a !^ --position anywhere --function first_history_arg # !^ returns the first argument of the last command
abbr -a !\$ --position anywhere --function last_history_arg # !$ returns the last argument of the last command
abbr -a !\* --position anywhere --function history_args # !* returns all arguments of the last command
abbr -a bang_nth_arg --position anywhere --regex '!:([0-9]+)' --function nth_history_arg # !$ returns the last argument of the last command

if status is-interactive # Commands to run in interactive sessions can go here

    # No greeting
    set fish_greeting

    # Use starship
    starship init fish | source
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    alias pamcan pacman
    alias ls 'eza --icons'
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias q 'qs -c ii'
    
end
