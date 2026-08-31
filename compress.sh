#!/bin/zsh

# Navigate to your Flutter web build directory
cd build/web

# Remove old compressed files
find . -name "*.gz" -type f -delete

# Compress all files with gzip at maximum compression
find . -type f -not -name "*.gz" -not -name "*.png" -not -name "*.jpg" -not -name "*.jpeg" -not -name "*.gif" -not -name "*.ico" | while read -r file; do
    # Skip files that are already compressed
    if [[ $file != *.gz ]]; then
        # Compress with maximum compression
        gzip -9 -k "$file"
        echo "Compressed: $file"
    fi
done

# For images, you might want to compress separately or skip
# Images are often already compressed

echo "✅ Compression complete!"

# Optional: Show size comparison
echo -e "\n📊 Size comparison:"
find . -type f \( -name "*.js" -o -name "*.css" -o -name "*.html" -o -name "*.json" \) -exec ls -lh {} \; | awk '{print $9, $5}'