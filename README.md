# Alpine APKs

Project containing custom Alpine Linux packages (APKs).

To install, add my [public key](alpine-devel@markerbench.com-5d56c244.rsa.pub) to `/etc/apk/keys` on the Alpine box.

Add my repository to `/etc/apk/repositories`:

        @arj http://alpine-apks.markerbench.com

Add one or more packages:

        apk add efs-utils@arj

## efs-utils

This package is an Alpine build of Amazon's [`efs-utils`](https://github.com/aws/efs-utils) package, which allows Amazon Machine Images to mount Elastic File System volumes. EFS volumes are essentially NFS mounts. But because NFS traffic is not encrypted, `efs-utils` provides a special `mount.efs` helper and watchdog daemon that create and tear down SSL tunnels to EFS hosts. Both the mount helper and accompanying watchdog daemon are written in Python are are simple to configure.

The `efs-utils` package provided by Amazon supports Ubuntu, Centos and Debian, but not Alpine. So this package gently modifies the watchdog (`/usr/bin/amazon-efs-mount-watchdog`) and mount helper (`/sbin/mount.efs`). The patch applied to the watchdog enables it to run under Python 3. The patch applied to the mount helper does the same, but also adds the ability to detect Alpine-based systems.

To install the EFS agent, install using the usual Alpine method (`apk`), appending the `arj` repository tag:

        sudo apk add efs-utils@arj

Once installed, EFS volumes can be mounted by Alpine hosts this way:

        sudo mount -t efs -o tls file-system-id efs-mount-point/

...and mounted at bootup by including a line in `/etc/fstab`:

        file-system-id efs-mount-point efs _netdev,tls 0 0

...where _file-system-id_ is the EFS volume ID and _efs-mount-point_ is the mount point, _eg_ `/opt/foo`.

## awslogs-agent

This package is a re-packaged version of the AWS CloudWatch Logs Agent, which allows Alpine-based AMIs to ship logs to CloudWatch. The agent is [the "older" style agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/QuickStartEC2Instance.html), rather than the newer unified agent.

The agent does very little; its primary purpose is to start an AWS CLI `logs push` process that runs in the background. The Alpine version of this package is merely an extracted set of config files from the Amazon-supplied installer.

The Alpine package installer performs similarly to the Amazon-supplied installer. It adds an Alpine-compatible `openrc` init script and accompanying environmental config to `/etc/init.d` and `/etc/conf.d`, respectively. It also adds a log rotation config to `/etc/logrotate.d` and a `cron` entry to rotate logs every 30 minutes. Last, it installs a version info script (`/var/awslogs/bin/awslogs-version.sh`).

_Unlike_ the Amazon-supplied installer, the Alpine package installer attempts to install the latest version of Python package `awscli-cwlogs`. It also adds sample AWS and AWS CloudWatch Log Agent configuration files to `/var/awslogs/etc`; these are `aws.conf.example` and `awslogs.conf.example`. If the (non example) `aws.conf` or `awslogs.conf` files do not exist, the package installer prints a warning.

The AWS configuration file `aws.conf` should contain valid values for `region`, `aws_access_key_id` and `aws_secret_access_key`. Ideally, these credentials should belong to an IAM user that possesses only the minimum privileges needed to create log groups and push logs, for example:

        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents",
                        "logs:DescribeLogStreams"
                    ],
                    "Resource": [
                        "arn:aws:logs:*:*:*"
                    ]
                }
            ]
        }

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

Because this package repository is an untrusted (private) repository, `abuild` must be made to trust it. To do this, we bind-mount the `etc/apk/keys` project subdirectory into the Docker container as `/etc/apk/keys`. This directory includes the current public keys used for the various Alpine public repos, _plus_ the public key for this private repo. This allows the APKs to build successfully without error.

The entire project directory is bind-mounted into the Docker container as `/package` so that `abuild` can modify files in it. Unfortunately, in the process of doing its work, `abuild` copies the APK signing key into its `config` directory. To prevent disclosure of the key, we add the entire `config` directory to `.gitignore`.

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
