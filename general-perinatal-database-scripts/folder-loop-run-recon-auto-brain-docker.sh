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

 
server_id=gpubeastie04
recon_user_id=au18
 

main_folder=/FetalPreprocessing/pride-auto-recon-files

results_folder=/FetalPreprocessing/pride-auto-recon-files/results

proc_folder=/FetalPreprocessing/pride-auto-recon-files/tmp-proc-files

script_path_pride=/FetalPreprocessing/pride-auto-recon-files/scripts

software_path=/FetalPreprocessing/pride-auto-recon-files/software


cd ${main_folder}
 

all_main_folders=("/FetalPreprocessing/pride-auto-recon-files" )
all_results_folders=("/FetalPreprocessing/pride-auto-recon-files/results" )



all_rois=( "brain_05t" "brain_15t" "brain_3t" )
all_recon_types=( "SVR" "SVR" "SVR" )



while :
do

	echo 
	echo " ... (auto recon brain 0.55T & 1.5T & 3T) " 
	echo 


	for ((q=0;q<${#all_main_folders[@]};q++));
	do

		main_folder=${all_main_folders[$q]}
		results_folder=${all_results_folders[$q]}
		
		for ((j=0;j<${#all_rois[@]};j++));
		do

			main_folder_check=${main_folder}/${all_rois[$j]}/
			folder_names=$(find ${main_folder_check} -maxdepth 1 -type d)
			# folder_names=$(find ${main_folder_check} -maxdepth 1 -type d -name "2022*")
			IFS=$'\n' read -rd '' -a all_folders <<<"$folder_names"

			for ((i=1;i<${#all_folders[@]};i++));
			do
		    
		    		cd ${main_folder_check}

		    		current_folder=${all_folders[$i]}

				case_name=${all_folders[$i]}
				case_name=${case_name##*/}


		    		cd ${current_folder}

				test_file=${results_folder}-${all_rois[$j]}/${case_name}-${all_recon_types[$j]}-output.nii.gz
		    		if [[ ! -f ${test_file} ]];then

					test_file=do-not-process.txt
			    		if [[ ! -f ${test_file} ]];then


						num_nii=$(find ${current_folder}/ -name "*.nii*" | wc -l)


						num_dcm=$(find ${current_folder}/ -name "*.dcm" | wc -l)

						if [ $num_dcm -gt 0 ]; then

								echo " - found .dcm in " ${all_folders[$i]} " - converting ... "
								echo 

								test_folder=${proc_folder}/${case_name}-org-files
								if [[ ! -d ${test_folder} ]];then

									mkdir ${proc_folder}/${case_name}-org-files

								else 

									rm ${proc_folder}/${case_name}-org-files/*

								fi 

									find ${current_folder}/ -name "*.dcm" -exec cp {} ${proc_folder}/${case_name}-org-files \; 
									
									${software_path}/dcm2niix -o ${proc_folder}/${case_name}-org-files  -z y -f '%b' ${proc_folder}/${case_name}-org-files

									rm ${proc_folder}/${case_name}-org-files/*.json 
									rm ${proc_folder}/${case_name}-org-files/*.dcm

									num_nii=$(find ${proc_folder}/${case_name}-org-files/ -name "*.nii*" | wc -l)

						fi 


						if [ $num_nii -gt 0 ]; then


							echo
							echo " - processing ("  ${all_rois[$j]}  ") : " ${all_folders[$i]} " ... " 
							echo 

							sleep 30 


							test_folder=${proc_folder}/${case_name}-org-files
							if [[ ! -d ${test_folder} ]];then

								mkdir ${proc_folder}/${case_name}-org-files

								find ${current_folder}/ -name "*.nii*" -exec cp {} ${proc_folder}/${case_name}-org-files \; 

							fi 

							rm -r ${proc_folder}/latest_case_recon_${all_rois[$j]}/
							mkdir ${proc_folder}/latest_case_recon_${all_rois[$j]}/

							cp -r ${proc_folder}/${case_name}-org-files ${proc_folder}/latest_case_recon_${all_rois[$j]}/org-files

							full_current_path=$(pwd)

							cd ${proc_folder}/latest_case_recon_${all_rois[$j]}/

							bash ${script_path_pride}/recon-${all_rois[$j]}.sh ${proc_folder}/latest_case_recon_${all_rois[$j]} ${results_folder}-${all_rois[$j]}/${case_name}-${all_recon_types[j]}-output.nii.gz

							cd ${default_main_folder}

							chmod 1777 ${results_folder}-${all_rois[$j]}/${case_name}-${all_recon_types[j]}-output.nii.gz

							test_file=${results_folder}-${all_rois[$j]}/${case_name}-${all_recon_types[j]}-output.nii.gz

                            rm -r ${proc_folder}/${case_name}-org-files
						
						fi


					fi 

				fi 

			done 

		done 

	done

	sleep 45 

done



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo








