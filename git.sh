#! /bin/bash
sh -c '''
if [ -f "/home/ec2-user/{GIT_FOLDER}" ]
then
rm -rf /home/ec2-user/{GIT_FOLDER}
git clone {GIT_URL}
else
git clone {GIT_URL}
fi
'''