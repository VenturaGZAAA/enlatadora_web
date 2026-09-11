#!/bin/zsh

rm -rf ./build/web

flutter build web --release --dart-define-from-file=config_esp.json

cd build/web || exit 1

# --- Compress with brotli (higher compression) ---
echo "Compressing with brotli..."
find . -type f -not -name "*.br" -not -name "*.gz" \
    -not -name "*.png" -not -name "*.jpg" -not -name "*.jpeg" \
    -not -name "*.gif" -not -name "*.ico" -not -name "*.svg" \
    -not -name "*.webp" -not -name "*.woff" -not -name "*.woff2" | while read -r file; do
    # Skip if .br already exists
    if [[ ! -f "${file}.br" ]]; then
        brotli -q 11 -k "$file"
        echo "  Brotli: $file.br"
    fi
done

# --- Compress with gzip (widely supported) ---
echo "Compressing with gzip..."
find . -type f -not -name "*.br" -not -name "*.gz" \
    -not -name "*.png" -not -name "*.jpg" -not -name "*.jpeg" \
    -not -name "*.gif" -not -name "*.ico" -not -name "*.svg" \
    -not -name "*.webp" -not -name "*.woff" -not -name "*.woff2" | while read -r file; do
    # Skip if .gz already exists
    if [[ ! -f "${file}.gz" ]]; then
        gzip -k -9 "$file"
        echo "  Gzip: $file.gz"
    fi
done

cd ..

# --- Sync to SD card (adjust path if needed) ---
rsync -r ./web /run/media/urzu-7/G-CODE

echo "✅ Deployment complete."