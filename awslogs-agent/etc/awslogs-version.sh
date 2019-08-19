#!/bin/sh
FILES=/var/awslogs/state/generated-files
for file in `cat ${FILES}`; do
    if [ -e $file ]; then
        echo "${file} version:"
        cat ${file} | grep "# Version: "
    else
        echo "$file not found on system"
    fi
done

echo "CloudWatch Logs Plugin Version:"
/usr/bin/pip3 show awscli-cwlogs

echo "AWS CLI Version:"
/usr/bin/pip3 show awscli
