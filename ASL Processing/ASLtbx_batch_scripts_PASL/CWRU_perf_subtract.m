% function [perfnum] =    CWRU_perf_subtract(Filename,FirstimageType, SubtractionType,...
%            SubtractionOrder,Flag,   ...
%            Timeshift,AslType,labeff,MagType, ...
%            Labeltime,Delaytime,Slicetime,TE,M0img,M0roi,maskimg, ...
%            M0csf, M0wm, threshold, ...
%            Foldername_TPMs, OutlierThresholds)

% original file: asl_perf_subtract.m
%   Copyright by Ze Wang
%   Ze Wang @cfn Upenn 2004
%   zewang@mail.med.upenn.edu  or  redhat_w@yahoo.com
% A MATLAB function for calculating the perfusion difference (delta M) or the quantitative perfusion value from the label/control ASL images.
% This code uses several SPM I/O functions, you may need to install SPM8, or 5 first.
% The code can be run in MATLAB(5.3 or above) with SPM99, SPM2, SPM5, or SPM8 on
% Redhat Linux 9 or Windows2K,XP.
% Note: Matlab refers to the Matlab software produced by Mathworks, Natick,
% MA; SPM(99, 2, 5, or 8) refers to the statistical parametric mapping
% software distributed by Wellcome Trust Center for Neuroimaging.
%
% Reference: Ze Wang, Geoffrey K. Aguirre, Hengyi Rao, Jiongjiong Wang,
% Maria A. Fernandez-Seara, Annasl_perf_subtracta R. Childress, and John A. Detre, Epirical
% optimization of ASL data analysis using an ASL data processing toolbox:
% ASLtbx, Magnetic Resonance Imaging, 2008, 26(2):261-9.
%
%
%
% The ASL perfusion sequences (CASL or PASL, works on Siemens Trio 3T) using EPI readout are freely avaiable for academic use, please refer to: http://cfn.upenn.edu/perfusion/sequences.htm
%
% License:
%   This file, asl_perf_subtract is the core part of the ASLtbx.
%     ASLtbx is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
%
%     ASLtbx is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
%
%     You should have received a copy of the GNU General Public License
%     along with ASLtbx.  If not, see <http://www.gnu.org/licenses/>.
%
%  This code can be freely used or changed for academic purposes. All commercial applications are not allowed without the formal
%    permission from the Center for functional neuroimaging at the University of Pennsylvania, Medicine School through the authors.
%    This file is part of the ASL toolbox, which also includes a manual and other files for ASL quality control, and will be
%    avaiable freely through cfn.upenn.edu.
%
% Subtraction methods:
%    The methods used here are based on the "simple subtraction", "surround subtraction" and "sinc subtract" approaches described in
%    Aguirre et al (2002) Experimental design and the relative sensitivity of perfusion and BOLD fMRI, NeuroImage. Later version might add other subtraction routines.
%
% CBF quantification:
% For casl, the CBF value is calculated by:
%   CBF (ml/100g/min) = 60*100*deltaM*lambda*R/(2*alpha*M0*(exp(-w*R)-exp(-(tao+w)*R))
%   where deltaM - ASL perfusion difference, lambda - blood/tissue water partition coefficient, R - longitudinal relaxation rate of blood,
%       alpha - tagging efficiency,
%       M0 - equilibrium magnetization of brain. M0 should be acquired when the spins are fully relaxed (with long TR and short TE)
%       w - post-labeling delay, w is generally assumed to be longer than the transit time from the tagging place to the arterial vascular compartment
%           to allow the delivery of all the tagged blood into the imaging slices. See Alsop and Detre, J Cereb Blood Flow Metab 1996;16:1236�C1249.
%       tao - duration of the labeling RF pulse train.
%   regular values for some parameters are lambda=0.9g/ml,
%   for 3T, alp=0.68, R=1/1664ms  was R=0.67sec-1 in Wang 03  but should be smaller than that according to the literature.
%   for 1.5T, alp=0.71, R=0.83sec-1.
%   Please refer to: Wang J, Alsop DC, et al. (2003) Arterial transit time imaging with flow encoding arterial spin tagging (FEAST).
%   Magn Reson Med. 50(3), page600, formula [1]
%     might be changed to
%   CBF (ml/100g/min) = 60*100*deltaM*lambda*R1tissue/(2*alpha*M0*(exp(-w*R1b)(1-exp(-(tao)*R1tissue)))  according to Buxton's model.
%
% For PASL,
%   CBF (ml/100g/min) = deltaM/(2*M0b*tao*exp(-T1/T1b)*qTI)
%   and M0b=Rwm*M0WM*exp((1/T2wm-1/T2b)*TE) or M0b=Rcsf*M0csf*exp((1/T2csf-1/T2b)*TE),
%   	T1 is the inversion time for different slice; T1b is the constant relaxation time of arterial blood.
%   	tao is actually TI1 in QUIPPS II
%   	qTI is close to unit, and is set to 0.85 in Warmuth 05. In addition, we
%   		introduce the label efficiency in the calculation.
%   	Rwm  - proton density ratio between blood and WM1.06 in Wong 97. 1.19 in Cavosuglu 09; T2wm and T2b are 55 msec and 100 for 1.5T, 40 80 for 3T, 30 60 for 4T;
%     Rcsf - proton density ratio between blood and csf, 0.87 in Cavosuglu, T2csf is 74.9 ms for 3T.
%   	M0WM means the mean value in an homogenous white matter region, and it could be selected by drawing an ROI in the M0 image.
%   	Please refer to: 1) Buxton et al, 1998 MRM 40:383-96, 2) Warmuth C., Gunther M. and Zimmer G. Radiology, 2003; 228:523-532.
%   	Note (Nov 19 2010): T2wm and T2b at 3T were changed to 44.7 and 43.6, T2csf if used was set to 74.9 according to Cavusoglu 09 MRI
% Concurrent pseudo-BOLD images
%      It is possible to get part of BOLD signal if the sequence is T2* weighted (like using the T2* weighted Gradient Refocused EPI sequence using a moderate TE >10msec).
%      		the pseudo-BOLD images can be extracted using: 1) take the average of each control/label pair, 2) just take the control image of each pair. You can
%      		do this by commenting out the corresponding line in lines 557/558 (line number might be changed due to code update). e.g., comment out BOLDimg=(Vconimg+Vlabimg)/2.; and enable BOLDimg=Vconimg;
%      		will enable the 2nd option. If you want to get the full resolution, you can simply project the zigzagged spin labeling pattern out.
%         Assuming labeling is played first and followed by control labeling, the asl pattern can be defined as x=[-0.5 0.5 -0.5 0.5 ...],
%         y is M by T (M is number of voxels, T is number of ASL images), then the perfusion signal removed BOLD data can be got by y'-x'*(x'\y') in matlab.
% Usages:
%    If you are using ASL sequences from Dr. John A Detre's lab, you can
%    follow the default setting in the GUI.
% Arguments:
%     Both 3D and 4D NIfTI format and 3D Analyze images are supported now.
%     FirstimageType - integer variable indicats the type of first image.
%        - 0:label; 1:control; for the sequence (PASL and CASL) distributed by CFN, the first image is set to be label.
%     Select raw images (*.img, images in a order of control1.img, label1.img, control2.img, label2.img,....;
%        or images in an order of label1.img, control1.img, label2.img, control2.img, .... or images in nifti format or in 4D format )
%    SubtractionType - integer variable indicats which subtraction method will be used
%        -0: simple subtraction; 1: surround subtraction; 2: sinc subtractioin.
%           For control-label:
%              if the raw images are: (C1, L1, C2, L2, C3...), the simple subtraction are: (C1-L1, C2-L2...)
%                 the surround subtraction is: ((C1+C2)/2-L1, (C2+C3)/2-L2,...), the sinc subtraction is: (C3/2-L1, C5/2-L2...)
%              if the raw images are: (L1, C1, L2, C2...), the simple subtraction are: (C1-L1, C2-L2...)
%                 the surround subtraction will be: (C1-(L1+L2)/2, C2-(L2+L3)/2,...), the sinc subtraction will be: (C1-L3/2, C2-L5/2...)
%           and vice versa for label-control
%    SubtractionOrder - integer value indicats the subtraction orientation
%           1: control-label; 0: label-control
%    Note: a gold stand to get the correct subtraction order is to check the CBF value in grey matter. If most grey matter voxels have negative
%          CBF values, you should switch to the other subtraction order. Usually, for CASL, you should choose control-label, and for the FAIR based PASL data,
%            you should select  label - control
%          When background suppression is applied, the subtraction order may need to be flipped also. Like CASL
%          with background suppression, the subtraction should be label-control.
%
%    Flag - flag vector composed of [MaskFlag,MeanFlag,CBFFlag,BOLDFlag,OutPerfFlag,OutCBFFlag,QuantFlag,ImgFormatFlag,D4Flag,M0wmcsfFlag]
%          MaskFlag - integer variable indicating whether perfusion images are
%               masked by BOLD image series, usually, it's masked to remove the
%               background noise and those non-perfusion regions.
%               - 0:no mask; 1:masked
%
%          MeanFlag - integer variable indicating whether mean image of all perfusion images are produced
%               - 0:no mean image; 1: produced mean image
%          CBFFlag - indicator for calculating cbf. 1: calculated, 0: no
%          BOLDFlag - generate pseudo BOLD images from the tag-utag pairs.
%
%
%          OutPerfFlag: write perf signal to disk or not? 1 yes, 0:no
%          OutCBFFlag: write CBF signal to disk or not?
%          QuantFlag: using a unique M0 value for the whole brain? 1:yes, 0:no.
%          ImgFormatFlag: 0 (default) means saving images in Analyze format, 1 means using NIFTI
%          D4Flag       : 0 (default) - no, 1 - yes
%          M0wmcsfFlag: 1 - using M0csf to estimate M0b, 0 - using M0wm to estimate M0b, -1 - disabled
%          OutliersNANFlag : 1 - set outlier to NaN in the CBF 4D images
%          DumpCBF_DataFlag: 1 - save all CBF data (for each perfusion
%                           image pair) to text file 'CBF_Data.xlsx'
%          ExcludeOutliersEachPerfusion: 1 - (as implemented in original code) outliers are
%                    eliminated in EACH perfusion image pair; 0 - outliers are eliminated from the
%                    final averaged CBF map
%          OutlierThresholds_IsFixedValues: if 0, the OutlierThresholds represent the number of
%                     sigmas away from mean to exclude; if 1, the OutlierThresholds represent fixed 
%                     thresholds of CBF to exclude
%
%    labeff  -  labeling efficiency, 0.95 for PASL, 0.68 for CASL, 0.85 for pCASL, this should be measured for onsite scanner.
%    MagType - indicator for magnet field strength, 1 for 3T, 0 for 1.5T,
%    Timeshift - only valid for sinc interpolation, it's a value between
%    0 and 1 to shift the labeled image forward or backward.
%
%    AslType - 0 means PASL, 1 means CASL
%    Labeltime-time for labelling arterial spins. (sec)
%              for PASL, this parameter is used to passing TI1 (in sec)
%    Delaytime - delay time for labeled spin to enter the imaging slice,
%               this argument should be set to TI2 in QUIPSS. In Siemens PICORE sequence, TI1/TI2 can be found by the "inversion time 1" and "inversion time 2"
%    Slicetime - 2D: time for getting one slice, which can calculated by #phase encoding lines*echo spacing time [+ fat saturation time and crusher time+ slice selection gradient time + phase refocusing gradient time]
%               #number of phase encoding lines usually is the same as the image dimension along y since phase encoding is
%               generally applied along y direction in 2D imaging. For 64x64 imaging matrix, it is 64. The easiest way to get slicetime is:
%               get the minimal TR by clicking the "TR" window in the protocol panel, then slicetime=(minTR-labelingtime-delaytime)/#slices.
%               For Siemens 3T Trio Tim, 64 x 64 with an echo spacing of 0.49ms will cause a slicetime of 50.5 ms if regular fatsat is toggle on and the minimum TE is used
%                   if echo spacing is reduced to be 0.38 and TE is 16ms, the slice time will be 43, using partial Fourier or parallel imaging will reduce slice time as well.
%                3D: should be set to 0.
%    M0img - M0 image acquired with short TE long TR.
%    M0roi - segmented white matter M0 image needed for automatically
%           calculating the PASL cbf images.
%    maskimg - a predefined mask image, for background suppression data, please specify a mask or 
%              change the corresponding threshold in the code.
%    M0csf   - mean CSF signal from the M0 image. Once this value is provided, the quantification will be automatically switched to be the "unique M0 for the whole brain" mode.
%    M0wm  -
%    threshold -
%    Foldername_TPMs
%    OutlierThresholds: 2-element vector describing lower and upper thresholds for oulier exclusion.
%                    Interpretation is either fixed values, or sigmas from the mean, depending on
%                    flag OutlierThresholds_IsFixedValues.  For example to exclude +/- 2 sigmas from
%                    the mean, set flag OutlierThresholds_IsFixedValues=0, and set OutlierThresholds
%                    to [-2 2]

%  Outputs:
%     perfnum: perfusion image number.
%     Images written to the disk: Perfusion images, BOLD images, and CBF
%     images (if the flags are turned on correspondingly).
%     global perfusion difference signals and CBF values will be saved to a txt file.
%
%  Example:
%    With user interface to select the input parameters:
%           asl_perf_subtract
%   Batch mode for PASL CBF calculation:
%           FirstimageType: label first, SubtractionType: 0 (simple subtraction)
%           SubtractionOrder: 1 (control-label),
%           Flag: [1 1 1 0 0 1 1 1]: [removing out-of-brain voxels, generating mean images, calculating qCBF, not saving pseudo bold,
%                   not saving perf diff images, save qCBF series, using unique M0 for all voxels, saving results in NIFTI format, saving image series in 4D, using M0csf to estimate M0b],
%                  Timeshift=0.5 (used in sinc subtraction), AslType: 0 (PASL), labeff:0.9, MagType: 1 (3T),
%                  Labeltime:2 (idle for PASL), Delaytime: 0.8 sec, Slicetime: 45 msec, TE: 20 msec,M0img,M0roi,maskimg
%                  M0csf will be taken from mean M0 signal (defined by M0img) within the ROI defined by M0roi.
%           asl_perf_subtract(Filename,0, 0, 1, [1 1 1 0 0 1 1 1 1 1], ...
%                             0.5, 0, 0.9, 1, 2, 0.8, 45, 20, M0img, M0roi, maskimg);
%   Ze Wang @cfn Upenn 2004
%   zewang@mail.med.upenn.edu  or  redhat_w@yahoo.com
%   History:
%   Modified: 11-08-2004
%   Modified: 04-12-05. Changed the perfusion image and CBF image
%   generating part to remove outliers.
%   Modified 10-04-05. Improved the cbf calculation part to be faster, using 6 point sinc interpolation.
%                   10-19-05. Modified the outlier mask for global time seriese calculation. Improved sinc
%                   interpolation.
%   Modified 10-22-05. Absolute threshold is used for local outlier cleaning.
%   11-16-2005 A bug fixed by Robert Kraft for displaying nonsquare image for M0 calculation in the PASL part.
%   11-30-2005 parameters adjusted for calculating CBF for PASL data.
%   07-20-2006 outlier threshold was adjusted to -40~150, this is an empirical range for removing within volume outliers.
%   04-20-2007 parameters were named consistently for CASL and PASL, and
%   code was tested in SPM5.
%   07-08-2008 added an option (Flag(7)) for CBF calibration using M0 from each
%   voxel. This will be particularly useful for ASL with array coil.
%   08-11-2008 supported 4D I/O. Only tested with spm5.
%   19-Nov-2010 update T1 T2 of blood and tissue according to the literature. Corrected the quantification method for using voxel-wise M0.
%               for using single M0, the water/tissue ratio was also changed according to the literature. Descriptions for PASL
%               quantification were updated, more details provided for using q, lambda etc
%               Adapted some changes made by Michael Harms.
%   May 2 2012 documentation has been partly updated.
%   July 18 2012 code modified to allow: 1) choose either using M0wm or
%   M0csf to estimate M0b, 2) directly input M0i value.
%   Aug 13 2013. Now use Labeltime to pass TI1 in PASL. Delay time fed to the code should be TI2 in PASL
%   Aug 23 2013. Replaced fileparts with spm_fileparts per Chris Roden's suggestion.

%  07 Oct 2017  TF: changed the way that the perfusion data is reported
%               (now as a table, with headers, and more data columns).
%               Found an error in the way in which the mean CBF was being
%               computed and reported, affecting the outlier-cleaned data.
%               Fixed that error.  
%  08 Oct 2017 TF: addded two new flag options:
%    OutliersNANFlag=Flag(11): if 1, will set the outlier values to NaN in the 4D CBF images 
%    DumpCBF_DataFlag=Flag(12): if 1, will save a file with name like
%    "CBF_Data_0.xlsx", with the CBF values per voxel for each perfusion
%    pair (all voxels in the brain mask, outliers not excluded)
%  09 Oct 2017 TF: now has the option to use TPM maps to segment the CBF into grey matter, white
%              matter, and CSF.  User must pass in the path to folder containing TPM maps; filenames
%              are expected to be like 'c1*.nii', 'c2*.nii', etc.
% 10 Oct 2017: implemented ability to exclude outliers at the overall average CBF, or the individual
%           perfusion image pair.  Also implemented dynamic or fixed-value outlier thresholds.

function [perfnum,glcbf] = ...
   CWRU_perf_subtract(Filename,FirstimageType, SubtractionType,...
           SubtractionOrder,Flag,   ...
           Timeshift,AslType,labeff,MagType, ...
           Labeltime,Delaytime,Slicetime,TE,M0img,M0roi,maskimg, ...
           M0csf, M0wm, threshold, ...
           Foldername_TPMs, OutlierThresholds, ...
           PrecomputedCBFImage, PrecomputedCBF_Scaling)
        
% close all;

global fidLog;

tabResults= table;

if (fidLog<=0)
   fidLog=1; %by default, output to screen
end

spmver = spm('ver',[],1);
modernSPM = any(strcmp(spmver,{'SPM5','SPM8','SPM12b', 'SPM12', 'SPM16'}));
% Define some constants
BPTransTime=200;          % Blood pool transit time
TissueTransTime=1500;     % Tissue transit time
MinGrayT1=900;            % Min T1 of gray matter in ms
MaxGrayT1=1600;           % Max T1 of gray matter in ms
MinWhiteT1=300;           % Min T1 of wht matter in ms
MaxWhiteT1=900;           % Max T1 of wht matter in ms
TI1=700;                  % Tagging bolus duration in ms, for the QUIPSS II. This is the default value, but you can use Labeltime to input a specific value, see line 649
qTI=0.85;
% lambda=0.9*100*60;
%r1a=1/1493; %0.67 per sec %1/BloodT1 depends on field

Rwm=1.19;     %1.06 in Wong 97. 1.19 in Cavosuglu 09, Proton density ratio between blood and WM;
% needed only for AslType=0 (PASL) with QuantFlag=1 (unique M0 based quantification)
Rcsf=0.87;    % both Rwm and Rcsf are for 3T only, you need to change them for other field strength.
lambda=0.9; %*100*60;   %0.9 mL/g
M0b=0;  %computed below, if needed

UsePrecomputedCBF = false;
if exist('PrecomputedCBFImage','var')  && ~isempty(PrecomputedCBFImage) 
   UsePrecomputedCBF=true;
end


DoTPMSegmentedSummarization = false;
TPM_count = 0;
TPM_Threshold = 0.75;  %originally was 0.5

if exist('Foldername_TPMs','var')  && ~isempty(Foldername_TPMs) 
   V_TPMs_unordered = spm_vol(spm_select('FPList', Foldername_TPMs, '^c\ds_mprage\.nii$'));
   % there is no guarantee that the filenames will be in the expected order 'c1..', 'c2..', so go
   % through the array and force them into expected order, ensuring elements 1..N are files c1...cN
   TPM_count = 0;
   for i=1:length(V_TPMs_unordered)
      for j=1:length(V_TPMs_unordered)
         [pth,nam,ext,num] = spm_fileparts(V_TPMs_unordered(j).fname); %#ok<*ASGLU>
         tpm_index = regexp([nam ext], '^c(\d).*\.nii$','tokens');
         if ~isempty( tpm_index)
            if str2num(tpm_index{1}{1}) == i 
               V_TPMs(i) = V_TPMs_unordered(j);
               TPM_count= TPM_count+1;
               break;
            end
         end
      end
   end
   
   if (TPM_count== length(V_TPMs_unordered)) 
      DoTPMSegmentedSummarization = true;
      clear V_TPMs_unordered
   %   TPM_All = spm_read_vols(V_TPMs);
   else
      error('Failed to find expected TPM filenames');
   end
end

% relthresh=0.12;           % Relative threshold for creating the mask.
if ~exist('threshold','var') || isempty(threshold)
   relthresh=0.05;
else
   relthresh=threshold;
end

if ~exist('Filename','var') || isempty(Filename)   
   if modernSPM
      Filename=spm_select(Inf,'image','Select ASL images',[],pwd,'.nii',1:1000);
   else
      Filename = spm_get(Inf,'*.img','Select ASL imgs');
   end
end

if isempty(Filename)
   if modernSPM
      Filename=spm_select(Inf,'image','Select ASL images',[],pwd,'.nii',1:1000);
   else
      Filename = spm_get(Inf,'*.img','Select ASL imgs');
   end
end
if isempty(Filename), fprintf(fidLog, 'No images selected!\n');return;end;
pos=1;

if ~exist('FirstimageType','var') || isempty(FirstimageType)   
   FirstimageType = spm_input('1st image type, 0:label; 1:control', pos, 'e', 0);
end

if ~exist('SubtractionType','var') || isempty(SubtractionType)   
   pos=pos+1;
   SubtractionType = spm_input('Select subtraction method', pos, 'm',...
      '*simple subtraction|surround subtraction|sinc subtraction',...
      [0 1 2], 0);
end

if SubtractionType==2
   if ~exist('Timeshift','var') || isempty(Timeshift)   
      %if nargin<6
      pos=pos+1;
      Timeshift = spm_input('Time shift for sinc interpolation', pos, 'e', 0.5);
   end
   %if FirstimageType==0 Timeshift=-1*Timeshift; end;
end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Note here, the sinc subtraction is C1-L1/2 or L1/2 -C1, but when the raw image sequence is L1 C1, L2 C2,... the
%% L1/2 should be between L1 and L2, otherwise, it should be between 0 and
%% L1.
%if nargin<4
if ~exist('SubtractionOrder','var') || isempty(SubtractionOrder)   
   pos=pos+1;
   SubtractionOrder = spm_input('Select subtraction order', pos, 'm',...
      'label-control|control-label',...
      [0 1], 2);
end

if exist('Flag','var') && ~isempty(Flag)   
   MaskFlag=Flag(1);
   MeanFlag=1;
   BOLDFlag=0; CBFFlag=1;
   OutPerfFlag=0;OutCBFFlag=1;
   QuantFlag=1;  % (default) using a unique M0 value from a ROI for all voxels;
   ImgFormatFlag=0;   % (default) save images in Analyze format
   D4Flag=0;          % this is to be compatible with old scripts
   M0wmcsfFlag =  1;  % choose either M0csf (1) or M0wm (0) for calibration, -1 means disabled.
   OutliersNANFlag = 0;
   DumpCBF_DataFlag = 0;
   ExcludeOutliersEachPerfusion = 0;
   OutlierThresholds_IsFixedValues = 0;
   
   if length(Flag)>1,  MeanFlag=Flag(2);end
   if length(Flag)>2,  CBFFlag=Flag(3); end
   if length(Flag)>3,  BOLDFlag=Flag(4);end
   if length(Flag)>4,  OutPerfFlag=Flag(5);end
   if length(Flag)>5,  OutCBFFlag=Flag(6)*CBFFlag; end
   if length(Flag)>6,  QuantFlag=Flag(7);end
   if length(Flag)>7,  ImgFormatFlag=Flag(8);end
   if length(Flag)>8,  D4Flag=Flag(9); end
   if length(Flag)>9,  M0wmcsfFlag=Flag(10); end
   if length(Flag)>10,  OutliersNANFlag=Flag(11); end      
   if length(Flag)>11,  DumpCBF_DataFlag=Flag(12); end   
   if length(Flag)>12,  ExcludeOutliersEachPerfusion=Flag(13); end   
   if length(Flag)>13,  OutlierThresholds_IsFixedValues=Flag(14); end   
else
   pos=pos+1;
   MaskFlag = spm_input('Applying mask for output? 0:no; 1:yes', pos, 'e', 1);
   pos=pos+1;
   MeanFlag = spm_input('Create mean images? 0:no; 1:yes', pos, 'e', 1);
   pos=pos+1;
   CBFFlag = spm_input('Calculate qCBF? 0:no; 1:yes', pos, 'e', 1);
   pos=pos+1;
   BOLDFlag = spm_input('Output pseudo BOLD imgs? 0:no; 1:yes', pos, 'e', 0);
   pos=pos+1;
   OutPerfFlag = spm_input('Save delta M imgs? 0:no; 1:yes', pos, 'e', 0);
   pos=pos+1;
   if CBFFlag
      OutCBFFlag = spm_input('Save qCBF imgs? 0:no; 1:yes', pos, 'e', 1);
      pos=pos+1;
      QuantFlag     = spm_input('Using a unique M0 value for all voxels? 0:no; 1:yes', pos, 'e', 1);
      if QuantFlag ==1
         pos=pos+1;
         M0wmcsfFlag = spm_input('Which M0? 0:M0wm; 1:M0csf', pos, 'e', 1);
      else
         M0wmcsfFlag = -1;
      end
   else
      OutCBFFlag =0;
   end
   pos=pos+1;
   ImgFormatFlag=spm_input('Output image format? 0:Analyze; 1:Nifti', pos, 'e', 1);
   pos=pos+1;
   D4Flag=spm_input('saving 4D image series? 0:no; 1:yes', pos, 'e', 1);
   pos=pos+1;
   OutliersNANFlag=spm_input('Set outliers to NaN in qCBF images? 0:no; 1:yes', pos, 'e', 0);
   pos=pos+1;
   DumpCBF_DataFlag=spm_input('Dump all CBF data into an Excel file? 0:no; 1:yes', pos, 'e', 0);
end

if ~modernSPM, ImgFormatFlag=0; end
if ImgFormatFlag, imgaffix='.nii';
else imgaffix='.img'; end


if ~exist('OutlierThresholds','var') || isempty(OutlierThresholds)   
   if OutlierThresholds_IsFixedValues
      OutlierThresholds = [-40 150]; %these were original values in ASLtbx code
   else
      OutlierThresholds = [-2 2];   % plus/minus 2 sigmas
   end
end


if ~exist('AslType','var') || isempty(AslType)   
   pos=pos+1;
   AslType = spm_input('Select ASL Type:0 for PASL,1 for CASL', pos, 'e', 1);
end

if (DoTPMSegmentedSummarization && ~OutCBFFlag)
   error('To perform segmented summarization, you must also specify the OutCBFFlag=1');
end

if CBFFlag==1
   %T2wm and T2b are 55 msec and 100 for 1.5T, 40 80 for 3T, 30 60 for 4T;
   if nargin<9
      pos=pos+1;
      MagType = spm_input('Magnetic field:0 for 1.5T,1 for 3T, 2 for 4T', pos, 'e', 1);
   end
   
   if nargin<10
      if AslType==1   % labeling time is only required for CASL or pCASL
         pos=pos+1;
         Labeltime = spm_input('Label time:sec', pos, 'e', 2);
      else
         Labeltime=0.001;
      end
   end
   Labeltime=Labeltime*1000;
   
   if nargin<11
      pos=pos+1;
      Delaytime = spm_input('Post-labeling delay:sec', pos, 'e', 0.8);
      
   end
   Delaytime=Delaytime*1000;
   if nargin<12
      pos=pos+1;
      Slicetime = spm_input('Slice acquisition time:msec', pos, 'e', 45);
   end
   if MagType==0  %1.5 T
      T2wm=55;
      T2b=100;
      BloodT1=1200;
   elseif MagType==1   % 3T
      T2wm=44.7;   % used to be 40;
      T2b=43.6;    % used to be 80;
      T2csf=74.9;
      BloodT1=1664;    % was 1490 in Wang 03;
      % these changes were made according to Lu 04 and Cavusoglu 09 MRI
   else
      T2wm=30;
      T2b=60;
      BloodT1=1810;  % You may need to update this value from the literature.
   end;
   if QuantFlag==1, useM0=1;      % CASLUSEM0VAL PASLUSEM0VAL
   else  % mapwise M0 or M0ctr calibration
      if exist('M0img','var')==0   % M0 image has not been provided
         pos=pos+1;
         useM0= spm_input('Use an additionally acquired M0 rather than M0ctr for CASL?', pos, 'm', 'yes|*no', [1 0], 0);     % CASLUSEM0  PASLUSEM0
      else  % M0img has been defined in batch mode
         if isempty(M0img), useM0=0;
         else
            useM0=1;
         end
      end
   end
   
   % useM0 defined above only tells whether a separate M0 value or M0 image will be used. M0 image or M0 value could be not defined thus far (like in the GUI mode).
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   % get M0img or M0 value if needed but not defined.
   if QuantFlag ==1  % useM0 has to be 1 (see lines 367 PASLUSEM0 and 376 CASLUSEM0VAL). need explicitly input unique M0 value or implicitly defined M0 value using M0image and M0roi
      if ~exist('TE','var') || isempty(TE)  
         pos=pos+1;
         TE=spm_input('TE for M0 acquisition:msec', pos, 'e', 20);
      end
      pos=pos+1;
      if (exist('M0img','var')==0) && (exist('M0wm','var')==0) && (exist('M0csf','var')==0)   % for the GUI mode
         uic = spm_input('Select an M0 image or input an M0 value?', pos, 'm', 'M0 image|*M0 value',  [1 0], 0);
         if uic == 1     % need an M0 image
            if modernSPM
               M0img = spm_select(1,'image','Select M0 image','',pwd,'.img$');
               %M0roi = spm_select(1,'image','Select a WM or CSF ROI image file','',pwd,'.seg.img$');
            else
               M0img = spm_get(1,'*.img','Select M0 image');
               %M0roi = spm_get(1,'*.img','Select a WM or CSF ROI image file');
            end
         else               % need an M0 value
            if M0wmcsfFlag == 0       % M0wm
               M0wm=-20; % M0wm and M0csf have not been defined
               while M0wm<=0
                  fprintf(fidLog, 'Please give a greater than 0 M0wm number!\n');
                  M0wm=spm_input('M0wm', pos, 'e', 1000);
               end
            elseif M0wmcsfFlag==1     % M0csf
               M0csf=-20;
               while M0csf<=0
                  fprintf(fidLog, 'Please give a greater than 0 M0csf number!\n');
                  M0csf=spm_input('M0csf', pos, 'e', 2000);
               end
            end
            M0img='';
         end                % end if uic==1
      else  % if M0img exists but M0 value is provided too, M0img will be set to []. The latter (M0 value) has higher priority.
         if M0wmcsfFlag == 1 && exist('M0csf','var')
            if isempty(M0csf)
               if ~exist(M0img,'file')     % you need to provide M0
                  if modernSPM
                     M0img = spm_select(1,'image','Select M0 image','',pwd,'.img$');
                  else
                     M0img = spm_get(1,'*.img','Select M0 image');
                  end
               end
            else
               if M0csf<=0
                  fprintf(fidLog, 'M0csf is %f, please give a greater than 0 number!\n', M0csf);
                  while M0csf<=0
                     M0csf=spm_input('M0csf', pos, 'e', 1000);
                  end
               end
               M0img='';
            end
         elseif M0wmcsfFlag==0 && exist('M0wm','var')
            if isempty(M0wm)
               if ~exist(M0img,'file')     % you need to provide M0
                  if modernSPM
                     M0img = spm_select(1,'image','Select M0 image','',pwd,'.img$');
                  else
                     M0img = spm_get(1,'*.img','Select M0 image');
                  end
               end
            else
               if M0wm<=0
                  fprintf(fidLog, 'M0wm is %f, please give a greater than 0 number!\n', M0wm);
                  while M0wm<=0
                     M0wm=spm_input('M0wm', pos, 'e', 1000);
                  end
               end
               M0img='';
            end
         else
            if ~exist(M0img,'file')     % QuantFlag is set to be 1 (using unique M0b) but no M0i (M0wm or M0csf) value is provided, then M0img is mandatory
               if modernSPM
                  M0img = spm_select(1,'image','Select M0 image','',pwd,'.img$');
               else
                  M0img = spm_get(1,'*.img','Select M0 image');
               end
            end
         end   % END if M0wmcsfFlag == 1 && exist('M0csf','var')
      end   % if (exist('M0img','var')==0)&&(exist('M0wm','var')==0) && (exist('M0csf','var')==0)
   else      % else if QuantFlag == 0, meaning a mapwise M0 calibration, an M0 image should be provided if useM0==1
      if useM0   % we need an M0 image when ASLtype==0 (PASL) or additional M0 for CASL option is selected (line 380, marked with CASLUSEM0)
         % first M0img might not be defined as in the GUI mode.
         M0ing_first = '';
         if exist('M0img','var')
            [pth,nam,ext,num] = spm_fileparts(M0img);  %to allow use of the 'exist' function, remove the trailing ",1"
            M0ing_first = fullfile(pth,[nam ext]);
         end
         if  exist('M0img','var')==0  || ~exist(M0ing_first,'file')   % you need to provide an M0 image
            if modernSPM
               M0img = spm_select(1,'image','Select M0 image','',pwd,'.img$');
            else
               M0img = spm_get(1,'*.img','Select M0 image');
            end
            M0wm=-20;
            M0csf=-20;  % disable M0wm and M0csf
         end
      end
   end
   
   %% now deal with M0roi, the roi map for getting the M0 value: M0wm or M0csf
   if QuantFlag==1    % the following section for getting M0roi is only needed when QuantFlag==1 because M0val is needed.
      if M0wmcsfFlag == 0,   imgaffix=['M0WM' imgaffix];
      elseif M0wmcsfFlag==1, imgaffix=['M0CSF' imgaffix];
      end
      if ~isempty(M0img)                     % note: empty M0img means that M0wm or M0csf is provided. see line 444 (marked with RESETM0IMG).
         M0auto=0; %#ok<NASGU>
         if M0wmcsfFlag == 0  % M0wm
            xy='white matter';
         elseif M0wmcsfFlag==1
            xy='CSF';
         end
         if exist('M0roi','var') && ~isempty(M0roi)      
            if ~exist(M0roi,'file')
               fprintf(fidLog, 'The %s mask file does not exist!\n',xy);
               if modernSPM
                  M0roi = spm_select(1,'image',['Select a ' xy ' mask'],'',pwd,'.seg.img$');
               else
                  M0roi = spm_get(1,'*.img',['Select a ' xy ' mask']);
               end
               
            end
            M0auto=1;
         else
            pos=pos+1;
            M0auto= spm_input(['Draw a ' xy 'roi for extracting M0?'], pos, 'm',...
               'yes|*no',...
               [0 1], 0);
            if M0auto==1
               if modernSPM
                  M0roi = spm_select(1,'image',['Select a ' xy ' mask'],'',pwd,'.seg.img$*');
               else
                  M0roi = spm_get(1,'*seg*.img',['Select a ' xy ' mask']);
               end
               
            end
         end  % end try M0roi
      end  % end if QuantFlag==1
   end
   %%%%%%%
   r1a=1/BloodT1; %0.601 sec for 3T was set to 0.67  sec in Wang 03
   if ~exist('labeff','var') || isempty(labeff) 
      pos=pos+1;
      if AslType==0
         labeff=spm_input('Enter the label efficiency', pos, 'e', 0.95);
      elseif AslType==1
         labeff=spm_input('Enter the label efficiency', pos, 'e', 0.68);
      else
         labeff=spm_input('Enter the label efficiency', pos, 'e', 0.82);
      end
   end
   %% When QuantFlag==1, M0img is not empty, and M0auto==0
   if (QuantFlag==1)                         % CALCM0BLK
      if ~isempty(M0img)                    % take the mena M0 wm or M0csf from the roi in the mask image or drawn by users  % M0ROIBLK
         vim=spm_vol(Filename(1,:));
         VM0=spm_vol(deblank( M0img ) );
         if sum(VM0.dim(1:3)==vim(1).dim(1:3))~=3
            fprintf(fidLog, '\n The M0 image size is different from the functional images!\n')
         end
         M0=spm_read_vols(VM0);
         M0(find(isnan(M0)))=0;
         if M0wmcsfFlag == 0  % M0wm
            xy='white matter';
         elseif M0wmcsfFlag==1
            xy='CSF';
         end
         if M0auto==0
            disp(['Draw a ' xy ' mask ...']);
            sl=8;
            tmp=sl;
            disp('Input 0 to end the selection loop.');
            roiplane=zeros(VM0.dim(1),VM0.dim(2));
            [xi,yi] = meshgrid(linspace(1,VM0.dim(1),VM0.dim(1)*2),linspace(1,VM0.dim(2),VM0.dim(2)*2));
            scale = 6;
            r = VM0.dim(2)*scale;
            c = VM0.dim(1)*scale;
            h=figure;
            w = get(h, 'Position');
            set(h, 'Unit', 'Pixels', 'Position', [w(1), w(2), c, r]);
            set(gca, 'Position', [0, 0, 1, 1]);
            plane=reshape(M0(:,:,tmp),VM0.dim(1),VM0.dim(2));
            plane=rot90(plane);
            roiplane=interp2(plane,xi,yi);
            imagesc(roiplane*255);
            colormap(gray(256));
            axis off
            while tmp
               tmp=input(['please choose an appropriate slice between 1 to ' num2str(VM0.dim(3)) ', type 0 to finish this process:  ']);
               sl=tmp;
               if (tmp>0) && (tmp <= VM0.dim(3))
                  plane=reshape(M0(:,:,tmp),VM0.dim(1),VM0.dim(2));
                  plane=rot90(plane);
                  roiplane=interp2(plane,xi,yi);
                  imagesc(roiplane*255);
               end
            end
            BW=roipoly;
            roiplane=roiplane.*BW;
            roiavg=mean(mean(roiplane(find(roiplane>0))));
         else   % get the mean ROI M0 value automatically
            VM0seg=spm_vol(deblank( M0roi ) );
            if sum(VM0seg.dim(1:3)==VM0.dim(1:3))~=3
               fprintf(fidLog, '\n The %s M0 mask image has different size from the M0 image!\n', xy);
               fprintf(fidLog, 'Please choose the right mask!\n');
               pos=pos+1;
               if modernSPM
                  M0roi = spm_select(1,'image',['Select ' xy ' M0 mask image'],'',pwd,'.seg.img$*');
               else
                  M0roi = spm_get(1,'*seg*.img',['Select ' xy ' M0 mask']);
               end
               VM0seg=spm_vol(deblank( M0roi ) );
               if sum(VM0seg.dim(1:3)==vim(1).(1:3))~=3
                  fprintf(fidLog, '\n The %s M0 mask is still not right!\n',xy);
                  fprintf(fidLog, 'Please go back and check it carefully!\n');
                  return;
               end
            end
            
            M0segdata=spm_read_vols(VM0seg);
            sln=size(M0segdata,3);
            M0segdata(find(isnan(M0segdata)))=0;
            if sln>7
               M0segdata(:,:,[1:3 (sln-1):sln])=0;
            elseif sln>4
               M0segdata(:,:,[1 sln])=0;
            end
            msk=M0segdata>0.8*max(M0segdata(:));
            msk(:,:,[1:fix(VM0seg.dim(3)/4) VM0seg.dim(3)-min(3,fix(VM0seg.dim(3)/4)):VM0seg.dim(3)] )=0;
            m0=M0.*msk;
            roiavg=mean(mean(m0(find(m0>0))));
         end    % end if M0auto
         fprintf(fidLog, 'The mean value of the roi is:%03f\n',roiavg);
         %fprintf(fidLog, logfid,'\nThe mean value of the roi is:%03f',roiavg);
         if M0wmcsfFlag == 0
            M0wm = roiavg;
         elseif M0wmcsfFlag==1
            M0csf = roiavg;
         end
      end    % if ~isempty(M0img)  line marked with M0ROIBLK
      if M0wmcsfFlag == 0
         M0b=M0wm*Rwm*exp( (1/T2wm-1/T2b)*TE);
      elseif M0wmcsfFlag==1
         M0b=M0csf*Rcsf*exp( (1/T2csf-1/T2b)*TE);
      end
   else
      if useM0   % M0img has been selected
         vim=spm_vol(Filename(1,:));
         VM0=spm_vol(deblank( M0img ) );
         if sum(VM0.dim(1:3)==vim(1).dim(1:3))~=3
            fprintf(fidLog, 'The M0 image size is different from the functional images!\n');
         end
         M0=spm_read_vols(VM0);
         M0(find(isnan(M0)))=0;
      end
   end   % end if (QuantFlag==1)   see line 519 marked with CALCM0BLK
end;    % end if CBFFlag==1
if AslType==0   % PASL
   if Labeltime<1 && Labeltime>0.5
      TI1=Labeltime*1000;   % changing into in msec
   end
end

% 
%    CWRU_perf_subtract(Filename,FirstimageType, SubtractionType,...
%            SubtractionOrder,Flag,   ...
%            Timeshift,AslType,labeff,MagType, ...
%            Labeltime,Delaytime,Slicetime,TE,M0img,M0roi,maskimg, ...
%            M0csf, M0wm, threshold, ...
%            Foldername_TPMs, OutlierThresholds)

fprintf(fidLog, 'CWRU_perf_subtract parameter summary: \n');
fprintf(fidLog, 'Filename(1)=%s\n', Filename(1,:));
fprintf(fidLog, 'maskimg=%s\n', maskimg);
fprintf(fidLog, 'M0img=%s\n', M0img);
fprintf(fidLog, 'Foldername_TPMs=%s\n', Foldername_TPMs);
fprintf(fidLog, 'FirstimageType=%d, SubtractionType=%d, SubtractionOrder=%d \n', FirstimageType, SubtractionType,SubtractionOrder);
fprintf(fidLog, 'Timeshift=%d, AslType=%d, MagType=%d, LabelEfficiency=%f \n', Timeshift, AslType,MagType, labeff);
fprintf(fidLog, 'Labeltime_ms=%f, Delaytime_ms=%f, Slicetime_ms=%f, TE_ms=%f \n', Labeltime,Delaytime,Slicetime,TE);
fprintf(fidLog, 'M0csf=%f, M0wm=%f, threshold=%f, effective M0b=%f \n', M0csf,M0wm,threshold,M0b);
fprintf(fidLog, 'OutlierThresholds= [');
fprintf(fidLog, ' %i',OutlierThresholds);
fprintf(fidLog, ']\n');
fprintf(fidLog, 'Flag Values: MaskFlag=%i, MeanFlag=%i, CBFFlag=%i, BOLDFlag=%i, OutPerfFlag=%i  \n', MaskFlag,MeanFlag,CBFFlag,BOLDFlag,OutPerfFlag);
fprintf(fidLog, '             OutCBFFlag=%i, QuantFlag=%i, ImgFormatFlag=%i, D4Flag=%i, M0wmcsfFlag=%i, OutliersNANFlag=%i, DumpCBF_DataFlag=%i  \n', ...
                                       OutCBFFlag,QuantFlag,ImgFormatFlag,D4Flag,M0wmcsfFlag, OutliersNANFlag, DumpCBF_DataFlag);
fprintf(fidLog, '             ExcludeOutliersEachPerfusion=%i, OutlierThresholds_IsFixedValues=%i \n', ...
                                       ExcludeOutliersEachPerfusion,  OutlierThresholds_IsFixedValues   );
if UsePrecomputedCBF 
   fprintf(fidLog, 'UsePrecomputedCBF=%i,  PrecomputedCBFImage=%s\n', UsePrecomputedCBF, PrecomputedCBFImage);
   fprintf(fidLog, 'PrecomputedCBF_Scaling=%f\n', PrecomputedCBF_Scaling);
end
   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  END OF PARAMETER PREPARATION                                                       %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The selected images must have the same dimensions.
Vall=spm_vol(deblank( Filename ) );
Is4D=size(Filename,1)<2;
if spm_check_orientations(Vall)
   alldat=spm_read_vols(Vall);
else
   alldat=[];
   for im=1:size(Filename,1)
      alldat=cat(4,alldat,spm_read_vols(Vall(im)));
   end
end
alldat(find(isnan(alldat)))=0;
tlen=size(alldat,4);
if tlen<2, fprintf(fidLog, 'You should select at least a pair of ASL raw images!\n');return;end;
perfno=fix(tlen/2);
imno=perfno*2;


% MEANSCALE=mean(alldat(find(alldat>0.1*max(alldat(:)))));  % a scale for removing outliers
if exist('maskimg','var') && ~isempty(maskimg) 
   vmm=spm_vol(deblank( maskimg ) );
   maskdat=spm_read_vols(vmm);
   glmask=maskdat>0.75;
else
   malldat=squeeze(mean(alldat,4));
   malldat(find(isnan(malldat(:))))=0;
   thresh=relthresh*max(malldat(:)); % a global threshhold
   glmask=malldat>thresh;
end
brain_ind=find(glmask>0);            % within brain voxels
if MaskFlag
   vxidx = brain_ind;                 % vxidx indicates voxel locations for quantification
else
   glmask=malldat>-2000;
   vxidx = find(glmask);         % no masking
end
MEANSCALE=mean(alldat(glmask));  % a scale for removing outliers
if MeanFlag==1
   meanBOLDimg=zeros(Vall(1).dim(1),Vall(1).dim(2),Vall(1).dim(3));
   meanPERFimg=zeros(Vall(1).dim(1),Vall(1).dim(2),Vall(1).dim(3));
   if CBFFlag==1 meanCBFimg =zeros(Vall(1).dim(1),Vall(1).dim(2),Vall(1).dim(3)); end
end


%If doing segmented summarization, prepare the TPMs data matrices.
if (DoTPMSegmentedSummarization) 
   %We need to create data matrices from the TPMs that have the same resolution and orientation
   %as the PASL data.  Use spm_imcalc, simply setting the reference image (the first image) to be
   %an array of 0's in the same space as the PASL data, and then adding the TPM's.  This will apply 
   % interpolation and reorientation to bring the data into alignment with the PASL data.
   
   Vzero_PASL = Vall(1);  %copy the structure from the PASL data, first element 
   %img = spm_read_vols(Vzero_PASL);   
   Vzero_PASL.fname = fullfile(pth, 'tmp_PASL_zeroes.nii');
   Vzero_PASL.dt = [spm_type('float32') 0];
   Vzero_PASL = spm_write_vol(Vzero_PASL, zeros(Vzero_PASL.dim(1:3)));
   TPMData_columnnames={};
   for tpm_idx=1:TPM_count
      Vi = [Vzero_PASL  V_TPMs(tpm_idx)];
      V_TPM_resized= Vzero_PASL;  %copy the structure from the PASL data
      [pth_TPM nam ext num] = spm_fileparts(V_TPMs(tpm_idx).fname);
      V_TPM_resized.fname=fullfile(pth, [nam '_resized' ext]); 

      %flags for spm_imcalc
      dmtx=0;  %do not use data matrix
      mask=0;  %do not use mask values
      interp=1; %interp=1 is trilinear;
      dtype = spm_type('float32');
      V_TPM_resized = spm_imcalc(Vi, V_TPM_resized, 'i1 + i2', {dmtx,mask,interp,dtype} );
      imgTPM(:,:,:,tpm_idx) = spm_read_vols(V_TPM_resized);      
      TPMData_columnnames(tpm_idx) = {['TPM ' TissueTypeIndex2Name(tpm_idx)]};      
   end
     
   delete(Vzero_PASL.fname);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Log file
%logfid=fopen('perfsubtract.log','w');
%fprintf(fidLog, logfid,'Log file for generating perfusion images. %s\n',date);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The main loop
if FirstimageType  % 1 control first
   %confiles=Filename(1:2:end,:);
   conidx = 1:2:2*perfno;
   labidx = 2:2:2*perfno;
   %labfiles=Filename(2:2:end,:);
else   % 0 label first
   conidx = 2:2:2*perfno;
   labidx = 1:2:2*perfno;
   %confiles=Filename(2:2:end,:);
   %labfiles=Filename(1:2:end,:);
end
[pth,nm,xt] = spm_fileparts(deblank(Filename(1,:)));
prevpth=pth;
fseq=0;
fprintf(fidLog,'   CBF quantification for L/C pair: %s',deblank(Filename(1,:)));
midname4D='';

if DumpCBF_DataFlag
   perfdata_all = zeros(size(vxidx,1),perfno); 
   cbfdata_all = zeros(size(vxidx,1),perfno); 
end

if UsePrecomputedCBF
   meanCBF_Precomputed=spm_read_vols(spm_vol(PrecomputedCBFImage));
   meanCBF_Precomputed = PrecomputedCBF_Scaling * meanCBF_Precomputed;
end


for p=1:perfno

   Perfusion_Mean_All=0;
   Perfusion_Mean_Cleaned=0;
   CBF_Mean_All=0;
   CBF_Mean_Cleaned=0;
   Outliers_Low_Count = 0;
   Outliers_High_Count = 0;
   Outlier_LowThreshold = 0;
   Outlier_HighThreshold = 0;

   str = sprintf('#%3d /%3d: ',p,perfno );
   sprintf( '\n%s%15s%20s',repmat(sprintf('\b'),1,35),str,'...calculating');
   %   fprintf(fidLog,'...calculating');
   if Is4D>0
      midname=strtok(Filename,',');
      midname=spm_str_manip(midname,'dts');
   else
      [pth,nm,xt] = spm_fileparts(deblank(Filename( (2*(p-1)+1+FirstimageType),:)));
      xt=strtok(xt,',');  % removing the training ','
      midname=spm_str_manip(Filename(2*(p-1)+1,:),'dts');
   end
   midname=strtok(midname,',');  % this could be redundant
   midname=spm_str_manip(midname,'dts');
   if p==1, midname4D=midname; end;
   if strcmp(prevpth,pth)==0   fseq=0;    end
   fseq=fseq+1;
   prevpth=pth;
   prefix     = [pth filesep 'Perf_' num2str(SubtractionType)];
   cbfprefix=fullfile(pth, ['cbf_' num2str(SubtractionType)]);
   BOLDprefix=[pth filesep 'PseuBold'];

   %Vlab=spm_vol(deblank(labfiles(p,:)));
   %[Vlabimg,cor]=spm_read_vols(Vlab);
   Vlabimg = alldat(:,:,:,labidx(p));
   % Here we assumed that the image values are modest, so no overflow will occur.
   switch SubtractionType
      case 1   % The linear interpolation method "surround average"
         %Vcon=spm_vol(deblank(confiles(p,:)));
         %[Vconimg,cor]=spm_read_vols(Vcon);
         Vconimg = alldat(:,:,:,conidx(p));

         if FirstimageType
            if p<perfno
               %Vcon2=spm_vol(deblank(confiles(p+1,:)));
               Vconimg = (Vconimg+squeeze(alldat(:,:,:,conidx(p+1))))/2;
            end
         else
            if p>1
               %Vcon2=spm_vol(deblank(confiles(p-1,:)));
               Vconimg = (Vconimg+squeeze(alldat(:,:,:,conidx(p-1))))/2;
            end
         end
         %[Vconimg2,cor]=spm_read_vols(Vcon2);
         %Vconimg=(Vconimg+Vconimg2)/2.0; clear Vconimg2 Vcon2;

      case 2   % sinc-subtraction
         % 6 point sinc interpolation
         if FirstimageType==0
            idx=p+[-3 -2 -1 0 1 2];
            normloc=3-Timeshift;
         else
            idx=p+[-2 -1 0 1 2 3];
            normloc=2+Timeshift;
         end
         idx(find(idx<1))=1;
         idx(find(idx>perfno))=perfno;
         %v=spm_vol(confiles(idx,:));
         %Vcon=v(1);
         %nimg=spm_read_vols(v);
         nimg = alldat(:,:,:,conidx(idx));
         nimg=reshape(nimg,size(nimg,1)*size(nimg,2)*size(nimg,3),size(nimg,4));
         clear tmpimg;
         [pn,tn]=size(nimg);
         tmpimg=sinc_interpVec(nimg(brain_ind,:),normloc);
         Vconimg=zeros(size(nimg,1),1);
         Vconimg(brain_ind)=tmpimg;
         Vconimg=reshape(Vconimg,Vall(1).dim(1),Vall(1).dim(2),Vall(1).dim(3));
         clear tmpimg pn tn;
      otherwise
         %disp('The default is the simple pair wise subtraction\n');
         %Vcon=spm_vol(deblank( Filename( (2*p-FirstimageType),:) ) );
         %[Vconimg,cor]=spm_read_vols(Vcon);
         Vconimg = alldat(:,:,:,conidx(p));
   end

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   % perform subtraction
   perfimg=Vconimg-Vlabimg;
   if SubtractionOrder==0  %label-control
      perfimg=-1.0*perfimg;
   end
   if MaskFlag==1
      %mask=Vconimg>relthresh*max(Vconimg(:));
      perfimg=perfimg.*glmask;
   end

   slicetimearray=ones(Vall(1).dim(1)*Vall(1).dim(2),Vall(1).dim(3));
   if ~exist('Slicetime','var') Slicetime=0; end
   for sss=1:Vall(1).dim(3)
      slicetimearray(:,sss)=slicetimearray(:,sss).*(sss-1)*Slicetime;
   end
   slicetimearray=reshape(slicetimearray,Vall(1).dim(1),Vall(1).dim(2),Vall(1).dim(3));
   slicetimearray=slicetimearray(vxidx);
   BOLDimg=(Vconimg+Vlabimg)/2.;
   meanbold=squeeze(mean(BOLDimg,4));
   %    BOLDimg=Vconimg;
   if BOLDFlag
      Vbold=Vall(1);
      if D4Flag
         Vbold.fname=[BOLDprefix '_' midname4D '_4D' imgaffix];
         Vbold.n = [fseq 1];
         if modernSPM
            Vbold.dt=[16 0];
         else
            Vbold.dim(4)=16;
         end
         Vbold=spm_write_vol(Vbold,BOLDimg);
      else
         Vbold.fname=[BOLDprefix '_' midname '_' num2str(fseq,'%0.3d') imgaffix];
         if modernSPM
            Vbold.dt=[16 0];
         else
            Vbold.dim(4)=16;
         end
         Vbold=spm_write_vol(Vbold,BOLDimg);
      end
   end
   if MeanFlag==1
      meanPERFimg=meanPERFimg+perfimg;
      if BOLDFlag==1 meanBOLDimg=meanBOLDimg+Vconimg;  end;
   end
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   % CBF quantification
   cbfimg=zeros(size(perfimg));
   if CBFFlag==1
      if AslType==0  % PASL
         clear tcbf;
         TI=Delaytime+slicetimearray;   % TI1+Delaytime+slicetimearray;
         tperf=perfimg(vxidx);
         tmpsig=meanbold(vxidx);
         tcbf=zeros(size(vxidx));
         effidx=find(abs(tmpsig)>1e-3*mean(tmpsig(:)));  %TF 6 Oct 2017: I do not comprehend the reason for this line.  It seems like it simply wants to filter out very small values... but for what purpose?
         % In actual practice, I have not seen it actually remove any
         % values from the arrays... the effidx is same as vxidx

         efftperf=tperf(effidx);
         TI=TI(effidx);
         if UsePrecomputedCBF
            cbf_precomputed_selected = meanCBF_Precomputed(vxidx);
            tcbf(effidx)= cbf_precomputed_selected(effidx);
         else         
            if QuantFlag==1                   % using a single M0 value (should be M0b)
               %tcbf(effidx)=efftperf*6000*1000./(2*Aprim*roiavg.*exp(-TI/BloodT1)*TI1*labeff*qTI);
               tcbf(effidx)=efftperf*6000*1000./(2*M0b.*exp(-TI/BloodT1)*TI1*labeff*qTI);
            else                              % using voxelwise M0 value for different voxel
               if exist('M0','var')
                  eM0=M0(vxidx);
               else
                  eM0=Vconimg(vxidx);
               end
               effM0=eM0(effidx);
               %tcbf(effidx)=lambda*efftperf*6000*1000./(2*Aprim*effM0)./exp(-TI/BloodT1)/TI1/labeff;
               tcbf(effidx)=lambda*efftperf*6000*1000./(2*effM0.*exp(-TI/BloodT1)*TI1*labeff*qTI);
            end
         end
         cbfimg(vxidx)=tcbf;  

      else  %CASL
         if useM0==1
            omega=Delaytime+slicetimearray;
            clear tcbf;
            locMask=Vconimg(brain_ind);
            tperf=perfimg(brain_ind);
            tcbf=zeros(size(locMask));
            effidx=find(abs(locMask)>1e-3*mean(locMask(:)));
            omega=omega(effidx);
            efftperf=tperf(effidx);
            if QuantFlag==1
               %efftcbf=efftperf./roiavg;
               efftcbf=efftperf./M0b;
            else                              % using different M0 value for different voxel
               eM0=M0(brain_ind);
               effM0=eM0(effidx);
               efftcbf=efftperf./effM0;
            end
            efftcbf=6000*1000*lambda*efftcbf*r1a./(2*labeff* (exp(-omega*r1a)-exp( -1*(Labeltime+omega)*r1a) ) );  % this model is based on Wang et al Riology 2005
            % efftcbf=6000*1000*lambda*efftcbf*r1g./(2*labeff* (exp(-omega*r1a)-exp( -1*(Labeltime+omega)*r1g) ) ); % this one should be the correct one
            tcbf(effidx)=efftcbf;
            cbfimg(brain_ind)=tcbf;
         else
            omega=Delaytime+slicetimearray;
            clear tcbf;
            M0=Vconimg(brain_ind);
            tperf=perfimg(brain_ind);
            tcbf=zeros(size(M0));
            effidx=find(abs(M0)>1e-3*mean(M0(:)));
            omega=omega(effidx);
            effM0=M0(effidx);
            efftperf=tperf(effidx);

            efftcbf=efftperf./effM0;
            efftcbf=6000*1000*lambda*efftcbf*r1a./(2*labeff* (exp(-omega*r1a)-exp( -1*(Labeltime+omega)*r1a) ) );
            tcbf(effidx)=efftcbf;
            cbfimg(brain_ind)=tcbf;
         end

      end

      if DumpCBF_DataFlag,  cbfdata_all(:, p) = tcbf; end  
      if MeanFlag==1
         meanCBFimg=meanCBFimg+cbfimg;
      end
      % Getting a mask for outliers
      % mean+3std has problem in some cases
      nanmask=isnan(cbfimg);
      wholemask=glmask-nanmask;
      whole_ind=find(wholemask>0);

      if ExcludeOutliersEachPerfusion

         if OutlierThresholds_IsFixedValues
            Outlier_LowThreshold = OutlierThresholds(1);
            Outlier_HighThreshold = OutlierThresholds(2);         
         else  % compute thresholds based on standard deviation and mean
            cbf_mean = mean(cbfimg(whole_ind));
            cbf_stdev = std(cbfimg(whole_ind),1);
            Outlier_LowThreshold = cbf_mean + OutlierThresholds(1)*cbf_stdev;
            Outlier_HighThreshold = cbf_mean + OutlierThresholds(2)*cbf_stdev;
         end
         outliermask=((cbfimg<Outlier_LowThreshold)+(cbfimg>Outlier_HighThreshold))>0;
      else
         outliermask= zeros(size(cbfimg));            
         Outlier_LowThreshold = -1* realmax('single') ;
         Outlier_HighThreshold = realmax('single') ;
      end

      sigmask=glmask-outliermask-nanmask;
      sigmask(sigmask<1)=0;  %above line possibly generated -1; change those back to zeros
      outliercleaned_maskind=find(sigmask);

      CBF_Mean_Cleaned=mean(cbfimg(outliercleaned_maskind));
      CBF_Mean_All=mean(cbfimg(whole_ind));

      Outliers_Low_Count = size(find(cbfimg<Outlier_LowThreshold),1);
      Outliers_High_Count = size(find(cbfimg>Outlier_HighThreshold),1);

      if OutliersNANFlag
         cbfimg(find(outliermask>0))=nan;
      end

      if OutCBFFlag
         VCBF=Vall(1);
         if D4Flag
            VCBF.fname=[cbfprefix '_' midname4D '_4D' imgaffix];
             if (fseq==1)  %on first time through loop, delete any old file
                 delete(VCBF.fname);
             end
            if modernSPM
               VCBF.dt=[16,0];
            else
               VCBF.dim(4)=16; %'float' type
            end
            VCBF.n = [fseq 1];
            VCBF=spm_write_vol(VCBF,cbfimg);
         else

            VCBF.fname=[cbfprefix '_' midname '_' num2str(fseq,'%0.3d') imgaffix];
            if modernSPM
               VCBF.dt=[16,0];
            else
               VCBF.dim(4)=16; %'float' type
            end
            VCBF=spm_write_vol(VCBF,cbfimg);
         end
      end

      %for the TPM segmentation, compute the mean CBF of each TPM 
      if (DoTPMSegmentedSummarization) 
         for tpm_idx=1:TPM_count
            TPM_this = imgTPM(:,:,:,tpm_idx);
            TPM_mask_this =  (TPM_this>=TPM_Threshold);   %in this simplistic approach, consider only the voxels where tissue map greater than 0.5
            TPM_mask_this = TPM_mask_this .* sigmask;  %keep only those in the brainmask, and eliminate outliers
            %cbfimg_TPMthis = cbfimg .* TPM_this .* TPM_mask_this;  %

            Segmented_Data_CBF_Mean_EachPerf(p, tpm_idx) = mean(cbfimg(find(TPM_mask_this)));
            Segmented_Data_VoxelCount_EachPerf(p, tpm_idx) = numel(find(TPM_mask_this));
        end
      end

   else  % do not compute CBF.  Looks for outliers based only on perfusion signal
      %getting sigmask and wholemask
      nanmask=isnan(perfimg);
      wholemask=glmask-nanmask;

      if ExcludeOutliersEachPerfusion

         if OutlierThresholds_IsFixedValues
            Outlier_LowThreshold = OutlierThresholds(1);
            Outlier_HighThreshold = OutlierThresholds(2);         
         else  % compute thresholds based on standard deviation and mean
            perf_mean = mean(perfimg(wholemask));
            perf_stdev = std(perfimg(wholemask),1);
            Outlier_LowThreshold = perf_mean - OutlierThresholds(1)*perf_stdev;
            Outlier_HighThreshold = perf_mean + OutlierThresholds(2)*perf_stdev;
         end
         outliermask=((perfimg<Outlier_LowThreshold)+(perfimg>Outlier_HighThreshold))>0;
     else
         outliermask= zeros(size(cbfimg));
      end

      sigmask=glmask-outliermask-nanmask;
      whole_ind=find(wholemask>0);
      outliercleaned_maskind=find(sigmask>0);
      Outliers_Low_Count = size(find(perfimg<Outlier_LowThreshold),1);
      Outliers_High_Count = size(find(perfimg>Outlier_HighThreshold),1);      
   end

   if DumpCBF_DataFlag,  perfdata_all(:, p) = perfimg(outliercleaned_maskind); end  

   Perfusion_Mean_Cleaned=mean(perfimg(outliercleaned_maskind));
   Perfusion_Mean_All=mean(perfimg(whole_ind));
   CountVoxels_All = numel(whole_ind);
   CountVoxels_Cleaned = numel(outliercleaned_maskind);
   PerfusionIndex = p;
   %add the values into our results table
   tabResults(p,:) = table(PerfusionIndex, Perfusion_Mean_All,Perfusion_Mean_Cleaned, ... 
          CBF_Mean_All,CBF_Mean_Cleaned, CountVoxels_All, CountVoxels_Cleaned, ...
          Outliers_Low_Count, Outliers_High_Count, Outlier_LowThreshold, Outlier_HighThreshold);

   %     perfimg(find(outliermask>0))=nan;
   if OutPerfFlag
      Vdiff=Vall(1);
      if D4Flag
         Vdiff.fname=[prefix '_' midname4D '_4D' imgaffix];
         if (fseq==1)  %on first time through loop, delete any old file
             delete(Vdiff.fname);
         end
         if modernSPM
            Vdiff.dt=[16 0];
         else
            Vdiff.dim(4)=16;
         end
         Vdiff.n=[fseq 1];
         Vdiff=spm_write_vol(Vdiff,perfimg);
      else
         Vdiff.fname=[prefix '_' midname '_' num2str(fseq,'%0.3d') imgaffix];
         if modernSPM
            Vdiff.dt=[16 0];
         else
            Vdiff.dim(4)=16;
         end
         Vdiff=spm_write_vol(Vdiff,perfimg);
      end
   end
end  %end the main loop

sprintf('...done\n');
fprintf(fidLog,'...done\n');
if MeanFlag==1
   meanPERFimg=meanPERFimg./perfno;
   if BOLDFlag==1, meanBOLDimg=meanBOLDimg./perfno;end;
   if CBFFlag==1
      meanCBFimg=meanCBFimg./perfno; 
   end
   
   %% output the mean images
   Vmean=Vall(1);
   if modernSPM
      Vmean.n = [1 1];
   end
   %   nm=strtok(midname,'_0123456789');
   nm=midname;
   Vmean.fname=fullfile(pth, ['meanPERF_' num2str(SubtractionType) '_' nm imgaffix]);
   if modernSPM
      Vmean.dt=[16 0];
   else %
      Vmean.dim(4)=16; %'float' type
   end
   
   Vmean=spm_write_vol(Vmean,meanPERFimg);
   fprintf(fidLog,'   Created mean perfusion image file: %s\n', Vmean.fname);
   
   if BOLDFlag==1
      Vmean.fname=fullfile(pth, ['meanBOLD_' num2str(SubtractionType) '_' nm imgaffix]);
      Vmean=spm_write_vol(Vmean,meanBOLDimg);
      fprintf(fidLog,'   Created mean BOLD image file: %s\n', Vmean.fname);
   end
   if CBFFlag==1
      Vmean.fname=fullfile(pth, ['meanCBF_' num2str(SubtractionType) '_' nm imgaffix]);
      Vmean=spm_write_vol(Vmean,meanCBFimg);
      fprintf(fidLog,'   Created mean CBF image file: %s\n', Vmean.fname);
      
      %   cbf_mean=mean(meanCBFimg(outliercleaned_maskind));  
      % TF 6 Oct 2017: that line above is simply incorrect!  The effect of
      % that line is to set the cbf_mean based on the
      % outliercleaned_maskind from the last iteration through the
      % perfusion loop!!  
      % Outliers are discarded in EACH ITERATION of the perfusion loop
      % (i.e. for each image pair), and a mean CBF is determined for that
      % image pair, with/without outliers.  Those mean CBF values are
      % stored in the 'tabResults' table.  So we can use that to compute the mean
      % of the mean CBF from each perfusion pair.

      if ExcludeOutliersEachPerfusion  %if we did outlier exclusion in each perfusion pair, nothing 
         %to do here except take mean/stdev of the CBF number from each perfusion pair
         cbf_mean_clean = mean(tabResults.CBF_Mean_Cleaned(:));   %new computation, TF 06 Oct 2017
         cbf_mean_all   = mean(tabResults.CBF_Mean_All(:)) ;      %also compute the mean without considering outliers. 
           %Note that the original code used 'mean(meanCBFimg(whole_ind))'
           %which produces the same result (since whole_ind is the same for
           %each iteration of the perfusion calc loop); but this computation
           %is more clear
         cbf_std_clean  = std(tabResults.CBF_Mean_Cleaned(:),1);  %use w=1 to compute the population StDev
         cbf_std_all    = std(tabResults.CBF_Mean_All(:),1);  %use w=1 to compute the population StDev

         nanmask=isnan(meanCBFimg);
         sigmask=glmask-nanmask;
         sigmask(sigmask<1)=0;  %above line possibly generated -1; change those back to zeros
      else
         %if we did not exclude outliers in each iteration, we can now exclude from the average
         %image
         nanmask=isnan(meanCBFimg);
         wholemask=glmask-nanmask;
         whole_ind=find(wholemask>0);
      
         if OutlierThresholds_IsFixedValues
            Outlier_LowThreshold = OutlierThresholds(1);
            Outlier_HighThreshold = OutlierThresholds(2);         
         else  % compute thresholds based on standard deviation and mean
            cbf_mean = mean(meanCBFimg(whole_ind));
            cbf_stdev = std(meanCBFimg(whole_ind),1);
            Outlier_LowThreshold = cbf_mean + OutlierThresholds(1)*cbf_stdev;
            Outlier_HighThreshold = cbf_mean + OutlierThresholds(2)*cbf_stdev;
         end

         outliermask=((meanCBFimg<Outlier_LowThreshold)+(meanCBFimg>Outlier_HighThreshold))>0;
         sigmask=glmask-outliermask-nanmask;
         sigmask(sigmask<1)=0;  %above line possibly generated -1; change those back to zeros
         outliercleaned_maskind=find(sigmask);
         Outliers_Low_Count = size(find(meanCBFimg<Outlier_LowThreshold),1);
         Outliers_High_Count = size(find(meanCBFimg>Outlier_HighThreshold),1);      
         
         cbf_mean_clean = mean(meanCBFimg(outliercleaned_maskind));   %new computation, TF 06 Oct 2017
         cbf_mean_all   = mean(meanCBFimg(whole_ind)) ;      %also compute the mean without considering outliers. 
           %Note that the original code used 'mean(meanCBFimg(whole_ind))'
           %which produces the same result (since whole_ind is the same for
           %each iteration of the perfusion calc loop); but this computation
           %is more clear
         cbf_std_clean  = std(meanCBFimg(outliercleaned_maskind),1);  %use w=1 to compute the population StDev
         cbf_std_all    = std(meanCBFimg(whole_ind),1);  %use w=1 to compute the population StDev
      end

      if (DoTPMSegmentedSummarization) %if we did TPM segmentation, jam those results onto the CBF data table
         SegmentedCBFMean_on_CBFMeanImage=[];
         SegmentedCBFStDev_on_CBFMeanImage=[];
         SegmentedVoxCount_on_CBFMeanImage= [];

         for colgroup=1:2
            ColumnNames_Mean = {};
            ColumnNames_StDev = {};

            for tpm_idx=1:TPM_count
               tissuetype= TissueTypeIndex2Name(tpm_idx);
               TPM_this = imgTPM(:,:,:,tpm_idx);
               TPM_mask_this =  (TPM_this>=TPM_Threshold);   %in this simplistic approach, consider only the voxels where tissue map greater than 0.5
               TPM_mask_this = TPM_mask_this .* sigmask;  %keep only those in the brainmask, and eliminate outliers
               TPM_mask_this_idx = find(TPM_mask_this);
               switch colgroup
                  case 1
                     ColumnNames_Mean(tpm_idx) = {['CBF_Mean_'  tissuetype]}; %#ok<*AGROW>
                     ColumnNames_StDev(tpm_idx) = {['CBF_StDev_'  tissuetype]}; %#ok<*AGROW>

                     %do computation of TPM on the **mean CBF image**
                     SegmentedCBFMean_on_CBFMeanImage(tpm_idx) = mean(meanCBFimg(TPM_mask_this_idx)); 
                     SegmentedCBFStDev_on_CBFMeanImage(tpm_idx) = std(meanCBFimg(TPM_mask_this_idx),1); 

                  case 2
                     ColumnNames_Mean(tpm_idx) = {['CountVoxels_' tissuetype]};
                     SegmentedVoxCount_on_CBFMeanImage(tpm_idx) = numel(TPM_mask_this_idx);

               end
            end

            switch colgroup
               case 1
                  tabResults = [tabResults array2table(Segmented_Data_CBF_Mean_EachPerf, 'VariableNames', ColumnNames_Mean)];

               case 2
                  tabResults = [tabResults array2table(Segmented_Data_VoxelCount_EachPerf, 'VariableNames', ColumnNames_Mean) ];

            end
         end
      end
      
      glcbf=cbf_mean_clean;  
      
      fprintf(fidLog,'  For all data within mask,   mean CBF=%03f; stdev=%03f; count voxels=%03f\n', ...
                        cbf_mean_all, cbf_std_all, mean(tabResults.CountVoxels_All(:)) );      
      fprintf(fidLog,'  Using outlier-cleaned data, mean CBF=%03f; stdev=%03f; mean count voxels per perfusion image=%03f\n', ...
                        cbf_mean_clean, cbf_std_clean, mean(tabResults.CountVoxels_Cleaned(:)) );      
      if ExcludeOutliersEachPerfusion
         fprintf(fidLog,'  Outliers were excluded from each individual CBF map\n'  );      
      else   
         fprintf(fidLog,'  Outliers were excluded from the final mean CBF map, Outlier_LowThreshold=%03f; Outlier_HighThreshold=%03f; Outliers_Low_Count=%i; Outliers_High_Count=%i\n', ...
                        Outlier_LowThreshold, Outlier_HighThreshold, Outliers_Low_Count, Outliers_High_Count );      
      end
      
      if (DoTPMSegmentedSummarization) %if we did TPM segmentation, jam those results onto the CBF data table            
         if ExcludeOutliersEachPerfusion, data_variety='all'; else , data_variety='outlier-cleaned'; end

         for tpm_idx=1:TPM_count
            tissuetype= TissueTypeIndex2Name(tpm_idx);

            fprintf(fidLog,'  Tissue segmented data, using mean CBF image (%s data); Tissue name: %s; mean CBF=%03f; stdev=%03f; count voxels=%03f\n', ...
                              data_variety, tissuetype,  ...
                              SegmentedCBFMean_on_CBFMeanImage(tpm_idx), SegmentedCBFStDev_on_CBFMeanImage(tpm_idx), SegmentedVoxCount_on_CBFMeanImage(tpm_idx)  );      
      
         end
      end   
      
    else
      glcbf=[];
   end
   
end


gsfile=fullfile(pth, ['globalsg_' datestr(now,'yyyymmdd_HHMMSS') '.txt']);
%save(gsfile,'gs','-ascii');
writetable(tabResults,gsfile,'FileType','text','Delimiter','tab');

if DumpCBF_DataFlag
   CBF_DataFilename = fullfile(pth, ['CBF_Data_' datestr(now,'yyyymmdd_HHMMSS') '.xlsx']);
   [I,J,K] = ind2sub(size(meanCBFimg),vxidx);
   maxsheetnum = 2;
   if DoTPMSegmentedSummarization, maxsheetnum = 3; end
   for sheet=1:maxsheetnum
      column_names={};
      switch sheet
         case 1
            column_prefix = 'perf ';
            sheetname = 'Perfusion';

         case 2
            column_prefix = 'CBF ';
            sheetname = 'CBF';
            
         case 3
            column_names = TPMData_columnnames;
            sheetname = 'TPM';
            
      end
      
      if sheet<=2
         for i=1:perfno
            column_names(i) = {[column_prefix num2str(i)]};      
         end
      end
      
      column_names = [{'voxel_index' 'I' 'J' 'K'} column_names ];
      xlswrite(CBF_DataFilename, column_names, sheetname, 'A1');   
      xlswrite(CBF_DataFilename, vxidx, sheetname, 'A2');   
      xlswrite(CBF_DataFilename, [I J K], sheetname, 'B2');   

      switch sheet
         case 1
            xlswrite(CBF_DataFilename, perfdata_all, sheetname, 'E2');

         case 2
            xlswrite(CBF_DataFilename, cbfdata_all, sheetname, 'E2');
         
         case 3
            TPM_vx=zeros(size(vxidx,1),TPM_count);
            for tpm_idx=1:TPM_count
               TPM_this = imgTPM(:,:,:,tpm_idx);
               TPM_vx(:,tpm_idx) = TPM_this(vxidx);
            end
            xlswrite(CBF_DataFilename, TPM_vx, sheetname, 'E2');
      end
   end
end;

fprintf(fidLog,'   Created summary data file: %s\n', gsfile);
%fclose(logfid);
perfnum=perfno;
return;

end


function tissuetypename = TissueTypeIndex2Name(tpm_idx)

      tissuetypename=''; %#ok<NASGU>
      switch tpm_idx         
         case 1
            tissuetypename = 'GM';
         case 2
            tissuetypename = 'WM';
         case 3
            tissuetypename = 'CSF';
         case 4
            tissuetypename = 'Bone';
         case 5
            tissuetypename = 'Soft';
         case 6
            tissuetypename = 'Air';
         otherwise
            tissuetypename = ['??_' num2str(tpm_idx)];
      end

end