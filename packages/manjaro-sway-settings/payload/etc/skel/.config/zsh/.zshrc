# base config for oh my zsh
source /usr/share/oh-my-zsh/zshrc

# oh my zsh overrides
plugins=(
    archlinux
    git
)

ZSH_THEME="agnoster"

[ -d ~/.config/zsh/config.d/ ] && source ~/.config/zsh/config.d/*

source $ZSH/oh-my-zsh.sh

# Source manjaro config
source ~/.zshrc

alias ssh="TERM=xterm-256color ssh"
