#SET definitions
set noswapfile # no swap files

#ZSH distribution
export ZSH=$HOME/.oh-my-zsh
export TERM="xterm-256color"
#THEME	
ZSH_THEME="powerlevel9k/powerlevel9k"

#USERNAME
DEFAULT_USER=$USER

COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
)

source $ZSH/oh-my-zsh.sh



# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

#ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"
#

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

[ -z "$TMUX"  ] && { tmux attach || exec tmux new-session;}

# ALIASES
alias copy="xclip -selection clipboard"
