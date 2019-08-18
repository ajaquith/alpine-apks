# Alpine APKs

Project containing custom Alpine Linux packages (APKs).

To install, add my [public key](alpine-devel@markerbench.com-5d56c244.rsa.pub) to `/etc/apk/keys` on the Alpine box.

Add my repository to `/etc/apk/repositories`:

        @arj http://alpine-apks.markerbench.com

Add one or more packages:

        apk add efs-utils@arj

## efs-utils

This package is an Alpine build of Amazon's [`efs-utils`](https://github.com/aws/efs-utils)` package, which allows Amazon Machine Images to mount Elastic File System volumes. EFS volumes are essentially NFS mounts. But because NFS traffic is not encrypted, `efs-utils` provides a special `mount.efs` helper and watchdog daemon that create and tear down SSL tunnels to EFS hosts. Both the mount helper and accompanying watchdog daemon are written in Python are are simple to configure.

The `efs-utils` package provided by Amazon supports Ubuntu, Centos and Debian, but not Alpine. So this package gently modifies the watchdog (`/usr/bin/amazon-efs-mount-watchdog`) and mount helper (`/sbin/mount.efs`). The patch applied to the watchdog enables it to run under Python 3. The patch applied to the mount helper does the same, but also adds the ability to detect Alpine-based systems.

Once installed, EFS volumes can be mounted by Alpine hosts this way:

        sudo mount -t efs -o tls file-system-id efs-mount-point/

...and mounted at bootup by including a line in `/etc/fstab`:

        file-system-id efs-mount-point efs _netdev,tls 0 0

...where _`file-system-id`_ is the EFS volume ID and _efs-mount-point_ is the mount point, eg `/opt/foo`.

# Building packages

I built all of the packages in this repository using the standard Alpine `abuild` package, using a Docker container to stand up and run the build environment. The Docker image [`craftdock/apk-builder`](https://hub.docker.com/r/craftdock/apk-builder) builds the packages. Each subdirectory contains an APK package to be built, with its own `APKBUILD` file.

## Workflow

Packages are built by changing to the project root and running the `abuild.sh` shell script, passing the name of the package and abuild command as parameters. Without the command parameter, `-r` is assumed.

Typical workflow:

        cd alpine-apks
        ./abuild.sh efs-utils checksum
        ./abuild.sh efs-utils

To see what is being built, incrementally:

        ./abuild.sh efs-utils cleanpkg
        ./abuild.sh efs-utils unpack
        ./abuild.sh efs-utils prepare
        ./abuild.sh efs-utils package

To rebuild from scratch:

        ./abuild.sh efs-utils cleanpkg
        ./abuild.sh efs-utils

To push the APK packages to the public webhost (on Amazon S3):

        ./deploy.sh

Because this package repository is an untrusted (private) repository, as the Docker container bind-mounts the `etc/apk/keys` project subdirectory into the container as `/etc/apk/keys`. This mount includes the current public keys used for the various Alpine public repos, plus the public key for this private repo. This allows the APKs to build normally without error.

The container has the unfortunate habit of copying my APK signing keys into its `config` directory, which is bind-mounted into the project directory at build time. However, we add the `conf` directory to `.gitignore` so that it doesn't show up in the Git tree.

## Prerequisites

### Docker

Because the `abuild` Alpine package builder runs in a Docker container, Docker is required. (I use Docker for Mac.)

### Amazon S3

The Alpine repository is hosted in an Amazon Web Services S3 bucket called [`alpine-apks.markerbench.com`](http://alpine-apks.markerbench.com) with an URL of the same name. This bucket is configured as a static website with all "block public access" flags turned off to make it accessible to all. It has the following bucket policy applied to it as [described on Stack Overflow](https://stackoverflow.com/questions/7420209/amazon-s3-permission-problem-how-to-set-permissions-for-all-files-at-once):

        {
            "Version": "2008-10-17",
            "Id": "http better policy",
            "Statement": [
                {
                    "Sid": "readonly policy",
                    "Effect": "Allow",
                    "Principal": "*",
                    "Action": "s3:GetObject",
                    "Resource": "arn:aws:s3:::alpine-apks.markerbench.com/*"
                }
            ]
        }

The root of the bucket contains a stub `index.html`. It has a subfolder called `x86_64` that contains the Alpine package index `APKINDEX.tar.gz`, as well as the `.apk` files created by the project. The bucket does not log access or version its contents because it is just a dumb bucket of bits and it is versioned in Git.

The bucket's full URL is `http://alpine-apks.markerbench.com.s3-website-us-east-1.amazonaws.com`. To make accessing it easier, the `markerbench.com` domain has a `CNAME` record containing the value of the full URL.
