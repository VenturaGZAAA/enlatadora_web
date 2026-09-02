#!/bin/zsh

#rm -rf ./build/web

flutter build web --release

# Compress with brotli (higher compression)
cd build/web
find . -type f -not -name "*.br" -not -name "*.png" -not -name "*.jpg" -not -name "*.jpeg" -not -name "*.gif" -not -name "*.ico" | while read -r file; do
    if [[ $file != *.br ]]; then
        brotli -q 11 -k "$file"
        echo "Compressed with brotli: $file"
    fi
done

cd ...
rsync -r ./build/web /run/media/urzu-7/G-CODE
