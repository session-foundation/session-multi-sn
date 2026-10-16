#!/usr/bin/env bash

# Script used with Woodpecker CI to upload the built package to builds.session.codes.  It goes into
# the project's debian-sid directory whatever branch built it: the package is the same for every
# distro, and session-packaging's publish-debs.sh publishes the debian-sid build of such packages
# into every distro's repository.

set -o errexit

if [ -z "$SSH_KEY" ]; then
    echo -e "\n\n\n\e[31;1mUnable to upload artifact: SSH_KEY not set\e[0m"
    exit 1
fi

# dpkg-buildpackage writes its output next to the source directory.
cd ..

echo "$SSH_KEY" >ssh_key

set -o xtrace  # Don't start tracing until *after* we write the ssh key
shopt -s nullglob

chmod 600 ssh_key

base="deb-sid-$(date --date=@$CI_PIPELINE_CREATED +%Y%m%dT%H%M%SZ)-${CI_COMMIT_SHA:0:9}"
upload_to="builds.session.codes/${CI_REPO// /_}/debian-sid/$base"

debs=(*_all.deb)
if [ ${#debs[@]} = 0 ]; then
    echo "No package found to upload!" >&2
    exit 1
fi

put=
for f in "${debs[@]}" *.buildinfo; do
    put+=$'\n'"put $f $upload_to"
done
for deb in "${debs[@]}"; do
    echo -e "\n\n\e[35;1m$deb info:\e[0m"
    dpkg-deb --info "$deb"
    echo -e "\n\n\e[35;1m$deb contents:\e[0m"
    dpkg-deb --contents "$deb"
done

# sftp doesn't have any equivalent to mkdir -p, so we have to split the above up into a chain of
# -mkdir a/, -mkdir a/b/, -mkdir a/b/c/, ... commands.  The leading `-` allows the command to fail
# without error.
upload_dirs=(${upload_to//\// })
mkdirs=
dir_tmp=""
for p in "${upload_dirs[@]}"; do
    dir_tmp="$dir_tmp$p/"
    mkdirs="$mkdirs
-mkdir $dir_tmp"
done

sftp -i ssh_key -b - -o StrictHostKeyChecking=off drone@builds.session.codes <<SFTP
$mkdirs
$put
SFTP

set +o xtrace

echo -e "\n\n\n\n\e[32;1mUploaded to https://${upload_to}\e[0m\n\n\n"
