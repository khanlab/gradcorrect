#!/bin/bash


#bids app to gradunwarp, creating mirror of input bids structure 


#for all nifti files that are not already corrected:
# save unwarped identically-named file in output folder
# copy json,bvec,bval,tsv files from anat/func/fmap/dwi
# copy json,tsv from main folder 

#create derivatives/gradcorrect folder for:
# save warpfiles as {prefix}_target-nativeGC_warp.nii.gz
# save detjac as {prefix}_target-nativeGC_detjac.nii.gz



function die {
 echo $1 >&2
 exit 1
}

participant_label=

if [ "$#" -lt 3 ]
then
 echo "Usage: gradcorrect bids_dir output_dir {participant,group} <optional arguments>"
 echo "          [--participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL...]]"
 echo "          [--grad_coeff_file GRAD_COEFF_FILE]"
 echo ""
 exit 1
fi


in_bids=$1 
out_folder=$2 
analysis_level=$3
grad_coeff_file=


fovmin=0.2
numpoints=150
interporder=3

shift 3



while :; do
      case $1 in
     -h|-\?|--help)
	     usage
            exit
              ;;
       --participant_label )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                participant_label=$2
                  shift
	      else
              die 'error: "--participant" requires a non-empty option argument.'
            fi
              ;;
     --participant_label=?*)
          participant_label=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --participant_label=)         # handle the case of an empty --participant=
         die 'error: "--participant_label" requires a non-empty option argument.'
          ;;

       --grad_coeff_file )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                grad_coeff_file=$2
                  shift
	      else
              die 'error: "--grad_coeff_file" requires a non-empty option argument.'
            fi
              ;;
     --grad_coeff_file=?*)
          grad_coeff_file=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --grad_coeff_file=)         # handle the case of an empty --participant=
         die 'error: "--grad_coeff_file" requires a non-empty option argument.'
          ;;



      
      
      -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
              ;;
     *)               # Default case: No more options, so break out of the loop.
          break
    esac
  
 shift
  done


shift $((OPTIND-1))



if [ -e $in_bids ]
then
	in_bids=`realpath $in_bids`
else
	echo "ERROR: bids_dir $in_bids does not exist!"
	exit 1
fi


if [ "$analysis_level" = "participant" ]
then
 echo " running participant level analysis"
 else
  echo "only participant level analysis is enabled"
  exit 0
fi

if [ -n "$grad_coeff_file" ]
then
        if [ -e $grad_coeff_file ]
        then
            grad_coeff_file=`realpath $grad_coeff_file`
        else
            echo "ERROR: --grad_coeff_file $grad_coeff_file does not exist!"
            exit 1
        fi

else
    echo "ERROR: --grad_coeff_file is a required argument"
    exit 1
fi


participants=$in_bids/participants.tsv

scratch_dir=$out_folder/sourcedata/scratch
derivatives=$out_folder/derivatives/gradcorrect


mkdir -p $scratch_dir $derivatives

scratch_dir=`realpath $scratch_dir`
derivatives=`realpath $derivatives`
out_folder=`realpath $out_folder`

echo $participants


if [ -n "$participant_label" ]
then
subjlist=`echo $participant_label | sed  's/,/\ /g'` 
else
subjlist=`tail -n +2 $participants | awk '{print $1}'`
fi

for subj in $subjlist 
do

#add on sub- if not exists
if [ ! "${subj:0:4}" = "sub-" ]
then
  subj="sub-$subj"
fi

pushd $in_bids

#for every nifti:
for nii in `ls $subj/{anat,func,fmap,dwi}/*.nii.gz`
do

    folder=${nii%/*}
    file=${nii##*/}
    file_noext=${file%.nii*}
    filetype=${file_noext##*_}
    fileprefix=${file_noext%_*}

    if echo $file | grep -q DIS
    then    
        echo "$file already gradient distortion corrected, skipping..."
        continue
    fi

    mkdir -p $out_folder/$folder $derivatives/$folder
    out_unwarped=$out_folder/$folder/${file}
    out_warp=$derivatives/$folder/${fileprefix}_${filetype}_target-nativeGC_warp.nii.gz
    out_detjac=$derivatives/$folder/${fileprefix}_${filetype}_target-nativeGC_warpdetjac.nii.gz

    cmd="procGradCorrect -i $nii -g $grad_coeff_file -c $out_unwarped -s $scratch_dir/$subj -w $out_warp -j $out_detjac -F $fovmin -N $numpoints -I $interporder"

    if [ "$filetype" = "dwi" ]
    then
    out_graddev=$derivatives/$folder/${fileprefix}_${filetype}_target-nativeGC_graddev.nii.gz
    cmd="$cmd -d $out_graddev"
    fi

    echo $cmd
    $cmd

    #copy extra files
    echo cp -v $folder/${file_noext}.{json,bvec,bval,tsv} $out_folder/$folder
    cp -v $folder/${file_noext}.{json,bvec,bval,tsv} $out_folder/$folder

done


popd

echo cp -v $in_bids/*.{tsv,json} $out_folder
cp -v $in_bids/*.{tsv,json} $out_folder

done
