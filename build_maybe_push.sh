#!/bin/bash -e

tag="$(date -I)"
image_repo="quay.io/domino/idsm-test-audit-log-spammer"

[ -n "$image_repo" ] || { echo "Please set the image_repo var at the top of '$0'"; exit 1; }

push=0
no_interactive=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            sed -n '/^while/,/^done/p' "$0" | grep -oP '\S+(?=\)$)'
            exit 0
            ;;
        --no-interactive)
            no_interactive=1
            shift
            ;;
        --push)
            push=1
            shift
            ;;
        --tag)
            tag="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done


_push () {
    docker push "$image_repo:$tag"
    echo "Pushed '$image_repo:$tag'.  Done." >&2
}


echo "Building..." >&2
docker build --tag "$image_repo:$tag" .
docker tag "$image_repo:$tag" "$image_repo:latest"

if [ "$push" -eq 1 ]; then
    _push

elif [ "$no_interactive" -eq 0 ]; then
    read -p "Would you like to push '$image_repo'? (y/N) " confirm_push
    (grep -iP "y|Y|yes|Yes|YES" <<< "$confirm_push" &>/dev/null) && _push || echo "Not pushing image.  Done." >&2

else
    echo "Did not specify --push.  Not prompting because --no-interactive was provided." >&2
fi
