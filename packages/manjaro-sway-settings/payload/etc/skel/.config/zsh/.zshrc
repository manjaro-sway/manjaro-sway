# manjaro base cfg

# Source manjaro-zsh-configuration
if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
  source /usr/share/zsh/manjaro-zsh-config
fi
# Use manjaro zsh prompt
if [[ -e /usr/share/zsh/manjaro-zsh-prompt ]]; then
  source /usr/share/zsh/manjaro-zsh-prompt
fi

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
source ~/.zshrc