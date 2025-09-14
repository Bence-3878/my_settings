alias kra="if [ ! -d \"kra\" ]; then mkdir kra; fi; if [ -d \"*.jpg.kra\" ]; then mv *.jpg.kra kra; fi; if [ -d \"*~\" ]; then rm *~; fi; if [ -d \"kra/*~\" ]; then rm kra/*~; fi;"
alias clion="nohup ~/JetBrains/CLion/bin/clion.sh &"
alias pycharm="nohup ~/JetBrains/pycharm/bin/pycharm.sh &"
alias zshconfig="mirco ~/.zshrc"