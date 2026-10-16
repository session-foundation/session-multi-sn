# Builds the oxen-multi-sn package on pushes to master and uploads it to builds.session.codes.  The
# package is architecture-independent and the same for every distro, so it is built once, in the
# Debian sid builder; session-packaging's publish-debs.sh then publishes that one build into every
# distro's repository.

builder_image = "registry.session.codes/debian-sid-builder"

apt_get = "apt-get -o=Dpkg::Use-Pty=0 -q"

def main(ctx):
    return [{
        "name": "Debian package",
        "labels": {"platform": "linux/amd64", "backend": "docker"},
        "when": [{"event": ["push", "manual"], "branch": "master"}],
        "steps": [
            {
                "name": "build",
                "image": builder_image,
                "pull": True,
                "commands": [
                    'echo "Building on $${CI_MACHINE}"',
                    'echo "man-db man-db/auto-update boolean false" | debconf-set-selections',
                    apt_get + " update",
                    apt_get + " install --no-install-recommends -y devscripts equivs",
                    "cd debian",
                    'mk-build-deps -i -r --tool="' + apt_get + ' -o Debug::pkgProblemResolver=yes --no-install-recommends -y" control',
                    "cd ..",
                    "dpkg-buildpackage -us -uc -b",
                ],
            },
            {
                # Kept out of the build step so that the build never sees the key.
                "name": "upload",
                "image": builder_image,
                "environment": {"SSH_KEY": {"from_secret": "SSH_KEY"}},
                "commands": [
                    apt_get + " update",
                    apt_get + " install --no-install-recommends -y openssh-client",
                    "./debian/ci-upload.sh",
                ],
            },
        ],
    }]
