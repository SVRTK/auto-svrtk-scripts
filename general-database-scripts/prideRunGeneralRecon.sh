#!/bin/bash 

### runGeneralRecon.sh
#
# Combined script to perform many different SVR reconstruction options
#
# - USAGE: 
# - Download data from ISDPACS / raw format and copy into Input_Data folder in YOUR user area.
# - Run /FetalPreprocessing/bin-updates/prideRunGeneralRecon.sh
#
# - Asks the user to enter PatientID and scan date
# - Creates a folder using date (if required) and subfolder based on PatientID
# - Copies files across for automatic / manual SVR
# - Copies files back to patient folder once reconstruction is completed
#
#
# - RECENT UPDATES:
# - 06/2022 & 12/2022 & 06/2023:
# - General manual + automated reconstruction code for multiple options 
# - Transfer to PRIDE 
#
# - Tom Roberts, KCL, 2018-2021
# - t.roberts@kcl.ac.uk
#
# - Alena Uus, KCL, 2021-2023
# - alena.uus@kcl.ac.uk
# 
##################################################################################
 

#---------------------------------------------------------------------------------


path_input=~/Input_Data


path_fetalrep=/FetalPreprocessing
path_mirtk=/home/au18/software/mirtk-bin/bin
dcm2niix=/home/au18/software/dcm2niix/build/bin/dcm2niix

module load itksnap
itksnap=itksnap


#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### Create patient folder 
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------


cd $path_input


### Check if the folder is empty
nostudies=`ls $path_input 2>/dev/null | wc -l`
if [ $nostudies -eq 0 ] ; then
	echo "There is no data in the Input_Data folder."
	exit
fi


### Enter Patient ID twice
#---------------------------------------------------------------------------------
echo "Please type the Patient ID, followed by [ENTER]:"
read patid1

clear

echo -e "Please type the Patient ID once more, followed by [ENTER]:"
read patid2


### Check Patient ID entered correctly
#---------------------------------------------------------------------------------
echo "Checking Patient ID matches..."

if [ $patid1 = $patid2 ];then
	echo
	echo "###################"
	echo "Patient ID matches."
	echo "###################"	
	echo
	
### Exit script if Patient ID entered incorrectly
else
	echo
	echo "#############################################################"
	echo "Patient ID entered incorrectly. Please run this script again."
	echo "#############################################################"
	echo
	exit
fi


# define patient folder name
patientFolder=$patid1


### Enter study date and check date entered correctly
#---------------------------------------------------------------------------------
echo "Please input the date of the scan. Press [ENTER] after each step:"

while true; do
    
echo "Year (YYYY):"
read date_year
echo "Month (MM):"
read date_month
echo "Day (DD):"
read date_day
echo
echo "Date entered as: "$date_year"_"$date_month"_"$date_day
echo	
	
	read -p "Is this the correct date? [y/n]: " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) echo; echo "Please re-input the date of the scan. Press [ENTER] after each step:";;
        * ) echo "Please answer yes or no.";;
    esac
done 


 


#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### Select recon type
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------

echo
echo  "Please select reconstruction type, followed by [ENTER]:"
echo " - 1 - automated T2w brain SVR 1.5-3T (singleton pregnancy and TSE only)"
echo " - 2 - manual brain SVR (for failed auto and twins or BTFE / T1w )"
echo " - 3 - automated T2w body SVR 1.5-3T (singleton pregnancy and TSE only)"
echo " - 4 - manual body SVR (for failed auto and twins or BTFE / T1w)"
echo " - 5 - automated head SVR (singleton pregnancy and TSE only)"
echo 
echo " - 6 - automated T2w brain SVR 0.55T (singleton pregnancy and TSE only)"
echo " - 7 - automated T2w body DSVR 0.55T (singleton pregnancy and TSE only)"
echo

read recon_type
echo

if [[ $recon_type -eq 1 ]];then
    patientFolder=${patientFolder}_BRAIN
fi
if [[ $recon_type -eq 2 ]];then
    patientFolder=${patientFolder}_BRAIN
fi
if [[ $recon_type -eq 3 ]];then
    patientFolder=${patientFolder}_BODY
fi
if [[ $recon_type -eq 4 ]];then
    patientFolder=${patientFolder}_BODY
fi
if [[ $recon_type -eq 5 ]];then
    patientFolder=${patientFolder}_HEAD
fi
if [[ $recon_type -eq 6 ]];then
    patientFolder=${patientFolder}_BRAIN
fi
if [[ $recon_type -eq 7 ]];then
    patientFolder=${patientFolder}_BODY
fi


#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### Check/create directories for that day and patient
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------


cd $path_fetalrep #cd to fetal reporting folder

# check for folder on that day and create if doesn't exist
dayFolder=$date_year"_"$date_month"_"$date_day

if [[ ! -d "${dayFolder}" ]];then
	mkdir "$dayFolder"
	
	# give folder sticky bits permissions, so all users can share directory
	chmod 1777 $dayFolder; chmod +t $dayFolder;
	
	echo
	echo "Folder created with the date: "$dayFolder
	echo
elif [[ -d "${patientFolder}" ]];then

	cd $dayFolder
fi

cd $dayFolder #enter day folder




if [[ ! -d "${patientFolder}" ]];then
	mkdir "$patientFolder"
	
	echo "Folder created with the name: "$patientFolder
	echo
elif [[ -d "${patientFolder}" ]];then

	echo
	echo "######################################################################"
	echo "Folder already exists with this date and Patient ID!"
	echo "To prevent overwriting any data, this script will exit."
	echo "Exiting script..."
	echo "######################################################################"
	echo
	exit
fi

# Update log.txt
cd $path_input
patientFolderLength=${#patientFolder}

echo "--- automaticSVR.sh --- Automatic brain segmentation ---" >> log.txt
echo "Input_Data Path = '"$path_input"'" >> log.txt
echo "Recon Path = '"$path_fetalrep"'" >> log.txt
echo "Folder Date = '"$dayFolder"'" >> log.txt
echo "Folder Name = '*****"${patientFolder:5:$patientFolderLength}"'" >> log.txt


#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### Detect Data Type in Input_Folder and Copy to the Patient Folder
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------

cd $path_input

echo
echo "######################################################################"
echo "Identifying, Extracting and Moving Data..."
echo "######################################################################"
echo

testZIP=$(find . -name "*.zip*" | wc -l)

### Check for ZIP file(s) and unzip (or warn and abort script).

if [ $testZIP -eq 1 ]; then
	echo
	echo "Found a .ZIP file. Unzipping and examining contents..."
	echo
	
	zipFile=`ls *.zip`
	unzip $zipFile

	rm *.zip
	
elif [ $testZIP -gt 1 ]; then
	
	echo
	echo "Found multiple .ZIP files! Please check that you haven't downloaded multiple/duplicate scans."
	echo "Aborting script."
	echo
	exit

fi 

testDCM=$(find . -name "*.dcm" | wc -l)

if [ $testDCM -gt 0 ]; then

	echo
	echo "Found .dcm files. Converting to nii ..."
	echo

	${dcm2niix} -z y -f '%b' . 
	rm *.json 

fi 


testNII=$(find . -name "*.nii*" | wc -l)

if [ $testNII -gt 0 ]; then

	echo
	echo "Found .nii files: " $testNII
	echo

else 

	echo
	echo "No .nii files found! Please check that you downloaded correct datasets."
	echo "Aborting script."
	echo
	exit

fi 


echo
echo "Moving .nii files to the patient folder..."
echo

find ${path_input}/ -name "*.nii*" -exec cp {} $path_fetalrep/$dayFolder/$patientFolder \; 


yy=$path_fetalrep/$dayFolder/$patientFolder
testNII=$(find ${yy}/ -name "*cine*.nii*" | wc -l)
if [ $testNII -gt 0 ]; then
	rm ${yy}/*cine* 
fi 


rm -r ${path_input}/*


echo
echo "######################################################################"
echo "Stacks saved to:"
echo $path_fetalrep/$dayFolder/$patientFolder
echo "######################################################################"
echo

#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### Extract dynamics and rename stacks
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------


echo
echo "######################################################################"
echo "Converting stacks ..."
echo "######################################################################"
echo

cd $path_fetalrep/$dayFolder/$patientFolder

stack_names=$(ls *.nii*)
IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"

for ((i=0;i<${#all_stacks[@]};i++));
do
	echo " - " ${all_stacks[i]} 
	${path_mirtk}/mirtk extract-image-region ${all_stacks[i]} tmp-st${i} -split t
done 

stack_names=$(ls tmp-st*.nii*)
IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"

for ((i=0;i<${#all_stacks[@]};i++));
do
	j=${i}
	${path_mirtk}/mirtk edit-image ${all_stacks[i]} stack${j}.nii.gz -torigin 0 
	rm ${all_stacks[i]}
	${path_mirtk}/mirtk convert-image stack${j}.nii.gz stack${j}.nii.gz -rescale 0 1000 
	${path_mirtk}/mirtk convert-image stack${j}.nii.gz stack${j}.nii.gz -short 
done 

echo
echo "Final number of stacks: " ${#all_stacks[@]}
echo


#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### Run auto brain recon 
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------


chmod 1777 $path_fetalrep/$dayFolder/$patientFolder
chmod 1777 $path_fetalrep/$dayFolder/$patientFolder/*


if [[ $recon_type -eq 1 ]];then


    cd $path_fetalrep/$dayFolder/$patientFolder

	echo
	echo "######################################################################"
	echo "Running automatic T2w BRAIN SVR ..."
	echo "######################################################################"
	echo

	path_autoSVRrecon_input=$path_fetalrep/pride-auto-recon-files/brain
	path_autoSVRrecon_output=$path_fetalrep/pride-auto-recon-files/results-brain
	path_autoSVRrecon_patientFolder=$path_autoSVRrecon_input/$dayFolder"_"$patientFolder

	mkdir $path_autoSVRrecon_patientFolder
	cp $path_fetalrep/$dayFolder/$patientFolder/stack*.nii.gz $path_autoSVRrecon_patientFolder

	svrOutputFile=$path_autoSVRrecon_output/$dayFolder"_"$patientFolder-SVR-output.nii.gz

    chmod -R 1777 $path_fetalrep/$dayFolder/$patientFolder
    chmod -R 1777 $path_autoSVRrecon_patientFolder

	### while loop - Wait for reconstruction to complete
	isReconstructed=false
	while ! $isReconstructed; do

		echo "... still running ..."	

		# Detect output SVR file / if found, exit while loop
		if [ -f "$svrOutputFile" ]; then
			echo
			echo "SVR File Found! Copying to patient directory..."
			echo
			isReconstructed=true
            rm -r $path_autoSVRrecon_patientFolder
            rm $path_fetalrep/$dayFolder/$patientFolder/*nii*
		fi
				
		sleep 60	
		
	done

	### Copy / clean up
	cp $path_autoSVRrecon_output/$dayFolder"_"$patientFolder-SVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder
	mv $path_fetalrep/$dayFolder/$patientFolder/$dayFolder"_"$patientFolder-SVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder/outputSVRvolume.nii.gz
	#rm -r $path_autoSVRrecon_patientFolder


	echo "######################################################################"
	echo "RECONSTRUCTION FINISHED "
	echo "Data saved to: "
	echo $path_fetalrep/$dayFolder/$patientFolder
	echo "######################################################################"

    $itksnap $path_fetalrep/$dayFolder/$patientFolder/outputSVRvolume.nii.gz > nul 2>&1 

    chmod 1777 $path_fetalrep/$dayFolder/$patientFolder/*

    exit 

fi



if [[ $recon_type -eq 6 ]];then


    cd $path_fetalrep/$dayFolder/$patientFolder

	echo
	echo "######################################################################"
	echo "Running automatic T2w BRAIN SVR FOR 0.55T ..."
	echo "######################################################################"
	echo

	path_autoSVRrecon_input=$path_fetalrep/pride-auto-recon-files/brain_05t
	path_autoSVRrecon_output=$path_fetalrep/pride-auto-recon-files/results-brain_05t
	path_autoSVRrecon_patientFolder=$path_autoSVRrecon_input/$dayFolder"_"$patientFolder

	mkdir $path_autoSVRrecon_patientFolder
	cp $path_fetalrep/$dayFolder/$patientFolder/stack*.nii.gz $path_autoSVRrecon_patientFolder

	svrOutputFile=$path_autoSVRrecon_output/$dayFolder"_"$patientFolder-SVR-output.nii.gz

    chmod -R 1777 $path_fetalrep/$dayFolder/$patientFolder
    chmod -R 1777 $path_autoSVRrecon_patientFolder

	### while loop - Wait for reconstruction to complete
	isReconstructed=false
	while ! $isReconstructed; do

		echo "... still running ..."	

		# Detect output SVR file / if found, exit while loop
		if [ -f "$svrOutputFile" ]; then
			echo
			echo "SVR File Found! Copying to patient directory..."
			echo
			isReconstructed=true
            rm -r $path_autoSVRrecon_patientFolder
            rm $path_fetalrep/$dayFolder/$patientFolder/*nii*
		fi
				
		sleep 60	
		
	done

	### Copy / clean up
	cp $path_autoSVRrecon_output/$dayFolder"_"$patientFolder-SVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder
	mv $path_fetalrep/$dayFolder/$patientFolder/$dayFolder"_"$patientFolder-SVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder/outputSVRvolume.nii.gz
	#rm -r $path_autoSVRrecon_patientFolder


	echo "######################################################################"
	echo "RECONSTRUCTION FINISHED "
	echo "Data saved to: "
	echo $path_fetalrep/$dayFolder/$patientFolder
	echo "######################################################################"

    $itksnap $path_fetalrep/$dayFolder/$patientFolder/outputSVRvolume.nii.gz > nul 2>&1 

    chmod 1777 $path_fetalrep/$dayFolder/$patientFolder/*

    exit 

fi


#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### Run auto head recon 
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------


if [[ $recon_type -eq 5 ]];then


    cd $path_fetalrep/$dayFolder/$patientFolder

	echo
	echo "######################################################################"
	echo "Running automatic T2w HEAD SVR ..."
	echo "######################################################################"
	echo

	path_autoSVRrecon_input=$path_fetalrep/pride-auto-recon-files/head
	path_autoSVRrecon_output=$path_fetalrep/pride-auto-recon-files/results-head
	path_autoSVRrecon_patientFolder=$path_autoSVRrecon_input/$dayFolder"_"$patientFolder

	mkdir $path_autoSVRrecon_patientFolder
	cp $path_fetalrep/$dayFolder/$patientFolder/stack*.nii.gz $path_autoSVRrecon_patientFolder

	svrOutputFile=$path_autoSVRrecon_output/$dayFolder"_"$patientFolder-SVR-output.nii.gz

    chmod -R 1777 $path_fetalrep/$dayFolder/$patientFolder
    chmod -R 1777 $path_autoSVRrecon_patientFolder

	### while loop - Wait for reconstruction to complete
	isReconstructed=false
	while ! $isReconstructed; do

		echo "... still running ..."	

		# Detect output SVR file / if found, exit while loop
		if [ -f "$svrOutputFile" ]; then
			echo
			echo "SVR File Found! Copying to patient directory..."
			echo
			isReconstructed=true
            rm -r $path_autoSVRrecon_patientFolder
            rm $path_fetalrep/$dayFolder/$patientFolder/*nii*
		fi
				
		sleep 60	
		
	done

	### Copy / clean up
	cp $path_autoSVRrecon_output/$dayFolder"_"$patientFolder-SVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder
	mv $path_fetalrep/$dayFolder/$patientFolder/$dayFolder"_"$patientFolder-SVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder/outputSVRvolume.nii.gz
	#rm -r $path_autoSVRrecon_patientFolder


	echo "######################################################################"
	echo "RECONSTRUCTION FINISHED "
	echo "Data saved to: "
	echo $path_fetalrep/$dayFolder/$patientFolder
	echo "######################################################################"

    $itksnap $path_fetalrep/$dayFolder/$patientFolder/outputSVRvolume.nii.gz > nul 2>&1 

    chmod 1777 $path_fetalrep/$dayFolder/$patientFolder/*

    exit 

fi


#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### Run manual brain recon 
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------

if [[ $recon_type -eq 2 ]];then

	echo
	echo "######################################################################"
	echo "Running manual BRAIN SVR ..."
	echo "######################################################################"
	echo
    echo "... please wait"
 
    cd $path_fetalrep/$dayFolder/$patientFolder

    stack_names=$(ls stack*.nii.gz)
    IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"


    # ${path_mirtk}/mirtk average-images tmp-space.nii.gz stack*


    echo
    echo "There are " ${#all_stacks[@]} "stacks"
    echo
    echo "Please inspect stacks one by one and select the template for masking."
    echo
    echo "(note: the stack should represent the average position"
    echo " of the brain and be less motion-corrupted)"
    echo
    

    for ((i=0;i<${#all_stacks[@]};i++));
    do
        # j=$((${i}+100))
        # ${path_mirtk}/mirtk transform-image ${all_stacks[i]} tmp-st${j}.nii.gz -target  tmp-space.nii.gz -interp Linear

        echo  " - " ${all_stacks[i]}
        ${itksnap} ${all_stacks[i]} > nul 2>&1


    done
    
    last_n=$((${#all_stacks[@]}-1))
    numStacks=${#all_stacks[@]}


    echo 
    echo "Please enter the selected template stack number ( from 0 to" ${last_n} " ):"
    echo
    
    
    
    read template_number
    
    cp stack${template_number}.nii.gz org-template-stack.nii.gz
    
    echo
    echo "Please segment the brain in ITK-SNAP using 3D brush."
    echo "The mask file will be saved as mask.nii.gz."
    
    ${path_mirtk}/mirtk convert-image org-template-stack.nii.gz mask.nii.gz -rescale 0 0 -short
    
    $itksnap -g org-template-stack.nii.gz -s mask.nii.gz > nul 2>&1


    echo
    while true; do
    read -p "Was the mask created correctly (i.e., could ITK-SNAP open the stack) ? [y/n]: " yn
    case $yn in
        [Yy]* )
        
            echo " ... "
        
            break;;
        [Nn]* )
            echo
            echo "Please select a different template. You can choose from stacks 0 to "${last_n}
            echo 
            read -a template_number    #read -a = read as array!

            cp stack${template_number}.nii.gz org-template-stack.nii.gz
    
            echo
            echo "Please segment the brain in ITK-SNAP using 3D brush."
            echo "The mask file will be saved as mask.nii.gz."
            
            ${path_mirtk}/mirtk convert-image org-template-stack.nii.gz mask.nii.gz -rescale 0 0 -short
            
            $itksnap -g org-template-stack.nii.gz -s mask.nii.gz > nul 2>&1
            
            break;;
        * ) echo "Please answer yes or no.";;
    esac
    done

    
    numStacks=${#all_stacks[@]}

    mkdir tmp_transfer

    echo
    while true; do
    read -p "Would you like to reconstruct using all ["${numStacks}"] of the stacks? [y/n]: " yn
    case $yn in
        [Yy]* )
        
            cp stack* tmp_transfer/
        
            break;;
        [Nn]* )
            echo
            echo "Which stacks would you like to use? You can choose from stacks 0 to "${last_n}
            echo "[Enter numbers separated by spaces, e.g: 0 1 4 6]:"
            echo 
            read -a newStackArray    #read -a = read as array!
             
            echo
            echo "You chose to reconstruct using stacks: "${newStackArray[@]}
            echo
            
            ### Update arrStackNames, Packages and Slice Thicknesses
            unset arrStackNames
            unset numStacks
            
            numStacks=${#newStackArray[@]}
            for i in $(seq 0 $numStacks); do
                cp stack${newStackArray[i]}.nii.gz tmp_transfer/
            done
            
            break;;
        * ) echo "Please answer yes or no.";;
    esac
    done
    
    
    echo
    echo "######################################################################"
    echo "Running reconstruction ..." 
    echo

    # path_autoSVRrecon_input=$path_fetalrep/pride-auto-recon-files/manual_svr
    # path_autoSVRrecon_output=$path_fetalrep/pride-auto-recon-files/results-manual_svr
    path_autoSVRrecon_input=$path_fetalrep/pride-auto-recon-files/brain_manual
    path_autoSVRrecon_output=$path_fetalrep/pride-auto-recon-files/results-brain_manual
    path_autoSVRrecon_patientFolder=$path_autoSVRrecon_input/$dayFolder"_"$patientFolder

    mkdir $path_autoSVRrecon_patientFolder
    cp $path_fetalrep/$dayFolder/$patientFolder/tmp_transfer/stack*.nii.gz $path_autoSVRrecon_patientFolder
    cp $path_fetalrep/$dayFolder/$patientFolder/mask.nii.gz $path_autoSVRrecon_patientFolder
    cp $path_fetalrep/$dayFolder/$patientFolder/org-template-stack.nii.gz $path_autoSVRrecon_patientFolder

    rm -r tmp_transfer

    svrOutputFile=$path_autoSVRrecon_output/$dayFolder"_"$patientFolder-SVR-output.nii.gz


    chmod -R 1777 $path_fetalrep/$dayFolder/$patientFolder
    chmod -R 1777 $path_autoSVRrecon_patientFolder

    ### while loop - Wait for reconstruction to complete
    isReconstructed=false
    while ! $isReconstructed; do

        echo "... still running ..."

        # Detect output SVR file / if found, exit while loop
        if [ -f "$svrOutputFile" ]; then
            echo
            echo "SVR File Found! Copying to patient directory..."
            echo
            isReconstructed=true
            rm -r $path_autoSVRrecon_patientFolder
            rm $path_fetalrep/$dayFolder/$patientFolder/*nii*
        fi
                
        sleep 60
        
    done

    ### Copy / clean up
    cp $path_autoSVRrecon_output/$dayFolder"_"$patientFolder-SVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder
    mv $path_fetalrep/$dayFolder/$patientFolder/$dayFolder"_"$patientFolder-SVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder/outputSVRvolume.nii.gz
    #rm -r $path_autoSVRrecon_patientFolder


    echo "######################################################################"
    echo "RECONSTRUCTION FINISHED "
    echo "Data saved to: "
    echo $path_fetalrep/$dayFolder/$patientFolder
    echo "######################################################################"

    $itksnap $path_fetalrep/$dayFolder/$patientFolder/outputSVRvolume.nii.gz > nul 2>&1 

    chmod 1777 $path_fetalrep/$dayFolder/$patientFolder/*

    exit 

fi



#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### Run auto body recon 
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------


if [[ $recon_type -eq 3 ]];then

	echo
	echo "######################################################################"
	echo "Running automatic T2w BODY DSVR ..."
	echo "######################################################################"
	echo

	path_autoDSVRrecon_input=$path_fetalrep/pride-auto-recon-files/body_15t
	path_autoDSVRrecon_output=$path_fetalrep/pride-auto-recon-files/results-body_15t
	path_autoDSVRrecon_patientFolder=$path_autoDSVRrecon_input/$dayFolder"_"$patientFolder

	mkdir $path_autoDSVRrecon_patientFolder
	cp $path_fetalrep/$dayFolder/$patientFolder/stack*.nii.gz $path_autoDSVRrecon_patientFolder

	svrOutputFile=$path_autoDSVRrecon_output/$dayFolder"_"$patientFolder-DSVR-output.nii.gz

    chmod -R 1777 $path_fetalrep/$dayFolder/$patientFolder
    chmod -R 1777 $path_autoDSVRrecon_patientFolder

	### while loop - Wait for reconstruction to complete
	isReconstructed=false
	while ! $isReconstructed; do

		echo "... still running ..."	

		# Detect output SVR file / if found, exit while loop
		if [ -f "$svrOutputFile" ]; then
			echo
			echo "DSVR File Found! Copying to patient directory..."
			echo
			isReconstructed=true
            rm -r $path_autoDSVRrecon_patientFolder
            rm $path_fetalrep/$dayFolder/$patientFolder/*nii*
		fi
				
		sleep 60	
		
	done

	### Copy / clean up
	cp $path_autoDSVRrecon_output/$dayFolder"_"$patientFolder-DSVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder
	mv $path_fetalrep/$dayFolder/$patientFolder/$dayFolder"_"$patientFolder-DSVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder/outputDSVRvolume.nii.gz
	#rm -r $path_autoSVRrecon_patientFolder


	echo "######################################################################"
	echo "RECONSTRUCTION FINISHED "
	echo "Data saved to: "
	echo $path_fetalrep/$dayFolder/$patientFolder
	echo "######################################################################"


    $itksnap $path_fetalrep/$dayFolder/$patientFolder/outputDSVRvolume.nii.gz > nul 2>&1

    chmod 1777 $path_fetalrep/$dayFolder/$patientFolder/*

    exit 

fi


if [[ $recon_type -eq 7 ]];then

	echo
	echo "######################################################################"
	echo "Running automatic T2w BODY DSVR FOR 0.55T ..."
	echo "######################################################################"
	echo

	path_autoDSVRrecon_input=$path_fetalrep/pride-auto-recon-files/body_05t
	path_autoDSVRrecon_output=$path_fetalrep/pride-auto-recon-files/results-body_05t
	path_autoDSVRrecon_patientFolder=$path_autoDSVRrecon_input/$dayFolder"_"$patientFolder

	mkdir $path_autoDSVRrecon_patientFolder
	cp $path_fetalrep/$dayFolder/$patientFolder/stack*.nii.gz $path_autoDSVRrecon_patientFolder

	svrOutputFile=$path_autoDSVRrecon_output/$dayFolder"_"$patientFolder-DSVR-output.nii.gz

    chmod -R 1777 $path_fetalrep/$dayFolder/$patientFolder
    chmod -R 1777 $path_autoDSVRrecon_patientFolder

	### while loop - Wait for reconstruction to complete
	isReconstructed=false
	while ! $isReconstructed; do

		echo "... still running ..."	

		# Detect output SVR file / if found, exit while loop
		if [ -f "$svrOutputFile" ]; then
			echo
			echo "DSVR File Found! Copying to patient directory..."
			echo
			isReconstructed=true
            rm -r $path_autoDSVRrecon_patientFolder
            rm $path_fetalrep/$dayFolder/$patientFolder/*nii*
		fi
				
		sleep 60	
		
	done

	### Copy / clean up
	cp $path_autoDSVRrecon_output/$dayFolder"_"$patientFolder-DSVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder
	mv $path_fetalrep/$dayFolder/$patientFolder/$dayFolder"_"$patientFolder-DSVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder/outputDSVRvolume.nii.gz
	#rm -r $path_autoSVRrecon_patientFolder


	echo "######################################################################"
	echo "RECONSTRUCTION FINISHED "
	echo "Data saved to: "
	echo $path_fetalrep/$dayFolder/$patientFolder
	echo "######################################################################"


    $itksnap $path_fetalrep/$dayFolder/$patientFolder/outputDSVRvolume.nii.gz > nul 2>&1

    chmod 1777 $path_fetalrep/$dayFolder/$patientFolder/*

    exit 

fi

#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### Run manual body recon 
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------

if [[ $recon_type -eq 4 ]];then

    echo
    echo "######################################################################"
    echo "Running manual BODY SVR ..."
    echo "######################################################################"
    echo
    echo "... please wait ..."
 
    cd $path_fetalrep/$dayFolder/$patientFolder

    stack_names=$(ls stack*.nii.gz)
    IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"

    # ${path_mirtk}/mirtk average-images tmp-space.nii.gz stack*


    echo
    echo "There are " ${#all_stacks[@]} "stacks."
    echo
    echo "Please inspect stacks one by one and select the template for masking."
    echo
    echo "(note: the stack should be represent the average position"
    echo " of the body and be less motion-corrupted)"
    echo
    

    for ((i=0;i<${#all_stacks[@]};i++));
    do
        echo " - " ${all_stacks[i]}
        ${itksnap} ${all_stacks[i]} > nul 2>&1
        # ${path_mirtk}/mirtk transform-image ${all_stacks[i]} tmp-st${j}.nii.gz -target  tmp-space.nii.gz -interp Linear
    done
    
    last_n=$((${#all_stacks[@]}-1))
    numStacks=${#all_stacks[@]}


    echo 
    echo "Please enter the selected template stack number ( from 0 to" ${last_n} " ):"
    echo
    
    read template_number
    
    cp stack${template_number}.nii.gz org-template-stack.nii.gz
    
    echo
    echo "Please segment the trunk in ITK-SNAP using 3D brush."
    echo "The mask file will be saved as mask.nii.gz."
    
    ${path_mirtk}/mirtk convert-image org-template-stack.nii.gz mask.nii.gz -rescale 0 0 -short
    
    $itksnap -g org-template-stack.nii.gz -s mask.nii.gz > nul 2>&1


    echo
    while true; do
    read -p "Was the mask created correctly (i.e., could ITK-SNAP open the stack) ? [y/n]: " yn
    case $yn in
        [Yy]* )
        
            echo " ... "
        
            break;;
        [Nn]* )
            echo
            echo "Please select a different template. You can choose from stacks 0 to "${last_n}
            echo 
            read -a template_number    #read -a = read as array!

            cp stack${template_number}.nii.gz org-template-stack.nii.gz
    
            echo
            echo "Please segment the brain in ITK-SNAP using 3D brush."
            echo "The mask file will be saved as mask.nii.gz."
            
            ${path_mirtk}/mirtk convert-image org-template-stack.nii.gz mask.nii.gz -rescale 0 0 -short
            
            $itksnap -g org-template-stack.nii.gz -s mask.nii.gz > nul 2>&1
            
            break;;
        * ) echo "Please answer yes or no.";;
    esac
    done

    
    numStacks=${#all_stacks[@]}
    
    mkdir tmp_transfer

    echo
    while true; do
    read -p "Would you like to reconstruct using all ["${numStacks}"] of the stacks? [y/n]: " yn
    case $yn in
        [Yy]* )
        
            cp stack* tmp_transfer/
        
            break;;
        [Nn]* )
            echo
            echo "Which stacks would you like to use? You can choose from stacks 0 to "${last_n}
            echo "[Enter numbers separated by spaces, e.g: 0 1 4 6]:"
            echo
            read -a newStackArray    #read -a = read as array!
             
            echo
            echo "You chose to reconstruct using stacks: "${newStackArray[@]}
            echo
            
            ### Update arrStackNames, Packages and Slice Thicknesses
            unset arrStackNames
            unset numStacks
            
            numStacks=${#newStackArray[@]}
            for i in $(seq 0 $numStacks); do
                cp stack${newStackArray[i]}.nii.gz tmp_transfer/
            done
            
            break;;
        * ) echo "Please answer yes or no.";;
    esac
    done
    
    
    echo
    echo "######################################################################"
    echo "Running reconstruction ..."
    echo

    # path_autoSVRrecon_input=$path_fetalrep/pride-auto-recon-files/manual_dsvr
    # path_autoSVRrecon_output=$path_fetalrep/pride-auto-recon-files/results-manual_dsvr
    path_autoSVRrecon_input=$path_fetalrep/pride-auto-recon-files/body_manual
    path_autoSVRrecon_output=$path_fetalrep/pride-auto-recon-files/results-body_manual
    path_autoSVRrecon_patientFolder=$path_autoSVRrecon_input/$dayFolder"_"$patientFolder

    mkdir $path_autoSVRrecon_patientFolder
    cp $path_fetalrep/$dayFolder/$patientFolder/tmp_transfer/stack*.nii.gz $path_autoSVRrecon_patientFolder
    cp $path_fetalrep/$dayFolder/$patientFolder/mask.nii.gz $path_autoSVRrecon_patientFolder
    cp $path_fetalrep/$dayFolder/$patientFolder/org-template-stack.nii.gz $path_autoSVRrecon_patientFolder
    
    rm -r tmp_transfer/

    svrOutputFile=$path_autoSVRrecon_output/$dayFolder"_"$patientFolder-DSVR-output.nii.gz

    chmod -R 1777 $path_fetalrep/$dayFolder/$patientFolder
    chmod -R 1777 $path_autoSVRrecon_patientFolder

    ### while loop - Wait for reconstruction to complete
    isReconstructed=false
    while ! $isReconstructed; do

        echo "... still running ..."

        # Detect output SVR file / if found, exit while loop
        if [ -f "$svrOutputFile" ]; then
            echo
            echo "DSVR File Found! Copying to patient directory..."
            echo
            isReconstructed=true
            rm -r $path_autoSVRrecon_patientFolder
            rm $path_fetalrep/$dayFolder/$patientFolder/*nii*
        fi
                
        sleep 60
        
    done

    ### Copy / clean up
    cp $path_autoSVRrecon_output/$dayFolder"_"$patientFolder-DSVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder
    mv $path_fetalrep/$dayFolder/$patientFolder/$dayFolder"_"$patientFolder-DSVR-output.nii.gz $path_fetalrep/$dayFolder/$patientFolder/outputDSVRvolume.nii.gz
    rm -r $path_autoDSVRrecon_patientFolder


    echo "######################################################################"
    echo "RECONSTRUCTION FINISHED "
    echo "Data saved to: "
    echo $path_fetalrep/$dayFolder/$patientFolder
    echo "######################################################################"

    $itksnap $path_fetalrep/$dayFolder/$patientFolder/outputDSVRvolume.nii.gz > nul 2>&1

    chmod 1777 $path_fetalrep/$dayFolder/$patientFolder/*

    exit 


fi



#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
### ....
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------




