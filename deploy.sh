#!/bin/bash
#
# Copies built APK artifacts to Amazon S3 bucket.
#
echo 'Upoading index HTML.'
aws s3 cp etc/index.html s3://alpine-apks.markerbench.com \
  --profile AlpineApkRepo

echo 'Upoading APKs.'
aws s3 cp packages/ s3://alpine-apks.markerbench.com \
  --profile AlpineApkRepo \
  --recursive \
  --exclude "*" \
  --include index.html \
  --include x86_64/APKINDEX.tar.gz \
  --include x86_64/*.apk

echo 'Upoading public key.'
aws s3 cp etc/apk/keys/alpine-devel@markerbench.com-5d56c244.rsa.pub s3://alpine-apks.markerbench.com \
    --profile AlpineApkRepo
