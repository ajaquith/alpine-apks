# Alpine APKs

Project containing custom Alpine Linux packages (APKs).

To install, add my [public key](alpine-devel@markerbench.com-5d56c244.rsa.pub) to `/etc/apk/keys` on the Alpine box.

Add my repository to `/etc/apk/repositories`:

        @arj http://alpine-apks.markerbench.com

Add one or more packages:

        apk add aws-docker@arj
        
## aws-docker

This meta-package configures an Alpine AMI with the packages necessary to run Docker, the [AWS Elastic Container Service](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_agent.html) agent, AWS CloudWatch Logs Agent, and AWS Elastic File System support. It:

- Installs the `efs-utils` package (see below)
- Installs the `awslogs-agent` package (see below)
- Installs a Docker daemon configuration file (`/etc/docker/daemon.json`) that sends Docker logs to AWS Cloudwatch
- Installs a blank ECS configuration file at `/etc/ecs/ecs.config`, which can be edited if the defaults are not sufficient
- Adds two `iptables` rules and a sysconfig setting that routes local traffic to the ECS Agent

The `aws-docker` package does _not_ actually download and run the ECS Agent container. This should be done after the AMI is provisioned, as described on the [ECS Agent GitHub page](https://github.com/aws/amazon-ecs-agent):

        docker run --name ecs-agent \
            --detach=true \
            --restart=on-failure:10 \
            --volume=/var/run/docker.sock:/var/run/docker.sock \
            --volume=/var/log/ecs:/log \
            --volume=/var/lib/ecs/data:/data \
            --net=host \
            --env-file=/etc/ecs/ecs.config \
            --env=ECS_LOGFILE=/log/ecs-agent.log \
            --env=ECS_DATADIR=/data/ \
            --env=ECS_ENABLE_TASK_IAM_ROLE=true \
            --env=ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true \
            amazon/amazon-ecs-agent:latest

The AMI instance that `aws-docker` is installed on must have an EC2 instance role associated with it. This role must have the `AmazonEC2ContainerServiceforEC2Role` policy attached to it, as well as entitlements that allow it to push logs to CloudWatch (see the discussion in the `awslogs-agent` package description below).

When the `aws-docker` package is removed, the ECS agent container (`amazon/amazon-ecs-agent:latest`) is stopped and removed.

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

To install the AWS Logs Agent, install using the usual Alpine method (`apk`), appending the `arj` repository tag:

        sudo apk add awslogs-agent@arj

_Unlike_ the Amazon-supplied installer, the Alpine package installer attempts to install the latest version of Python package `awscli-cwlogs`. It also adds default AWS and AWS CloudWatch Log Agent configuration files to `/var/awslogs/etc`; these are `aws.conf` and `awslogs.conf`.

The AWS configuration file `aws.conf` should contain a valid value for `region`, in the `[default]` section. If the EC2 instance has an IAM role that contains appropriate entitlements (see below), no other configuration is needed. If an IAM role is _not_ attached to the EC2 instance, the  `aws_access_key_id` and `aws_secret_access_key` need to be supplied.

In order to push logs, either the IAM role (preferred) or user (less preferred) needs to possess privileges to create log groups and push logs. Here is a sample policy that grants these privileges:

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
                        "arn:aws:logs:\*:\*:\*"
                    ]
                }
            ]
        }

As mentioned &mdash; and at the risk of repeating myself &mdash; this policy should be attached to an IAM role, and that role should be attached to the EC2 instance at launch.

The `awslogs.conf` file tells the CloudWatch Logs Agent what to push. With the stock Alpine configuration, this is straightforward because the only `syslog` package included is the BusyBox `syslog`, which logs to a single file, `/var/log/messages`. As a result, the out-of-the-box `awslogs.conf` supplied in this package only pushes `/var/log/messages`. _Note:_ if the Alpine services `klogd` and `crond` are enabled, kernel- and cron-related log lines will be included in `/var/log/messages` and pushed to CloudWatch as well. If you use another `syslog` package, such as `rsyslogd`, add entries to `awslogs.conf` to push additional files as needed.

## alpine-keys-arj

This package provides the standard set of Alpine public repository signing keys, plus my own [public signing key](alpine-devel@markerbench.com-5d56c244.rsa.pub). This package is used by my forked [`alpine-ec2-ami`](https://github.com/ajaquith/alpine-ec2-ami) scripts as a substitute for the standard Alpine public repo signing keys package, `alpine-keys-2.x.apk`. It is otherwise identical except that my public key has been added. At build-time, the `alpine-ec2-ami` builder injects these keys into the AMI build so that this repository can be trusted. It is meant to be used primarily by `alpine-ec2-ami`, and not as a standard package; that is, you would not typically add it via the normal `apk` package installer (_eg_, `apk add alpine-keys-arj`).

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
                    "Principal": "\*",
                    "Action": "s3:GetObject",
                    "Resource": "arn:aws:s3:::alpine-apks.markerbench.com/\*"
                }
            ]
        }

The root of the bucket contains a stub `index.html`. It has a subfolder called `x86_64` that contains the Alpine package index `APKINDEX.tar.gz`, as well as the `.apk` files created by the project. The bucket does not log access or version its contents because it is just a dumb bucket of bits and it is versioned in Git.

The bucket's full URL is `http://alpine-apks.markerbench.com.s3-website-us-east-1.amazonaws.com`. To make accessing it easier, the `markerbench.com` domain has a `CNAME` record containing the value of the full URL.
