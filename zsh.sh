#!/bin/bash

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-autosuggestions \
${ZSH_CUSTOM:-~/mis/zsh}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
${ZSH_CUSTOM:-~/mis/zsh}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/web-search \
${ZSH_CUSTOM:-~/mis/zsh}/plugins/web-search
mkdir ~/bin

rm $HOME/.zshrc
mv $HOME/mis/.zshrc $HOME

zsh