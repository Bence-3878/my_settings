#!/bin/bash

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-autosuggestions \
${ZSH_CUSTOM}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/web-search \
${ZSH_CUSTOM}/plugins/web-search
git clone https://github.com/agkozak/zsh-z ${ZSH_CUSTOM}/plugins/zsh-z
git clone https://github.com/zsh-users/zsh-history-substring-search \
${ZSH_CUSTOM}/plugins/zsh-history-substring-search
mkdir ~/bin

rm $HOME/.zshrc
ln -s $HOME/mis/zshrc $HOME/.zshrc

zsh