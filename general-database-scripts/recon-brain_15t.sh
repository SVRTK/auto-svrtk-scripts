#!/bin/bash

#
# SVRTK : SVR reconstruction based on MIRTK
#
# Copyright 2018- King's College London
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo



input_main_folder=$1
output_main_file=$2

current_roi=recon_brain_15t

cd ${input_main_folder}


mkdir results 


docker run --rm  --mount type=bind,source=${input_main_folder},target=/home/data  fetalsvrtk/svrtk:auto-2.20 sh -c ' bash /home/auto-proc-svrtk/auto-brain-055t-reconstruction.sh /home/data/org-files /home/data/results 1 3 0.8 1 ; chmod 1777 -R /home/data/results ; '



test_file=results/reo-SVR-output-brain.nii.gz 
if [ ! -f ${test_file} ];then

    echo
    echo "-----------------------------------------------------------------------------"
    echo "ERROR: no recon files - copying zero ..."
    echo "-----------------------------------------------------------------------------"

    cp /home/au18/zero.nii.gz ${output_main_file}

else

    echo
    echo "-----------------------------------------------------------------------------"
    echo "RECON WORKED !!! "
    echo "-----------------------------------------------------------------------------"

    cp results/reo-SVR-output-brain.nii.gz ${output_main_file}

fi


