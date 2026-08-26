#!/bin/zsh
flutter build web --release

rsync -r ./build/web /run/media/urzu-7/G-CODE
