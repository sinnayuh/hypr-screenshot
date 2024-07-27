#!/usr/bin/env sh

# Restores the shader after screenshot has been taken
restore_shader() {
    if [ -n "$shader" ]; then
        hyprshade on "$shader"
    fi
}

# Saves the current shader and turns it off
save_shader() {
    shader=$(hyprshade current)
    hyprshade off
    trap restore_shader EXIT
}

save_shader # Saving the current shader

if [ -z "$XDG_PICTURES_DIR" ]; then
    XDG_PICTURES_DIR="$HOME/Pictures"
fi

scrDir=$(dirname "$(realpath "$0")")
source $scrDir/globalcontrol.sh
swpy_dir="${confDir}/swappy"
save_dir="${2:-$XDG_PICTURES_DIR/Screenshots}"
save_file=$(date +'%y%m%d_%Hh%Mm%Ss_screenshot.png')
full_path="${save_dir}/${save_file}"

mkdir -p $save_dir
mkdir -p $swpy_dir
echo -e "[Default]\nsave_dir=$save_dir\nsave_filename_format=$save_file" >$swpy_dir/config

# Function to upload screenshot
upload_screenshot() {
    local file="$1"
    curl -H "authorization: {BEARER_TOKEN}" \
         https://{HOSTNAME}/api/upload \
         -F file=@"$file" \
         -H "Content-Type: multipart/form-data" \
         -H "Embed: true" | \
    jq -r '.files[0]' | tr -d '\n' | wl-copy
}

function print_error
{
    cat <<"EOF"
    ./screenshot.sh <action>
    ...valid actions are...
        p  : print all screens
        s  : snip current screen
        sf : snip current screen (frozen)
        m  : print focused monitor
        u  : snip current screen (frozen) and upload
EOF
}

case $1 in
p) # print all outputs
    grimblast copysave screen "$full_path" && restore_shader && swappy -f "$full_path" -o "$full_path" ;;
s) # drag to manually snip an area / click on a window to print it
    grimblast copysave area "$full_path" && restore_shader && swappy -f "$full_path" -o "$full_path" ;;
sf) # frozen screen, drag to manually snip an area / click on a window to print it
    grimblast --freeze copysave area "$full_path" && restore_shader && swappy -f "$full_path" -o "$full_path" ;;
m) # print focused monitor
    grimblast copysave output "$full_path" && restore_shader && swappy -f "$full_path" -o "$full_path" ;;
u) # frozen screen, drag to manually snip an area / click on a window to print it, then upload
    grimblast --freeze copysave area "$full_path" && restore_shader
    if [ -f "$full_path" ]; then
        upload_screenshot "$full_path"
        notify-send -a "Screenshot" -i "$full_path" "Screenshot Uploaded"
    else
        notify-send -a "Screenshot" "Screenshot failed"
    fi
    ;;
*) # invalid option
    print_error ;;
esac

# For other options, we'll keep the existing behavior
if [ "$1" != "u" ] && [ -f "$full_path" ]; then
    notify-send -a "Screenshot" -i "$full_path" "Saved in $save_dir"
fi
