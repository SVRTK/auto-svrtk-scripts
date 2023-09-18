#!/usr/bin/python


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


from __future__ import print_function
import sys
import os
import shutil
import tempfile



import matplotlib.pyplot as plt
import numpy as np
#from tqdm import tqdm
import nibabel as nib 

from monai.inferers import sliding_window_inference
from monai.transforms import (
    EnsureChannelFirst,
    Compose,
    Resize,
    ScaleIntensity,
    RandAffine,
    LoadImaged,
    Compose,
    AddChanneld,
    ToTensord,
    ScaleIntensityd,
    Resized,
)


from monai.config import print_config
from monai.networks.nets import DenseNet121

from monai.data import (
    DataLoader,
    CacheDataset,
    load_decathlon_datalist,
    decollate_batch,
)


import torch
import warnings
warnings.filterwarnings("ignore")
warnings.simplefilter("ignore")


#############################################################################################################
#############################################################################################################



files_path = sys.argv[1]
check_path = sys.argv[2]
json_file = sys.argv[3]
results_path = sys.argv[4]

#res = int(sys.argv[5])
#cl_num = int(sys.argv[6])

cl_num = 2


#############################################################################################################
#############################################################################################################


directory = os.environ.get("MONAI_DATA_DIRECTORY")
root_dir = tempfile.mkdtemp() if directory is None else directory

root_dir=files_path
os.chdir(root_dir)

run_transforms = Compose(
    [
        LoadImaged(keys=["image"]),
        AddChanneld(keys=["image"]),
        ScaleIntensityd(
            keys=["image"], minv=0.0, maxv=1.0
        ),
        Resized(keys=["image"], spatial_size=(96, 96, 96)),
        ToTensord(keys=["image"]),
    ]
)

#############################################################################################################
#############################################################################################################


datasets = files_path + json_file
run_datalist = load_decathlon_datalist(datasets, True, "running")
run_ds = CacheDataset(
    data=run_datalist, transform=run_transforms,
    cache_num=100, cache_rate=1.0, num_workers=4,
)
run_loader = DataLoader(
    run_ds, batch_size=1, shuffle=False, num_workers=4, pin_memory=True
)

#############################################################################################################
#############################################################################################################

os.environ["CUDA_DEVICE_ORDER"] = "PCI_BUS_ID"
#device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

device = torch.device('cpu')
map_location = torch.device('cpu')



model = DenseNet121(spatial_dims=3, in_channels=1, out_channels=cl_num)


#monai.networks.nets.DenseNet121 

loss_function = torch.nn.CrossEntropyLoss()
torch.backends.cudnn.benchmark = True
optimizer = torch.optim.Adam(model.parameters(), 1e-4)

#############################################################################################################
#############################################################################################################

model.load_state_dict(torch.load(os.path.join(check_path, "best_metric_model.pth"), map_location=torch.device('cpu')), strict=False)
model.to(device)

#model.eval()

for x in range(len(run_datalist)):
  # print(x)

  case_num = x
  img_name = run_datalist[case_num]["image"]
  case_name = os.path.split(run_ds[case_num]["image_meta_dict"]["filename_or_obj"])[1]

  with torch.no_grad():
      img_name = os.path.split(run_ds[case_num]["image_meta_dict"]["filename_or_obj"])[1]
      img = run_ds[case_num]["image"]
      run_inputs = torch.unsqueeze(img, 1)
      
      val_outputs = model(run_inputs)
      predicted_probabilities = torch.softmax(val_outputs, dim=1)
      class_out = torch.argmax(predicted_probabilities, dim=1)
      predicted_class = class_out.item()
      
      print(case_num, case_name, " - predicted class : ", predicted_class)

      #print(predicted_class)
      



#############################################################################################################
#############################################################################################################




#############################################################################################################
#############################################################################################################





