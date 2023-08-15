Scripts for automated SVRTK reconstruction and segmentation solutions (work in progress)
====================

This repository is used for storage of scripts for automated  processing of fetal MRI in [SVRTK dockers](https://hub.docker.com/r/fetalsvrtk/) and general processing for:
- segmentation
- SVR-based reconstruction

The scripts were installed in the corresponding docker containers together with network weights and SVRTK software. 

The trained network weights can be found in: https://gin.g-node.org/SVRTK/fetal_mri_network_weights . 

The code was created by Dr Alena Uus.    


License
-------

The SVRTK package and all scripts are distributed under the terms of the
[Apache License Version 2](http://www.apache.org/licenses/LICENSE-2.0). The license enables usage of SVRTK in both commercial and non-commercial applications, without restrictions on the licensing applied to the combined work.


Citation and acknowledgements
-----------------------------

In case you found SVRTK useful please give appropriate credit to the software ([SVRTK dockers](https://hub.docker.com/r/fetalsvrtk/)).


> Uus, A., Grigorescu, I., van Poppel, M., Steinweg, J. K., Roberts, T., Rutherford, M., Hajnal, J., Lloyd, D., Pushparajah, K. & Deprez, M. (2022) Automated 3D reconstruction of the fetal thorax in the standard atlas space from motion-corrupted MRI stacks for 21-36 weeks GA range. Medical Image Analysis, 80 (August 2022).: https://doi.org/10.1016/j.media.2022.102484

> Uus, A. U., Kyriakopoulou, V., Makropoulos, A., Fukami-Gartner, A., Cromb, D., Davidson, A., Cordero-Grande, L., Price, A. N., Grigorescu, I., Williams, L. Z. J., Robinson, E. C., Lloyd, D., Pushparajah, K., Story, L., Hutter, J., Counsell, S. J., Edwards, A. D., Rutherford, M. A., Hajnal, J. V., Deprez, M. (2023) BOUNTI: Brain vOlumetry and aUtomated parcellatioN for 3D feTal MRI. bioRxiv 2023.04.18.537347; doi: https://doi.org/10.1101/2023.04.18.537347

> Uus, A. U., Hall, M., Grigorescu, I., Avena Zampieri, C., Egloff Collado, A., Payette, K., Matthew, J., Kyriakopoulou, V., Hajnal, J. V., Hutter, J., Rutherford, M. A., Deprez, M., Story, L. (2023) Automated body organ segmentation and volumetry for 3D motion-corrected T2-weighted fetal body MRI: a pilot pipeline. medRxiv 2023.05.31.23290751; doi: https://doi.org/10.1101/2023.05.31.23290751


Disclaimer
-------

This software has been developed for research purposes only, and hence should not be used as a diagnostic tool. In no event shall the authors or distributors be liable to any direct, indirect, special, incidental, or consequential damages arising of the use of this software, its documentation, or any derivatives thereof, even if the authors have been advised of the possibility of such damage.


