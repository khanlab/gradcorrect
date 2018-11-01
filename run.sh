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
 echo "Usage: gradcorrect bids_dir output_dir {participant,group} <additional arguments>"
 echo "     Required arguments:"
 echo "          [--grad_coeff_file GRAD_COEFF_FILE]  (required)"
 echo ""
 echo "     Optional arguments:"
 echo "          [--participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL...]]"
 echo "          [--only_matching SEARCHSTRING ]  (default: *, e.g.: use 2RAGE to only convert *2RAGE* images, e.g. MP2RAGE and SA2RAGE)"
 echo ""
 exit 1
fi


in_bids=$1 
out_folder=$2 
analysis_level=$3
grad_coeff_file=

searchstring=*


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



       --only_matching )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                searchstring=$2
                  shift
	      else
              die 'error: "--only_matching" requires a non-empty option argument.'
            fi
              ;;
     --only_matching=?*)
          searchstring=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --only_matching=)         # handle the case of an empty --participant=
         die 'error: "--only_matching" requires a non-empty option argument.'
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

if [ ! -e $participants ]
then
    #participants tsv not required by bids, so if it doesn't exist, create one for temporary use
    participants=$scratch_dir/participants.tsv
    echo participant_id > $participants
    pushd $in_bids
    ls -d sub-* >> $participants
    popd 
fi

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
for nii in `ls $subj/{anat,func,fmap,dwi}/${searchstring}.nii.gz $subj/*/{anat,func,fmap,dwi}/${searchstring}.nii.gz`
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
    
    #keep best unwarped in the main folder (to mirror input bids structure)
    out_unwarped=$out_folder/$folder/${file}

    #intermediate files
    intermediate_3d=$derivatives/$folder/${fileprefix}_${filetype}_3dvol.nii.gz

    #extra files (keep in derivatives)
    out_warp=$derivatives/$folder/${fileprefix}_${filetype}_target-nativeGC_warp.nii.gz
    out_nointcorr=$derivatives/$folder/${fileprefix}_${filetype}_nodetjac.nii.gz
    out_detjac=$derivatives/$folder/${fileprefix}_${filetype}_target-nativeGC_warpdetjac.nii.gz
    out_graddev=$derivatives/$folder/${fileprefix}_${filetype}_target-nativeGC_graddev.nii.gz
    out_inpaintmask=$derivatives/$folder/${fileprefix}_${filetype}_inpaintMask.nii.gz 

    
    if [ "`fslval $nii dim4`" = "1" ]
    then
            dimension=3
            in_vol=$nii
     else
            dimension=4

            #extract 3d vol for procGradCorrect
            echo fslroi $nii $intermediate_3d 0 1
            fslroi $nii $intermediate_3d 0 1
            in_vol=$intermediate_3d
    fi

    

    if echo $file | grep -q part-phase
    then    
        #phase image, skip detjac normalization, and use nearest neighbout (interporder=0)
        cmd="procGradCorrect -i $in_vol -g $grad_coeff_file -u $out_nointcorr -s $scratch_dir/$subj -w $out_warp  -F $fovmin -N $numpoints -I 0"
        applyinterp=nn
        isphase=1
    else
        cmd="procGradCorrect -i $in_vol -g $grad_coeff_file -c $out_unwarped -u $out_nointcorr -s $scratch_dir/$subj -w $out_warp -j $out_detjac -F $fovmin -N $numpoints -I $interporder"

        applyinterp=spline
        isphase=0
    fi


    if [ "$filetype" = "dwi" ]
    then
    cmd="$cmd -d $out_graddev"
    fi

    if [ ! -e $out_warp ]
    then
    echo $cmd
    $cmd
    fi

    #remove extra file
    rm -vf $intermediate_3d

    #this applies warp to input nifti if 4d
    if [ "$dimension" == 4 ]
    then
        echo applywarp -i $nii -o $out_nointcorr -w $out_warp --abs --interp=$applyinterp -r $nii 
        applywarp -i $nii -o $out_nointcorr -w $out_warp --abs --interp=$applyinterp -r $nii 
  
       #detjac modulation
        echo fslmaths $out_nointcorr -mul $out_detjac $out_unwarped
        fslmaths $out_nointcorr -mul $out_detjac $out_unwarped
             
    fi



        if [ "$isphase" = "0" ]
        then
 
            #perform correction of cubic spline overshoot
            inpaint_iters=3
            echo fslmaths $out_unwarped -thr 0 $out_inpaintmask
            fslmaths $out_unwarped -thr 0 $out_inpaintmask
            echo "starting inpainting at `date`"
            echo ImageMath $dimension $out_unwarped InPaint $out_inpaintmask $inpaint_iters
            ImageMath $dimension $out_unwarped InPaint $out_inpaintmask $inpaint_iters
            echo "done inpainting at `date`"

        else 
         cp -v $out_nointcorr $out_unwarped
        fi


        #ensure final unwarped (out_unwarped) is same datatype and geom as input (assuming mr images are input type short)

        echo fslmaths $out_unwarped $out_unwarped -odt short
        fslmaths $out_unwarped $out_unwarped -odt short
        echo fslcpgeom $nii $out_unwarped
        fslcpgeom $nii $out_unwarped



    #copy extra files
    for ext in json bvec bval tsv
    do
        if [ -e $folder/${file_noext}.$ext ]
        then
            cp -v $folder/${file_noext}.$ext $out_folder/$folder
        fi
    done


done #nii

#TODO: add check if existing first to avoid errors in log

for otherfile in `ls ./*.{tsv,json} $subj/${searchstring}.{tsv,json} $subj/*/${searchstring}.{tsv,json}`
do
 folder=${otherfile%/*} 
 file=${otherfile##*/}

    if echo $file | grep -q DIS
    then    
        continue
    fi

 cp -v $otherfile $out_folder/$folder/$file

done

popd


#TODO: add check if existing first to avoid errors in log

for otherfile in `ls ./${searchstring}.{tsv,json}`
do
 folder=${otherfile%/*} 
 file=${otherfile##*/}
    if echo $file | grep -q DIS
    then    
        continue
    fi
 
 cp -v $otherfile $out_folder/$folder/$file

done

#TO DO: remove *DIS* scans from the _scans.tsv file

done #subj
