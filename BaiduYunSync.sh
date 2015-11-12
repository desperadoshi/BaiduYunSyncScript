#!/bin/bash
export PYTHONWARNINGS="ignore:Unverified HTTPS request"
YunSyncExec='bypy.py'
# Change working directory to YunSync root directory
WorkingDir='/home/shijingchang/YunWorking'
cd ${WorkingDir}
echo $(pwd)
${YunSyncExec} syncup ${WorkingDir} '/'
echo 'Sync Up Operation is Done.'
rm /tmp/BaiduYunSync*
CurrentTime=$(date +"%F-%H-%M-%S")
CompareLogFile='/tmp/BaiduYunSync_'${CurrentTime}'.log'
${YunSyncExec} compare / ${WorkingDir} > ${CompareLogFile}
declare -i RemoteOnlyFilesStartLine=$(sed -n '/==== Remote only ====/=' ${CompareLogFile})
declare -i RemoteOnlyFilesEndLine=$(sed -n '/--------------------------------/=' ${CompareLogFile})
# RemoteOnlyFilesNMAX should be 3, if there is no Remote only file.
declare -i RemoteOnlyFilesNMAX=$(expr ${RemoteOnlyFilesEndLine} - ${RemoteOnlyFilesStartLine} - 3)
if [ "${RemoteOnlyFilesNMAX}" -eq "0" ]; then
    echo 'There is no Remote only files.'
else
    echo 'There are '${RemoteOnlyFilesNMAX}' Remote only files.'
    # 1st round of operation. Loop to get Remote only files name.
    RemoteOnlyFileTypeDIndex=0
    RemoteOnlyFileTypeFIndex=0
    for (( RemoteOnlyFileIndex=1; RemoteOnlyFileIndex<=${RemoteOnlyFilesNMAX}; RemoteOnlyFileIndex++ ))
        do
            declare -i RemoteOnlyFileCurrentLine=$(expr ${RemoteOnlyFilesStartLine} + ${RemoteOnlyFileIndex})
            RemoteOnlyFileCurrentLineContents=$(sed -n ${RemoteOnlyFileCurrentLine}'p' ${CompareLogFile})
            # Get the type of Remote only file, i.e. Directory or File.
            RemoteOnlyFileType[${RemoteOnlyFileIndex}]=${RemoteOnlyFileCurrentLineContents:0:1}
            RemoteOnlyFilePath[${RemoteOnlyFileIndex}]=${RemoteOnlyFileCurrentLineContents:4}
            if [ "${RemoteOnlyFileType[${RemoteOnlyFileIndex}]}" == "D" ]; then
                RemoteOnlyFileTypeDIndex=$(expr ${RemoteOnlyFileTypeDIndex} + 1)
                RemoteOnlyFileTypeDPath[${RemoteOnlyFileTypeDIndex}]=${RemoteOnlyFilePath[${RemoteOnlyFileIndex}]}
            else
                RemoteOnlyFileTypeFIndex=$(expr ${RemoteOnlyFileTypeFIndex} + 1)
                RemoteOnlyFileTypeFPath[${RemoteOnlyFileTypeFIndex}]=${RemoteOnlyFilePath[${RemoteOnlyFileIndex}]}
            fi
        done
    # 2nd round of operation. Loop files of type Directory and remove them.
    RemoteOnlyFileTypeDNMAX=${RemoteOnlyFileTypeDIndex}
    if [ "${RemoteOnlyFileTypeDNMAX}" != "0" ]; then
        for (( RemoteOnlyFileTypeDIndex=1; RemoteOnlyFileTypeDIndex<=${RemoteOnlyFileTypeDNMAX}; RemoteOnlyFileTypeDIndex++ ))
            do
                echo ${RemoteOnlyFileTypeDPath[${RemoteOnlyFileTypeDIndex}]}
                ${YunSyncExec} remove ${RemoteOnlyFileTypeDPath[${RemoteOnlyFileTypeDIndex}]}
            done
    fi
    # 3rd round of operation. Loop files of type File and remove them.
    # Additional inner loop to avoid remove files in the directories removed in the last round of operation.
    RemoteOnlyFileTypeFNMAX=${RemoteOnlyFileTypeFIndex}
    if [ "${RemoteOnlyFileTypeFNMAX}" != "0" ]; then
        for (( RemoteOnlyFileTypeFIndex=1; RemoteOnlyFileTypeFIndex<=${RemoteOnlyFileTypeFNMAX}; RemoteOnlyFileTypeFIndex++ ))
            do
                for (( RemoteOnlyFileTypeDIndex=1; RemoteOnlyFileTypeDIndex<=${RemoteOnlyFileTypeDNMAX}; RemoteOnlyFileTypeDIndex++ ))
                    do
                        CurrentDirLength=${#RemoteOnlyFileTypeDPath[${RemoteOnlyFileTypeDIndex}]}
                        CurrentFileDirPart=${RemoteOnlyFileTypeFPath[${RemoteOnlyFileTypeFIndex}]:0:${CurrentDirLength}}
                        if [ "${CurrentFileDirPart}" != "${RemoteOnlyFileTypeDPath[${RemoteOnlyFileTypeDIndex}]}" ]; then
                            echo ${RemoteOnlyFileTypeFPath[${RemoteOnlyFileTypeFIndex}]}
                            ${YunSyncExec} remove ${RemoteOnlyFileTypeFPath[${RemoteOnlyFileTypeFIndex}]}
                        fi
                    done
            done
    fi
    ${YunSyncExec} compare / ${WorkingDir} > ${CompareLogFile}'.new'
    echo 'Remove Remote Only Files Operation is done. Check '${CompareLogFile}'.new'
fi

