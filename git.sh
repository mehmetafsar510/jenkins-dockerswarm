#! /bin/bash
sh -c '''
if [ -f "{GIT_FOLDER}" ]
then
rm -rf {GIT_FOLDER}
git clone {GIT_FOLDER}
else
git clone {GIT_FOLDER}
fi
'''