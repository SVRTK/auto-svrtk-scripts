#!/usr/bin/env bash -l

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

eval "$(conda shell.bash hook)"
#conda init bash
conda activate Segmentation_FetalMRI_MONAI

#UPDATE AS REQUIRED BEFORE RUNNING !!!!
software_path=/home
default_run_dir=/home/tmp_proc


mirtk_path=${software_path}/MIRTK/build/bin
segm_path=${software_path}/segmentation
template_path=${segm_path}/templates



test_dir=${software_path}/MIRTK
if [[ ! -d ${test_dir} ]];then
    echo "ERROR: COULD NOT FIND MIRTK INSTALLED IN : " ${software_path}
    echo "PLEASE INSTALL OR UPDATE THE PATH software_path VARIABLE IN THE SCRIPT"
    exit
fi

test_dir=${segm_path}/trained_models
if [[ ! -d ${test_dir} ]];then
    echo "ERROR: COULD NOT FIND SEGMENTATION MODULE INSTALLED IN : " ${software_path}
    echo "PLEASE INSTALL OR UPDATE THE PATH software_path VARIABLE IN THE SCRIPT"
    exit
fi


monai_check_path_stack_thorax=${segm_path}/trained_models/local_stack_thorax_unet
monai_check_path_dsvr_body_reo=${segm_path}/trained_models/local_dsvr_body_reo_rois_unet


test_dir=${default_run_dir}
if [[ ! -d ${test_dir} ]];then
    mkdir ${default_run_dir}
else
    rm -r ${default_run_dir}/*
fi

test_dir=${default_run_dir}
if [[ ! -d ${test_dir} ]];then
    echo "ERROR: COULD NOT CREATE THE PROCESSING FOLDER : " ${default_run_dir}
    echo "PLEASE CHECK THE PERMISSIONS OR UPDATE THE PATH default_run_dir VARIABLE IN THE SCRIPT"
    exit
fi



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "SVRTK for fetal MRI (KCL): auto reorientation of fetal DSVR thorax T2w recons"
echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo

if [[ $# -ne 2 ]] ; then
    echo "Usage: bash /home/segmentation/auto-thorax-reorientation.sh"
    echo "            [full path to the folder with T2w DSVR recons]"
    echo "            [full path to the folder for reoriented results]"
    exit
else
    input_main_folder=$1
    output_main_folder=$2
fi


echo " - input folder : " ${input_main_folder}
echo " - output folder : " ${input_main_folder}


test_dir=${input_main_folder}
if [[ ! -d ${test_dir} ]];then
    echo
	echo "ERROR: NO FOLDER WITH THE INPUT FILES FOUND !!!!" 
	exit
fi


test_dir=${output_main_folder}
if [[ ! -d ${test_dir} ]];then
	mkdir ${output_main_folder}
fi 



cd ${default_run_dir}
main_dir=$(pwd)

number_of_stacks=$(find ${input_main_folder}/ -name "*.nii*" | wc -l)
if [[ ${number_of_stacks} -eq 0 ]];then
    echo
    echo "-----------------------------------------------------------------------------"
	echo "ERROR: NO INPUT .nii / .nii.gz FILES FOUND !!!!"
    echo "-----------------------------------------------------------------------------"
    echo
	exit
fi 

mkdir ${default_run_dir}/org-files
find ${input_main_folder}/ -name "*.nii*" -exec cp {} ${default_run_dir}/org-files  \; 

echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "PREPROCESSING ..."
echo

cd ${default_run_dir}


mkdir org-files-preproc
cp org-files/* org-files-preproc

cd org-files-preproc

stack_names=$(ls *.nii*)
IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"

echo
echo "-----------------------------------------------------------------------------"
echo "REMOVING NAN & NEGATIVE/EXTREME VALUES & SPLITTING INTO DYNAMICS..."
echo "-----------------------------------------------------------------------------"
echo

for ((i=0;i<${#all_stacks[@]};i++));
do
    echo " - " ${i} " : " ${all_stacks[$i]}
    ${mirtk_path}/mirtk nan ${all_stacks[$i]} 100000
    ${mirtk_path}/mirtk extract-image-region ${all_stacks[$i]} ${all_stacks[$i]} -split t
    rm ${all_stacks[$i]}
done

stack_names=$(ls *.nii*)
IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"


echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "REORIENTATION OF DSVR THORAX RECONS..."
echo

cd ${main_dir}

echo
echo "-----------------------------------------------------------------------------"
echo "RUNNING LANDMARK UNET ..."
echo "-----------------------------------------------------------------------------"
echo

number_of_stacks=$(ls org-files-preproc/*.nii* | wc -l)
stack_names=$(ls org-files-preproc/*.nii*)

echo " ... "

res=128
monai_lab_num=4
number_of_stacks=$(find org-files-preproc/ -name "*.nii*" | wc -l)
${mirtk_path}/mirtk prepare-for-monai res-reo-files/ reo-files/ stack-info.json stack-info.csv ${res} ${number_of_stacks} org-files-preproc/*nii* > tmp.log

mkdir monai-segmentation-results-reo
python ${segm_path}/run_monai_unet_segmentation-2022.py ${main_dir}/ ${monai_check_path_dsvr_body_reo}/ stack-info.json ${main_dir}/monai-segmentation-results-reo ${res} ${monai_lab_num}


number_of_stacks=$(find monai-segmentation-results-reo/ -name "*.nii*" | wc -l)
if [[ ${number_of_stacks} -eq 0 ]];then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "ERROR: REO CNN LOCALISATION DID NOT WORK !!!!"
    echo "-----------------------------------------------------------------------------"
    echo
    exit
fi

echo
echo "-----------------------------------------------------------------------------"
echo "EXTRACTING LABELS AND REORIENTING..."
echo "-----------------------------------------------------------------------------"
echo

out_mask_names=$(ls monai-segmentation-results-reo/cnn-*.nii*)
IFS=$'\n' read -rd '' -a all_masks <<<"$out_mask_names"

org_stack_names=$(ls org-files-preproc/*.nii*)
IFS=$'\n' read -rd '' -a all_org_stacks <<<"$org_stack_names"


mkdir reo-results
mkdir out-dsvr-reo-masks
mkdir dofs-to-atlas


current_template_path=${template_path}/body-dsvr-reo-template
${mirtk_path}/mirtk init-dof init.dof
    
for ((i=0;i<${#all_org_stacks[@]};i++));
do
    echo " - " ${i} " : " ${all_org_stacks[$i]} ${all_masks[$i]}
    
    jj=$((${i}+1000))

    for ((q=1;q<5;q++));
    do
        ${mirtk_path}/mirtk extract-label ${all_masks[$i]} out-dsvr-reo-masks/mask-${jj}-${q}.nii.gz ${q} ${q}
#        ${mirtk_path}/mirtk dilate-image out-dsvr-reo-masks/mask-${jj}-${q}.nii.gz out-dsvr-reo-masks/mask-${jj}-${q}.nii.gz
        ${mirtk_path}/mirtk extract-connected-components out-dsvr-reo-masks/mask-${jj}-${q}.nii.gz out-dsvr-reo-masks/mask-${jj}-${q}.nii.gz
    done

    z1=1; z2=2; z3=3; z4=4; n_roi=4;
    
    ${mirtk_path}/mirtk register-landmarks ${current_template_path}/thorax-atlas.nii.gz ${all_org_stacks[$j]} init.dof dofs-to-atlas/dof-to-atl-${jj}.dof ${n_roi} ${n_roi}  ${current_template_path}/thorax-reo-atlas-label-${z1}.nii.gz ${current_template_path}/thorax-reo-atlas-label-${z2}.nii.gz ${current_template_path}/thorax-reo-atlas-label-${z3}.nii.gz ${current_template_path}/thorax-reo-atlas-label-${z4}.nii.gz out-dsvr-reo-masks/mask-${jj}-${z1}.nii.gz out-dsvr-reo-masks/mask-${jj}-${z2}.nii.gz out-dsvr-reo-masks/mask-${jj}-${z3}.nii.gz out-dsvr-reo-masks/mask-${jj}-${z4}.nii.gz > tmp.log
    
    ${mirtk_path}/mirtk info dofs-to-atlas/dof-to-atl-${jj}.dof
    
    echo " ... "

    ${mirtk_path}/mirtk transform-image ${all_org_stacks[$i]} ${all_org_stacks[$i]} -target ${current_template_path}/thorax-ref.nii.gz -dofin dofs-to-atlas/dof-to-atl-${jj}.dof -interp BSpline
    
    ${mirtk_path}/mirtk crop-image ${all_org_stacks[$i]} ${all_org_stacks[$i]} ${all_org_stacks[$i]}
    
    ${mirtk_path}/mirtk nan ${all_org_stacks[$i]}  100000
    
    
    ${mirtk_path}/mirtk transform-and-rename ${all_org_stacks[$i]} ${all_org_stacks[$i]}  "_reo" ${main_dir}/reo-results
        
        
done


number_of_final_files=$(ls ${main_dir}/reo-results/*.nii* | wc -l)
if [[ ${number_of_final_files} -ne 0 ]];then

    cp -r reo-results/*.nii* ${output_main_folder}/
    

    echo "-----------------------------------------------------------------------------"
    echo "Reorientation results are in the output folder : " ${output_main_folder}
    echo "-----------------------------------------------------------------------------"
        
else
    echo
    echo "-----------------------------------------------------------------------------"
    echo "ERROR: COULD NOT COPY THE FILES TO THE OUTPUT FOLDER : " ${output_main_folder}
    echo "PLEASE CHECK THE WRITE PERMISSIONS / LOCATION !!!"
    echo
    echo "note: you can still find the reoriented files in : " ${main_dir}/reo-results
    echo "-----------------------------------------------------------------------------"
    echo

fi


echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo



    





