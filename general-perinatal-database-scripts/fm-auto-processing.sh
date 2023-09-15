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


server_seg_id=gpubeastie06
server_id=pridesvr02-pc
run_user_id=au18


in_folder=/home/au18/F-Data/pip
proc_folder=/FetalPreprocessing/pride-auto-recon-files
run_folder=/home/au18/Software/pride-files/proc-files
proc_folder_seg=/scratch/auto-segmentation-files


while :
do

	echo 
	echo " ... (fm analysis) " 
	echo 
		main_folder=${in_folder}
		results_folder=${in_folder}

			main_folder_check=${main_folder}
			folder_names=$(find ${main_folder_check} -maxdepth 1 -type d -name "fm0*" )
			IFS=$'\n' read -rd '' -a all_folders <<<"$folder_names"


			for ((i=0;i<${#all_folders[@]};i++));
			do

					cd ${main_folder_check}

					current_folder=${all_folders[$i]}

					case_name=${all_folders[$i]}

					case_name=${case_name##*/}


					cd ${current_folder}

					roi_id=2
					roi_name=brain
					seg_name=brain_tissue
					folder_seg=brain_bounti 
					folder_rec=brain

					seg_name=brain_tissue
					folder_seg=brain_bounti
					file_seg_name=brain_dhcp-19


					test_file=${case_name}_t2_recon_${roi_id}.nii.gz 
					if [[ ! -f ${test_file} ]];then


						echo $" - " ${case_name} - no ${roi_name} recon ...

						sleep 60

						num_nii=$(find ./*haste* -name "*.nii*" | wc -l)

						if [ $num_nii -gt 4 ]; then

							test_file=${run_folder}/${case_name}_${roi_id}
							if [[ -d ${test_file} ]];then
								rm -r ${run_folder}/${case_name}_${roi_id}
							else 
								mkdir ${run_folder}/${case_name}_${roi_id}
							fi 

							find ./*haste*ute* -name "s*.nii*" -exec cp {} ${run_folder}/${case_name}_${roi_id}/ \;
							find ./*haste*brain* -name "s*.nii*" -exec cp {} ${run_folder}/${case_name}_${roi_id}/ \;
							find ./*haste*body* -name "s*.nii*" -exec cp {} ${run_folder}/${case_name}_${roi_id}/ \;

							# find ./*haste*ute* -name "*fm*.nii*" -exec cp {} ${run_folder}/${case_name}_${roi_id}/ \;

							echo
							echo " - processing "  ${roi_name} ${roi_id} " : " ${case_name} " ... " 
							echo 


							scp -r ${run_folder}/${case_name}_${roi_id} ${run_user_id}@${server_id}:${proc_folder}/${folder_rec}/

							rm -r ${run_folder}/${case_name}_${roi_id}


							isReconstructed=false
							while ! $isReconstructed; do

								test_file=${proc_folder}/results-${folder_rec}/${case_name}_${roi_id}-SVR-output.nii.gz

								ssh  ${run_user_id}@${server_id} "if [[ -f $test_file ]]; then scp $test_file au18@perinatal174-pc:${in_folder}/${case_name}/${case_name}_t2_recon_${roi_id}.nii.gz    ; else echo ... ; fi"; 

								test_file=${case_name}_t2_recon_${roi_id}.nii.gz 
								if [[ -f ${test_file} ]];then

									isReconstructed=true
									echo "  !!! found reconstructred file !!!! "

									ssh ${run_user_id}@${server_id} rm -r ${proc_folder}/${folder_rec}/${case_name}_${roi_id}

								else 
									echo " ... waiting for " results-${folder_rec}/${case_name}_${roi_id}-SVR-output.nii.gz
									sleep 60
								fi 

							done 


						fi

					else 

						test_file=${case_name}_t2_recon_${roi_id}_mask_${seg_name}.nii.gz 
						if [[ ! -f ${test_file} ]];then

							echo " - running segmentation for : " ${case_name}_t2_recon_${roi_id}

							test_file=${run_folder}/${case_name}_${roi_id}_recon
							if [[ -d ${test_file} ]];then
								rm -r ${run_folder}/${case_name}_${roi_id}_recon/*
							else 
								mkdir ${run_folder}/${case_name}_${roi_id}_recon
							fi 

							cp ${case_name}_t2_recon_${roi_id}.nii.gz ${run_folder}/${case_name}_${roi_id}_recon/

							scp -r ${run_folder}/${case_name}_${roi_id}_recon ${run_user_id}@${server_seg_id}:${proc_folder_seg}/${folder_seg}/

							rm -r ${run_folder}/${case_name}_${roi_id}_recon

							isSegmented=false
							while ! $isSegmented; do

								test_file=${proc_folder_seg}/results-${folder_seg}/${case_name}_${roi_id}_recon-segmentations/${case_name}_t2_recon_${roi_id}-mask-${file_seg_name}.nii.gz 

								echo 

								ssh  ${run_user_id}@${server_seg_id} "if [[ -f $test_file ]]; then scp $test_file au18@perinatal174-pc:${in_folder}/${case_name}/${case_name}_t2_recon_${roi_id}_mask_${seg_name}.nii.gz  ; else echo ... ; fi"; 

								test_file=${case_name}_t2_recon_${roi_id}_mask_${seg_name}.nii.gz 
								if [[ -f ${test_file} ]];then

									isSegmented=true
									echo "  !!! found segmentation file !!!! "

									ssh  ${run_user_id}@${server_seg_id} " rm -r ${proc_folder_seg}/${folder_seg}/${case_name}_${roi_id}_recon ; "

								else

									echo " ... waiting for " ${proc_folder_seg}/results-${folder_seg}/${case_name}_${roi_id}_recon-segmentations/${case_name}_t2_recon_${roi_id}-mask-${file_seg_name}.nii.gz
									sleep 60

								fi 

							done 


						fi 

					fi 


					roi_id=3
					roi_name=body_05t
					seg_name=body_organs
					folder_seg=body_organs
					file_seg_name=body_organs-10


					test_file=${case_name}_t2_recon_${roi_id}.nii.gz 
					if [[ ! -f ${test_file} ]];then

						echo $" - " ${case_name} - no ${roi_name} recon ...

						sleep 60 

						num_nii=$(find ./*haste* -name "*.nii*" | wc -l)

						if [ $num_nii -gt 4 ]; then

							test_file=${run_folder}/${case_name}_${roi_id}
							if [[ -d ${test_file} ]];then
								rm -r ${run_folder}/${case_name}_${roi_id}
							else 
								mkdir ${run_folder}/${case_name}_${roi_id}
							fi 


							find ./*haste*ute* -name "s*.nii*" -exec cp {} ${run_folder}/${case_name}_${roi_id}/ \;
                            find ./*haste*brain* -name "s*.nii*" -exec cp {} ${run_folder}/${case_name}_${roi_id}/ \;
                            find ./*haste*body* -name "s*.nii*" -exec cp {} ${run_folder}/${case_name}_${roi_id}/ \;

							# find ./*haste*ute* -name "*fm*.nii*" -exec cp {} ${run_folder}/${case_name}_${roi_id}/ \;

							echo
							echo " - processing "  ${roi_name} ${roi_id} " : " ${case_name} " ... " 
							echo 

							scp -r ${run_folder}/${case_name}_${roi_id} ${run_user_id}@${server_id}:${proc_folder}/${roi_name}/

							rm -r ${run_folder}/${case_name}_${roi_id}

							isReconstructed=false
							while ! $isReconstructed; do

								test_file=${proc_folder}/results-${roi_name}/${case_name}_${roi_id}-DSVR-output.nii.gz

								ssh  ${run_user_id}@${server_id} "if [[ -f $test_file ]]; then scp $test_file au18@perinatal174-pc:${in_folder}/${case_name}/${case_name}_t2_recon_${roi_id}.nii.gz    ; else echo ... ; fi"; 

								test_file=${case_name}_t2_recon_${roi_id}.nii.gz 
								if [[ -f ${test_file} ]];then
 
									isReconstructed=true
									echo "  !!! found reconstructred file !!!! "

									ssh ${run_user_id}@${server_id} rm -r ${proc_folder}/${roi_name}/${case_name}_${roi_id}

								else 
									echo " ... waiting for " results-${roi_name}/${case_name}_${roi_id}-DSVR-output.nii.gz
									sleep 60
								fi 

							done 


						fi


					else 

						test_file=${case_name}_t2_recon_${roi_id}_mask_${seg_name}.nii.gz 
						if [[ ! -f ${test_file} ]];then

							echo " - running segmentation for : " ${case_name}_t2_recon_${roi_id}

							test_file=${run_folder}/${case_name}_${roi_id}_recon
							if [[ -d ${test_file} ]];then
								rm -r ${run_folder}/${case_name}_${roi_id}_recon/*
							else 
								mkdir ${run_folder}/${case_name}_${roi_id}_recon
							fi 

							cp ${case_name}_t2_recon_${roi_id}.nii.gz ${run_folder}/${case_name}_${roi_id}_recon/

							scp -r ${run_folder}/${case_name}_${roi_id}_recon ${run_user_id}@${server_seg_id}:${proc_folder_seg}/${folder_seg}/

							rm -r ${run_folder}/${case_name}_${roi_id}_recon

							isSegmented=false
							while ! $isSegmented; do

								test_file=${proc_folder_seg}/results-${folder_seg}/${case_name}_${roi_id}_recon-segmentations/${case_name}_t2_recon_${roi_id}-mask-${file_seg_name}.nii.gz 
								ssh  ${run_user_id}@${server_seg_id} "if [[ -f $test_file ]]; then scp $test_file au18@perinatal174-pc:${in_folder}/${case_name}/${case_name}_t2_recon_${roi_id}_mask_${seg_name}.nii.gz  ; else echo ... ; fi"; 

								test_file=${case_name}_t2_recon_${roi_id}_mask_${seg_name}.nii.gz 
								if [[ -f ${test_file} ]];then

									isSegmented=true
									echo "  !!! found segmentation file !!!! "

									ssh ${run_user_id}@${server_id} rm -r ${proc_folder}/${roi_name}/${case_name}_${roi_id}

								else

									echo " ... waiting for " ${proc_folder_seg}/results-${folder_seg}/${case_name}_${roi_id}_recon-segmentations/${case_name}_t2_recon_${roi_id}-mask-${file_seg_name}.nii.gz
									sleep 60

								fi 

							done 


						fi 

					fi 



			done 


	sleep 45  

done



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo








