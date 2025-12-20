if [ $# -ne 1 ]; then
    echo "Usage: $0 <number or nil>"
    exit 1
fi

new_value=$1
dir="lib/a940"

for file in $dir/*.ex; do
    if [ -f "$file" ]; then
        sed -i '' "s/\s*@debug_line *.*$/@debug_line $new_value/g" "$file"
    fi
done
