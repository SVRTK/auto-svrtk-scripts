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

echo "Setting environment ... "
echo

eval "$(conda shell.bash hook)"

conda init bash

conda activate Segmentation_FetalMRI_MONAI



#NOTE: UPDATE AS REQUIRED BEFORE RUNNING !!!!
#NOTE - BEFORE USING: UPLOAD https://gin.g-node.org/SVRTK/fetal_mri_network_weights
#
#echo "NOTE: UPDATE SOFTWARE PAHTS AS REQUIRED BEFORE RUNNING !!!!"
#echo "NOTE: DOWNLOAD MONAI WEIGHTS INTO auto-proc-svrtk/trained_models FOLDER FROM https://gin.g-node.org/SVRTK/fetal_mri_network_weights"
#
#exit


software_path=/home

default_run_dir=/home/data/tmp_proc

segm_path=${software_path}/auto-proc-svrtk

dcm2niix_path=${software_path}/dcm2niix/build/bin

mirtk_path=${software_path}/MIRTK/build/bin

template_path=${segm_path}/templates

model_path=${segm_path}/trained_models




test_dir=${software_path}/MIRTK
if [ ! -d $test_dir ];then
    echo "ERROR: COULD NOT FIND MIRTK INSTALLED IN : " ${software_path}
    echo "PLEASE INSTALL OR UPDATE THE PATH software_path VARIABLE IN THE SCRIPT"
    exit
fi

test_dir=${segm_path}/trained_models
if [ ! -d $test_dir ];then
    echo "ERROR: COULD NOT FIND SEGMENTATION MODULE INSTALLED IN : " ${software_path}
    echo "PLEASE INSTALL OR UPDATE THE PATH software_path VARIABLE IN THE SCRIPT"
    exit
fi




test_dir=${default_run_dir}
if [ ! -d $test_dir ];then
    mkdir ${default_run_dir}
else
    rm -r ${default_run_dir}/*
fi

test_dir=${default_run_dir}
if [ ! -d $test_dir ];then
    echo "ERROR: COULD NOT CREATE THE PROCESSING FOLDER : " ${default_run_dir}
    echo "PLEASE CHECK THE PERMISSIONS OR UPDATE THE PATH default_run_dir VARIABLE IN THE SCRIPT"
    exit
fi



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "SVRTK for fetal MRI (KCL): auto thorax DSVR reconstruction for TSE T2w fetal MRI"
echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo

if [ $# -ne 2 ] ; then

    if [ $# -ne 6 ] ; then
        echo "Usage: bash /home/auto-proc-svrtk/auto-thorax-reconstruction.sh"
        echo "            [FULL path to the folder with raw T2w stacks in .nii or .dcm, e.g., /home/data/test]"
        echo "            [FULL path to the folder for recon results, e.g., /home/data/out-test]"
        echo "            (optional) [motion correction mode (0 or 1): 0 - minor, 1 - >180 degree rotations] - default: 1"
        echo "            (optional) [slice thickness] - default: 2.5"
        echo "            (optional) [output recon resolution] - default: 0.7"
        echo "            (optional) [number of packages] - default: 4 for 1.25 spacing, 1 for the rest"
        echo
        exit
    else
        input_main_folder=$1
        output_main_folder=$2
        motion_correction_mode=$3
        default_thickness=$4
        recon_resolution=$5
        num_packages=$6
    fi
    
else
    input_main_folder=$1
    output_main_folder=$2
    motion_correction_mode=1
    default_thickness=2.5
    recon_resolution=0.7
    num_packages=-1
fi


echo " - input folder : " ${input_main_folder}
echo " - output folder : " ${output_main_folder}
echo " - motion correction mode : " ${motion_correction_mode}
echo " - slice thickness : " ${default_thickness}
echo " - output resolution : " ${recon_resolution}


recon_roi=body


test_dir=${input_main_folder}
if [ ! -d $test_dir ];then
    echo
	echo "ERROR: NO FOLDER WITH THE INPUT FILES FOUND !!!!" 
	exit
fi


test_dir=${output_main_folder}
if [ ! -d $test_dir ];then
	mkdir ${output_main_folder}
fi 



cd ${default_run_dir}
main_dir=$(pwd)



number_of_stacks=$(find ${input_main_folder}/ -name "*.dcm" | wc -l)
if [ $number_of_stacks -gt 0 ];then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "FOUND .dcm FILES - CONVERTING TO .nii.gz !!!!"
    echo "-----------------------------------------------------------------------------"
    echo
    cd ${input_main_folder}/
    ${dcm2niix_path}/dcm2niix -z y .
    cd ${main_dir}/
fi



number_of_stacks=$(find ${input_main_folder}/ -name "*.nii*" | wc -l)
if [ $number_of_stacks -eq 0 ];then
    echo
    echo "-----------------------------------------------------------------------------"
	echo "ERROR: NO INPUT .nii / .nii.gz FILES FOUND !!!!"
    echo "-----------------------------------------------------------------------------"
    echo
	exit
fi 

mkdir ${default_run_dir}/org-files
find ${input_main_folder}/ -name "*.nii*" -exec cp {} ${default_run_dir}/org-files  \; 


number_of_stacks=$(find ${default_run_dir}/org-files -name "*SVR-output*.nii*" | wc -l)
if [ $number_of_stacks -gt 0 ];then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "WARNING: FOUND ALREADY EXISTING *SVR-output* FILES IN THE DATA FOLDER !!!!"
    echo "-----------------------------------------------------------------------------"
    echo "note: they won't be used in reconstruction"
    echo
    rm ${default_run_dir}/org-files/"*SVR-output*.nii*"
fi

number_of_stacks=$(find ${default_run_dir}/org-files -name "*mask*.nii*" | wc -l)
if [ $number_of_stacks -gt 0 ];then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "WARNING: FOUND *mask* FILES IN THE DATA FOLDER !!!!"
    echo "-----------------------------------------------------------------------------"
    echo "note: they won't be used in reconstruction"
    echo
    rm ${default_run_dir}/org-files/"*mask*.nii*"
fi

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
read -rd '' -a all_stacks <<<"$stack_names"

echo
echo "-----------------------------------------------------------------------------"
echo "REMOVING NAN & NEGATIVE/EXTREME VALUES & SPLITTING INTO DYNAMICS ..."
echo "-----------------------------------------------------------------------------"
echo

for ((i=0;i<${#all_stacks[@]};i++));
do
    echo " - " ${i} " : " ${all_stacks[$i]}

    st=${all_stacks[$i]}
    st=$(echo ${st//.nii.gz\//\.nii.gz})
    st=$(echo ${st//.nii\//\.nii})
    
    ${mirtk_path}/mirtk nan ${st} 100000
    ${mirtk_path}/mirtk extract-image-region ${st} ${st} -split t
    rm ${st}
done


stack_names=$(ls *.nii*)
read -rd '' -a all_stacks <<<"$stack_names"


if [ $num_packages -ne 1 ]; then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "SPLITTING INTO PACKAGES ..."
    echo "-----------------------------------------------------------------------------"
    echo

    for ((i=0;i<${#all_stacks[@]};i++));
    do
        echo " - " ${i} " : " ${all_stacks[$i]}
        
        st=${all_stacks[$i]}
        st=$(echo ${st//.nii.gz\//\.nii.gz})
        st=$(echo ${st//.nii\//\.nii})
        
        ${mirtk_path}/mirtk extract-packages ${st} ${num_packages}

        rm ${st}
        rm package-template.nii.gz

    done
fi


    mkdir ${default_run_dir}/tmp-res-global

    stack_names=$(ls *.nii*)
    read -rd '' -a all_stacks <<<"$stack_names"

    echo
    echo "-----------------------------------------------------------------------------"
    echo "PREPROCESSING FOR LOCALISATION ..."
    echo "-----------------------------------------------------------------------------"
    echo

    for ((i=0;i<${#all_stacks[@]};i++));
    do
        echo " - " ${i} " : " ${all_stacks[$i]}
        
        st=${all_stacks[$i]}
        st=$(echo ${st//.nii.gz\//\.nii.gz})
        st=$(echo ${st//.nii\//\.nii})
        
        jj=$((${i}+1000))
        
        ${mirtk_path}/mirtk resample-image ${st} ${main_dir}/tmp-res-global/stack-${jj}.nii.gz -size 1.5 1.5 1.5

    done


echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "GLOBAL LOCALISATION SEGMENTATION..."
echo

cd ${main_dir}

echo
echo "-----------------------------------------------------------------------------"
echo "RUNNING GLOBAL BODY+BRAIN LOCALISATION ..."
echo "-----------------------------------------------------------------------------"
echo

number_of_stacks=$(ls org-files-preproc/*.nii* | wc -l)
stack_names=$(ls org-files-preproc/*.nii*)

echo " ... "

res=128
monai_lab_num=2
number_of_stacks=$(find tmp-res-global/ -name "*.nii*" | wc -l)
${mirtk_path}/mirtk prepare-for-monai res-global-files/ global-files/ stack-info.json stack-info.csv ${res} ${number_of_stacks} tmp-res-global/*nii* > tmp.log

current_monai_check_path=${model_path}/monai-checkpoints-unet-global-loc-2-lab

mkdir monai-segmentation-results-global
python ${segm_path}/run_monai_unet_segmentation-2022.py ${main_dir}/ ${current_monai_check_path}/ stack-info.json ${main_dir}/monai-segmentation-results-global ${res} ${monai_lab_num}


number_of_stacks=$(find monai-segmentation-results-global/ -name "*.nii*" | wc -l)
if [ ${number_of_stacks} -eq 0 ];then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "ERROR: GLOBAL CNN LOCALISATION DID NOT WORK !!!!"
    echo "-----------------------------------------------------------------------------"
    echo
    exit
fi

echo
echo "-----------------------------------------------------------------------------"
echo "EXTRACTING LABELS ..."
echo "-----------------------------------------------------------------------------"
echo

out_mask_names=$(ls monai-segmentation-results-global/cnn-*.nii*)
read -rd '' -a all_masks <<<"$out_mask_names"

org_stack_names=$(ls org-files-preproc/*.nii*)
read -rd '' -a all_org_stacks <<<"$org_stack_names"


mkdir out-global-masks
# mkdir cropped-stacks-brain
mkdir cropped-stacks-body
# mkdir recon-stacks-brain
mkdir recon-stacks-body
mkdir masked-cropped-stacks-body

mkdir recon-masks-body

for ((i=0;i<${#all_org_stacks[@]};i++));
do
    echo " - " ${i} " : " ${all_org_stacks[$i]} ${all_masks[$i]}
    
    jj=$((${i}+1000))
    
    ${mirtk_path}/mirtk extract-label ${all_masks[$i]} out-global-masks/mask-body-${jj}.nii.gz 1 1
    # ${mirtk_path}/mirtk extract-label ${all_masks[$i]} out-global-masks/mask-brain-${jj}.nii.gz 2 2
    
    # ${mirtk_path}/mirtk erode-image out-global-masks/mask-brain-${jj}.nii.gz out-global-masks/mask-brain-${jj}.nii.gz -iterations 1

    ${mirtk_path}/mirtk erode-image out-global-masks/mask-body-${jj}.nii.gz out-global-masks/mask-body-${jj}.nii.gz -iterations 1
    ${mirtk_path}/mirtk extract-connected-components out-global-masks/mask-body-${jj}.nii.gz out-global-masks/mask-body-${jj}.nii.gz -n 1
    ${mirtk_path}/mirtk dilate-image out-global-masks/mask-body-${jj}.nii.gz out-global-masks/mask-body-${jj}.nii.gz -iterations 1


    # ${mirtk_path}/mirtk extract-connected-components out-global-masks/mask-brain-${jj}.nii.gz out-global-masks/mask-brain-${jj}.nii.gz -max-size 950000 -n 1

#    roi=body
#    ${mirtk_path}/mirtk dilate-image out-global-masks/mask-${roi}-${jj}.nii.gz out-global-masks/mask-${roi}-${jj}.nii.gz -iterations 2
#    ${mirtk_path}/mirtk erode-image out-global-masks/mask-brain-${jj}.nii.gz out-global-masks/mask-${roi}-${jj}.nii.gz -iterations 2
#    ${mirtk_path}/mirtk dilate-image out-global-masks/mask-${roi}-${jj}.nii.gz dl-m.nii.gz -iterations 7
#    ${mirtk_path}/mirtk crop-image ${all_org_stacks[$i]} dl-m.nii.gz recon-stacks-${roi}/stack-${jj}.nii.gz
#
#    ${mirtk_path}/mirtk dilate-image out-global-masks/mask-${roi}-${jj}.nii.gz dl-m.nii.gz -iterations 2
#    ${mirtk_path}/mirtk crop-image ${all_org_stacks[$i]} dl-m.nii.gz cropped-stacks-${roi}/stack-${jj}.nii.gz
#    ${mirtk_path}/mirtk mask-image cropped-stacks-${roi}/stack-${jj}.nii.gz dl-m.nii.gz cropped-stacks-${roi}/stack-${jj}.nii.gz
    
    roi=body
#    ${mirtk_path}/mirtk erode-image out-global-masks/mask-${roi}-${jj}.nii.gz out-global-masks/mask-${roi}-${jj}.nii.gz -iterations 2
#    ${mirtk_path}/mirtk dilate-image out-global-masks/mask-brain-${jj}.nii.gz out-global-masks/mask-${roi}-${jj}.nii.gz -iterations 2
    ${mirtk_path}/mirtk dilate-image out-global-masks/mask-${roi}-${jj}.nii.gz dl-m.nii.gz -iterations 5
    ${mirtk_path}/mirtk crop-image ${all_org_stacks[$i]} dl-m.nii.gz cropped-stacks-${roi}/stack-${jj}.nii.gz
    cp cropped-stacks-${roi}/stack-${jj}.nii.gz recon-stacks-${roi}/
#    ${mirtk_path}/mirtk mask-image cropped-stacks-${roi}/stack-${jj}.nii.gz dl-m.nii.gz masked-cropped-stacks-${roi}/stack-${jj}.nii.gz
    cp cropped-stacks-${roi}/stack-${jj}.nii.gz masked-cropped-stacks-${roi}/stack-${jj}.nii.gz
    ${mirtk_path}/mirtk resample-image masked-cropped-stacks-${roi}/stack-${jj}.nii.gz masked-cropped-stacks-${roi}/stack-${jj}.nii.gz -size 1.5 1.5 1.5


done


# echo
# echo "-----------------------------------------------------------------------------"
# echo "-----------------------------------------------------------------------------"
# echo
# echo "LOCAL ROI SEGMENTATION ..."
# echo

cd ${main_dir}

# mkdir recon-masks-brain/


# echo
# echo "-----------------------------------------------------------------------------"
# echo "RUNNING BODY SEGMENTATION ..."
# echo "-----------------------------------------------------------------------------"
# echo
    
# number_of_stacks=$(ls masked-cropped-stacks-${roi}/*.nii* | wc -l)
# stack_names=$(ls masked-cropped-stacks-${roi}/*.nii*)
    
# echo " ... "
    
# roi=brain
# res=128
# monai_lab_num=1
# ${mirtk_path}/mirtk prepare-for-monai res-cropped-files/ again-cropped-files/ cropped-stack-info.json cropped-stack-info.csv ${res} ${number_of_stacks} masked-cropped-stacks-${roi}/*nii* > tmp.log
    
# current_monai_check_path=${model_path}/monai-checkpoints-atunet-brain_bet_all_degree_raw_stacks-1-lab

# mkdir monai-segmentation-results-stack-brain
# python ${segm_path}/run_monai_atunet_segmentation-2022.py ${main_dir}/ ${current_monai_check_path}/ cropped-stack-info.json ${main_dir}/monai-segmentation-results-stack-brain ${res} ${monai_lab_num}
    
# number_of_stacks=$(find monai-segmentation-results-stack-brain/ -name "*.nii*" | wc -l)
# if [ ${number_of_stacks} -eq 0 ];then
#     echo
#     echo "-----------------------------------------------------------------------------"
#     echo "ERROR: brain CNN LOCALISATION DID NOT WORK !!!!"
#     echo "-----------------------------------------------------------------------------"
#     echo "note: check whether Segmentation_FetalMRI_MONAI was activated"
#     echo "conda init bash"
#     echo "conda activate Segmentation_FetalMRI_MONAI"
#     echo
#     exit
# fi

# echo
# echo "-----------------------------------------------------------------------------"
# echo "EXTRACTING LABELS ..."
# echo "-----------------------------------------------------------------------------"
# echo

# out_mask_names=$(ls monai-segmentation-results-stack-brain/cnn-*.nii*)
# read -rd '' -a all_masks <<<"$out_mask_names"
    
# org_stack_names=$(ls cropped-stacks-${roi}/*.nii*)
# read -rd '' -a all_org_stacks <<<"$org_stack_names"

# mkdir  masked-cropped-files-brain
    
# for ((i=0;i<${#all_org_stacks[@]};i++));
# do
#     echo " - " ${i} " : " ${all_org_stacks[$i]} ${all_masks[$i]}
        
#     jj=$((${i}+1000))
        
#     ${mirtk_path}/mirtk extract-label ${all_masks[$i]} recon-masks-brain/mask-${jj}.nii.gz 1 1
#     ${mirtk_path}/mirtk erode-image recon-masks-brain/mask-${jj}.nii.gz recon-masks-brain/mask-${jj}.nii.gz -iterations 2
#     ${mirtk_path}/mirtk extract-connected-components recon-masks-brain/mask-${jj}.nii.gz recon-masks-brain/mask-${jj}.nii.gz -n 1 -max-size 700000
#     ${mirtk_path}/mirtk dilate-image recon-masks-brain/mask-${jj}.nii.gz recon-masks-brain/mask-${jj}.nii.gz -iterations 2
    
#     ${mirtk_path}/mirtk transform-image recon-masks-brain/mask-${jj}.nii.gz recon-masks-brain/mask-${jj}.nii.gz -target recon-stacks-brain/stack-${jj}.nii.gz -labels
    
#     ${mirtk_path}/mirtk centre-volume recon-stacks-brain/stack-${jj}.nii.gz recon-masks-brain/mask-${jj}.nii.gz recon-stacks-brain/stack-${jj}.nii.gz
#     ${mirtk_path}/mirtk centre-volume recon-masks-brain/mask-${jj}.nii.gz recon-masks-brain/mask-${jj}.nii.gz recon-masks-brain/mask-${jj}.nii.gz
    
#     if [ $motion_correction_mode -eq 1 ]; then
    
#         ${mirtk_path}/mirtk dilate-image recon-masks-brain/mask-${jj}.nii.gz dl.nii.gz -iterations 3
        
#         ${mirtk_path}/mirtk crop-image recon-stacks-brain/stack-${jj}.nii.gz  dl.nii.gz masked-cropped-files-brain/stack-${jj}.nii.gz
#         ${mirtk_path}/mirtk mask-image masked-cropped-files-brain/stack-${jj}.nii.gz  dl.nii.gz masked-cropped-files-brain/stack-${jj}.nii.gz
        
#         ${mirtk_path}/mirtk resample-image masked-cropped-files-brain/stack-${jj}.nii.gz masked-cropped-files-brain/stack-${jj}.nii.gz -size 1 1 1 -interp Linear
#     fi
# done


# if [ $motion_correction_mode -eq 1 ]; then

    echo
    echo "-----------------------------------------------------------------------------"
    echo "RUNNING BODY ROI REORIENTATION ..."
    echo "-----------------------------------------------------------------------------"
    echo

    number_of_stacks=$(ls masked-cropped-stacks-body/*.nii* | wc -l)
    stack_names=$(ls masked-cropped-stacks-body/*.nii*)
    
    echo " ... "
    
    roi=body
    res=128
    monai_lab_num=4
    ${mirtk_path}/mirtk prepare-for-monai res-cropped-files/ again-cropped-files/ reo-cropped-stack-info.json reo-cropped-stack-info.csv ${res} ${number_of_stacks} masked-cropped-stacks-body/*nii* > tmp.log
    
    current_monai_check_path=${model_path}/monai-checkpoints-unet-stack-body-reo-4-lab
    
    mkdir monai-segmentation-results-stack-reo
    python ${segm_path}/run_monai_unet_segmentation-2022.py ${main_dir}/ ${current_monai_check_path}/ reo-cropped-stack-info.json ${main_dir}/monai-segmentation-results-stack-reo ${res} ${monai_lab_num}
    
    
    number_of_stacks=$(find monai-segmentation-results-stack-reo/ -name "*.nii*" | wc -l)
    if [ ${number_of_stacks} -eq 0 ];then
        echo
        echo "-----------------------------------------------------------------------------"
        echo "ERROR: REO CNN LOCALISATION DID NOT WORK !!!!"
        echo "-----------------------------------------------------------------------------"
        echo
        exit 
    fi

    echo
    echo "-----------------------------------------------------------------------------"
    echo "EXTRACTING REO LABELS AND REORIENTING ..."
    echo "-----------------------------------------------------------------------------"
    echo

    out_mask_names=$(ls monai-segmentation-results-stack-reo/cnn-*.nii*)
    read -rd '' -a all_masks <<<"$out_mask_names"

    org_stack_names=$(ls cropped-stacks-${roi}/*.nii*)
    read -rd '' -a all_org_stacks <<<"$org_stack_names"

    mkdir out-stack-reo-masks
    mkdir out-dofs-to-templates
    
    ${mirtk_path}/mirtk init-dof init.dof
    
    for ((i=0;i<${#all_org_stacks[@]};i++));
    do
        echo " - " ${i} " : " ${all_org_stacks[$i]} ${all_masks[$i]}
        
        jj=$((${i}+1000))
        
        for ((q=1;q<5;q++));
        do
            ${mirtk_path}/mirtk extract-label ${all_masks[$i]} out-stack-reo-masks/mask-${jj}-${q}.nii.gz ${q} ${q}
            ${mirtk_path}/mirtk dilate-image out-stack-reo-masks/mask-${jj}-${q}.nii.gz out-stack-reo-masks/mask-${jj}-${q}.nii.gz
            ${mirtk_path}/mirtk erode-image out-stack-reo-masks/mask-${jj}-${q}.nii.gz out-stack-reo-masks/mask-${jj}-${q}.nii.gz
            ${mirtk_path}/mirtk extract-connected-components out-stack-reo-masks/mask-${jj}-${q}.nii.gz out-stack-reo-masks/mask-${jj}-${q}.nii.gz
        done


        ${mirtk_path}/mirtk extract-label ${all_masks[$i]} recon-masks-body/mask-${jj}.nii.gz 1 2
        ${mirtk_path}/mirtk erode-image recon-masks-body/mask-${jj}.nii.gz recon-masks-body/mask-${jj}.nii.gz
        ${mirtk_path}/mirtk extract-connected-components recon-masks-body/mask-${jj}.nii.gz recon-masks-body/mask-${jj}.nii.gz
        ${mirtk_path}/mirtk dilate-image recon-masks-body/mask-${jj}.nii.gz recon-masks-body/mask-${jj}.nii.gz



        n_roi=4; z1=1; z2=2; z3=3; z4=4;
        current_template_path=${template_path}/body-stack-reo-template-2023
        ${mirtk_path}/mirtk register-landmarks mask-${z1}.nii.gz out-stack-reo-masks/mask-${jj}-${z1}.nii.gz init.dof  out-dofs-to-templates/dof-to-atl-${jj}.dof ${n_roi} ${n_roi} ${current_template_path}/mask-${z1}.nii.gz ${current_template_path}/mask-${z2}.nii.gz ${current_template_path}/mask-${z3}.nii.gz ${current_template_path}/mask-${z4}.nii.gz  out-stack-reo-masks/mask-${jj}-${z1}.nii.gz out-stack-reo-masks/mask-${jj}-${z2}.nii.gz out-stack-reo-masks/mask-${jj}-${z3}.nii.gz out-stack-reo-masks/mask-${jj}-${z4}.nii.gz > tmp.log
        cp out-dofs-to-templates/dof-to-atl-${jj}.dof init.dof
        
        test_file=out-dofs-to-templates/dof-to-atl-${jj}.dof
        if [ ! -f ${test_file} ];then
            echo
            echo "-----------------------------------------------------------------------------"
            echo "ERROR: REORIENTATION DID NOT WORK !!!!"
            echo "-----------------------------------------------------------------------------"
            echo
            exit
        fi
        
    
        ${mirtk_path}/mirtk edit-image recon-stacks-body/stack-${jj}.nii.gz recon-stacks-body/stack-${jj}.nii.gz -dofin_i out-dofs-to-templates/dof-to-atl-${jj}.dof
        ${mirtk_path}/mirtk edit-image recon-masks-body/mask-${jj}.nii.gz recon-masks-body/mask-${jj}.nii.gz -dofin_i out-dofs-to-templates/dof-to-atl-${jj}.dof
        ${mirtk_path}/mirtk transform-image recon-masks-body/mask-${jj}.nii.gz recon-masks-body/mask-${jj}.nii.gz -labels -target recon-stacks-body/stack-${jj}.nii.gz
        
        # ${mirtk_path}/mirtk centre-volume recon-stacks-brain/stack-${jj}.nii.gz recon-masks-brain/mask-${jj}.nii.gz recon-stacks-brain/stack-${jj}.nii.gz
        # ${mirtk_path}/mirtk centre-volume recon-masks-brain/mask-${jj}.nii.gz recon-masks-brain/mask-${jj}.nii.gz recon-masks-brain/mask-${jj}.nii.gz

    done
    


# fi



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "RUNNING RECONSTRUCTION ..."
echo

cd ${main_dir}


if [ $recon_roi = "body" ]; then

    echo
    echo "-----------------------------------------------------------------------------"
    echo "SELECTING STACKS / GENERATING TEMPLATE ..."
    echo "-----------------------------------------------------------------------------"
    echo
    
    cd ${main_dir}
    
    recon_roi_global=body
    
    number_of_stacks=$(ls recon-stacks-${recon_roi_global}/*.nii* | wc -l)
    stack_names=$(ls recon-stacks-${recon_roi_global}/*.nii*)
    mask_names=$(ls recon-masks-${recon_roi}/*.nii*)
    
    
    mkdir proc-stacks-${recon_roi}
    
#    if [ $motion_correction_mode -eq 1 ]; then

        echo " ... "

        # /home/legacy/MIRTK/build/bin/mirtk 
        

        # ${mirtk_path}/mirtk stacks-and-masks-selection ${number_of_stacks} $(echo $stack_names) $(echo $mask_names) proc-stacks-${recon_roi} 15 1

        ${mirtk_path}/mirtk stacks-selection ${number_of_stacks} $(echo $stack_names) $(echo $mask_names) proc-stacks-${recon_roi} 11 1 0.5 

#    fi
    
#    > tmp.txt
    
    test_file=selected_template.nii.gz
    if [ ! -f ${test_file} ];then
        echo
        echo "-----------------------------------------------------------------------------"
        echo "COMPUTING GLOBAL AVERAGE - THE AUTO-SELECTION FAILED ..."
        echo "-----------------------------------------------------------------------------"
        echo
         
        ${mirtk_path}/mirtk average-images selected_template.nii.gz recon-stacks-${recon_roi_global}/*.nii*
        ${mirtk_path}/mirtk resample-image selected_template.nii.gz selected_template.nii.gz -size 1 1 1
        ${mirtk_path}/mirtk average-images selected_template.nii.gz recon-stacks-${recon_roi_global}/*.nii* -target selected_template.nii.gz
        ${mirtk_path}/mirtk average-images average_mask_cnn.nii.gz recon-masks-${recon_roi}/*.nii* -target selected_template.nii.gz
        ${mirtk_path}/mirtk convert-image average_mask_cnn.nii.gz average_mask_cnn.nii.gz -short
        cp recon-stacks-${recon_roi_global}/*.nii* proc-stacks-${recon_roi}/
         
        ${mirtk_path}/mirtk mask-image selected_template.nii.gz average_mask_cnn.nii.gz masked-selected_template.nii.gz

        out_mask_names=$(ls recon-masks-${recon_roi}/*.nii*)
        read -rd '' -a all_masks <<<"$out_mask_names"
        
        org_stack_names=$(ls recon-stacks-${recon_roi_global}/*.nii*)
        read -rd '' -a all_org_stacks <<<"$org_stack_names"
        
        ${mirtk_path}/mirtk init-dof init.dof
        
        for ((i=0;i<${#all_org_stacks[@]};i++));
        do
            echo " - " ${i} " ... "

            ${mirtk_path}/mirtk mask-image ${all_org_stacks[$i]} ${all_masks[$i]} tmp-stack.nii.gz
            ${mirtk_path}/mirtk register masked-selected_template.nii.gz tmp-stack.nii.gz -model Rigid -dofin init.dof -dofout d.dof -v 0
            ${mirtk_path}/mirtk edit-image ${all_org_stacks[$i]} ${all_org_stacks[$i]} -dofin_i d.dof
            ${mirtk_path}/mirtk edit-image ${all_masks[$i]} ${all_masks[$i]} -dofin_i d.dof
        done
        
        ${mirtk_path}/mirtk average-images selected_template.nii.gz recon-stacks-${recon_roi_global}/*.nii* -target selected_template.nii.gz
        ${mirtk_path}/mirtk average-images average_mask_cnn.nii.gz recon-masks-${recon_roi}/*.nii* -target selected_template.nii.gz
#        ${mirtk_path}/mirtk nan average_mask_cnn.nii.gz 0
        ${mirtk_path}/mirtk nan selected_template.nii.gz 1000000
        ${mirtk_path}/mirtk convert-image average_mask_cnn.nii.gz average_mask_cnn.nii.gz -short

    else 

        ${mirtk_path}/mirtk average-images selected_template.nii.gz proc-stacks-${recon_roi}/*.nii* -target selected_template.nii.gz

    fi
     
    # current_template_path=${template_path}/brain-stack-reo-template
    # if [ $motion_correction_mode -eq 1 ]; then
        ${mirtk_path}/mirtk resample-image ${template_path}/body-stack-reo-template-2023/ref-space.nii.gz ref.nii.gz -size 1 1 1
        ${mirtk_path}/mirtk transform-image selected_template.nii.gz transf-selected_template.nii.gz -target ref.nii.gz -interp Linear
        ${mirtk_path}/mirtk crop-image transf-selected_template.nii.gz transf-selected_template.nii.gz transf-selected_template.nii.gz
    # else
        # cp selected_template.nii.gz transf-selected_template.nii.gz
    # fi
    
    ${mirtk_path}/mirtk dilate-image average_mask_cnn.nii.gz average_mask_cnn.nii.gz -iterations 4
    ${mirtk_path}/mirtk erode-image average_mask_cnn.nii.gz average_mask_cnn.nii.gz -iterations 2

    echo
    echo "-----------------------------------------------------------------------------"
    echo "DSVR RECONSTRUCTION ..."
    echo "-----------------------------------------------------------------------------"
    echo

    mkdir out-recon-files-${recon_roi}
    cd out-recon-files-${recon_roi}
    number_of_stacks=$(ls ../proc-stacks-${recon_roi}/*.nii* | wc -l)
    
    
    # NO STRUCTURAL ?????

    ${mirtk_path}/mirtk reconstructFFD ../DSVR-output-${recon_roi}.nii.gz  ${number_of_stacks} ../proc-stacks-${recon_roi}/*.nii* -mask ../average_mask_cnn.nii.gz -template ../transf-selected_template.nii.gz -default_thickness ${default_thickness} -resolution ${recon_resolution} -iterations 2 -cp 15 9 -default -structural -dilation 5 -delta 110 -lambda 0.018 -lastIter 0.008 
    


    # if [ $motion_correction_mode -eq 1 ]; then
    
    #     ${mirtk_path}/mirtk reconstruct ../SVR-output-${recon_roi}.nii.gz ${number_of_stacks} ../proc-stacks-${recon_roi}/*.nii* -mask ../average_mask_cnn.nii.gz -template tmp-output.nii.gz -default_thickness ${default_thickness} -iterations 3 -resolution ${recon_resolution} -structural -svr_only -with_background
        
    # else
    
    #     ${mirtk_path}/mirtk reconstruct ../SVR-output-${recon_roi}.nii.gz ${number_of_stacks} ../proc-stacks-${recon_roi}/*.nii* -mask ../average_mask_cnn.nii.gz -template tmp-output.nii.gz -default_thickness ${default_thickness}  -iterations 3 -resolution ${recon_resolution} -svr_only -with_background
        
    # fi
        
    
#   -delta 110 -lambda 0.018 -lastIter 0.008 ;
    
    test_file=../DSVR-output-${recon_roi}.nii.gz
    if [ ! -f ${test_file} ];then
        echo
        echo "-----------------------------------------------------------------------------"
        echo "ERROR: SVR RECONSTRUCTION DID NOT WORK !!!!"
        echo "-----------------------------------------------------------------------------"
        echo
        exit
    fi
    
    
    # ${mirtk_path}/mirtk dilate-image ../average_mask_cnn.nii.gz dl.nii.gz -iterations 6
    # ${mirtk_path}/mirtk mask-image ../DSVR-output-${recon_roi}.nii.gz dl.nii.gz ../masked-DSVR-output-${recon_roi}.nii.gz
    
    
    echo
    echo "-----------------------------------------------------------------------------"
    echo "REORIENTATION TO THE STANDARD SPACE ..."
    echo "-----------------------------------------------------------------------------"
    echo
    
    cd ${main_dir}
    

    number_of_stacks=1
    roi=body
    res=128
    monai_lab_num=4
    
    echo " ... "
    
    ${mirtk_path}/mirtk mask-image DSVR-output-${recon_roi}.nii.gz average_mask_cnn.nii.gz   masked-DSVR-output-${recon_roi}.nii.gz
    
    ${mirtk_path}/mirtk prepare-for-monai res-svr-files/ svr-files/ reo-svr-info.json reo-svr-info.csv ${res} ${number_of_stacks} masked-DSVR-output-${recon_roi}.nii.gz > tmp.log

    current_monai_check_path=${model_path}/monai-checkpoints-unet-thorax-reo-4-lab-cmr
    
    mkdir monai-segmentation-results-svr-reo
    python ${segm_path}/run_monai_unet_segmentation-2022.py ${main_dir}/ ${current_monai_check_path}/ reo-svr-info.json ${main_dir}/monai-segmentation-results-svr-reo ${res} ${monai_lab_num}
    
    
    number_of_stacks=$(find monai-segmentation-results-svr-reo/ -name "*.nii*" | wc -l)
    if [ ${number_of_stacks} -eq 0 ];then
        echo
        echo "-----------------------------------------------------------------------------"
        echo "ERROR: REO CNN LOCALISATION DID NOT WORK !!!!"
        echo "-----------------------------------------------------------------------------"
        echo
        exit
    fi
    
    mkdir out-svr-reo-masks
    for ((q=1;q<6;q++));
    do
        ${mirtk_path}/mirtk extract-label monai-segmentation-results-svr-reo/cnn* out-svr-reo-masks/mask-${q}.nii.gz ${q} ${q}
        ${mirtk_path}/mirtk dilate-image out-svr-reo-masks/mask-${q}.nii.gz out-svr-reo-masks/mask-${q}.nii.gz  -iterations 2
        ${mirtk_path}/mirtk erode-image out-svr-reo-masks/mask-${q}.nii.gz out-svr-reo-masks/mask-${q}.nii.gz   -iterations 2
        ${mirtk_path}/mirtk extract-connected-components out-svr-reo-masks/mask-${q}.nii.gz out-svr-reo-masks/mask-${q}.nii.gz -n 1

    done

    thorax_reo_template=${template_path}/thorax-reo-template 

    z1=1; z2=2; z3=3; z4=4; n_roi=4;
    ${mirtk_path}/mirtk init-dof init.dof
    ${mirtk_path}/mirtk register-landmarks ${thorax_reo_template}/thorax-atlas.nii.gz ${all_org_stacks[$j]} init.dof dof-to-atl-${recon_roi}.dof ${n_roi} ${n_roi}  ${thorax_reo_template}/thorax-reo-atlas-label-${z1}.nii.gz ${thorax_reo_template}/thorax-reo-atlas-label-${z2}.nii.gz ${thorax_reo_template}/thorax-reo-atlas-label-${z3}.nii.gz ${thorax_reo_template}/thorax-reo-atlas-label-${z4}.nii.gz out-svr-reo-masks/mask-${z1}.nii.gz out-svr-reo-masks/mask-${z2}.nii.gz out-svr-reo-masks/mask-${z3}.nii.gz out-svr-reo-masks/mask-${z4}.nii.gz > tmp.log


    ${mirtk_path}/mirtk info dof-to-atl-${recon_roi}.dof
    
    ${mirtk_path}/mirtk resample-image ${thorax_reo_template}/thorax-ref.nii.gz  ref.nii.gz -size ${recon_resolution} ${recon_resolution} ${recon_resolution}

    ${mirtk_path}/mirtk transform-image DSVR-output-${recon_roi}.nii.gz reo-DSVR-output-${recon_roi}.nii.gz -target ref.nii.gz -dofin dof-to-atl-${recon_roi}.dof -interp BSpline
    ${mirtk_path}/mirtk threshold-image reo-DSVR-output-${recon_roi}.nii.gz tmp-m.nii.gz 0.01
    ${mirtk_path}/mirtk crop-image reo-DSVR-output-${recon_roi}.nii.gz tmp-m.nii.gz reo-DSVR-output-${recon_roi}.nii.gz
    ${mirtk_path}/mirtk nan reo-DSVR-output-${recon_roi}.nii.gz 100000


    test_file=reo-DSVR-output-${recon_roi}.nii.gz
    if [ ! -f ${test_file} ];then
        echo
        echo "-----------------------------------------------------------------------------"
        echo "ERROR: REORIENTATION OF RECONSTRUCTED IMAGE DID NOT WORK !!!!"
        echo "-----------------------------------------------------------------------------"
        echo
        exit
    fi
    
    number_of_final_recons=$(ls *SVR-output*.nii* | wc -l)
    if [ ${number_of_final_recons} -ne 0 ];then

        cp -r *SVR-output*nii* ${output_main_folder}/
        cp -r average_mask_cnn.nii.gz ${output_main_folder}/

        echo "-----------------------------------------------------------------------------"
        echo "Reconstructed SVR results are in the output folder : " ${output_main_folder}
        echo "-----------------------------------------------------------------------------"
        
    else
        echo
        echo "-----------------------------------------------------------------------------"
        echo "ERROR: COULD NOT COPY THE FILES TO THE OUTPUT FOLDER : " ${output_main_folder}
        echo "PLEASE CHECK THE WRITE PERMISSIONS / LOCATION !!!"
        echo
        echo "note: you can still find the recon files in : " ${main_dir}
        echo "-----------------------------------------------------------------------------"
        echo
        exit
    fi

fi


echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo





