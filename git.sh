#! /bin/bash
sh -c '''
if [ -d "/home/ec2-user/{GIT_FOLDER}" ]
then
rm -rf {GIT_FOLDER}
git clone {GIT_URL}
else
git clone {GIT_URL}
fi
'''