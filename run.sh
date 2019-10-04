#!/bin/bash


#bids app to gradunwarp, creating mirror of input bids structure 


#for all nifti files that are not already corrected:
# save unwarped identically-named file in output folder
# copy json,bvec,bval,tsv files from anat/func/fmap/dwi
# copy json,tsv from main folder 

#create sourcedata/gradcorrect folder for:
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
 echo "          [--only_matching SEARCHSTRING ]  ( e.g.: use 2RAGE to only convert *2RAGE* images, e.g. MP2RAGE and SA2RAGE)"
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
                only_matching=$2
                  shift
	      else
              die 'error: "--only_matching" requires a non-empty option argument.'
            fi
              ;;
     --only_matching=?*)
          only_matching=${1#*=} # delete everything up to "=" and assign the remainder.
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

if [ -n "$only_matching" ]
then
    searchstring=*${only_matching}*
fi

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
sourcedata=$out_folder/sourcedata/gradcorrect

mkdir -p $scratch_dir $sourcedata

scratch_dir=`realpath $scratch_dir`
sourcedata=`realpath $sourcedata`
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
for nii in `ls $subj/{anat,func,fmap,dwi,asl}/${searchstring}.nii.gz $subj/*/{anat,func,fmap,dwi,asl}/${searchstring}.nii.gz`
do

    folder=${nii%/*}
    file=${nii##*/}
    file_noext=${file%.nii*}
    filetype=${file_noext##*_}
    fileprefix=${file_noext%_*}

    if echo $file | grep -q DIS
    then    
        echo "$file already gradient distortion corrected from scanner, skipping..."
        continue
    fi

    mkdir -p $out_folder/$folder $sourcedata/$folder
    
    #keep best unwarped in the main folder (to mirror input bids structure)
    out_unwarped=$out_folder/$folder/${file}

    #intermediate files
    intermediate_3d=$sourcedata/$folder/${fileprefix}_${filetype}_3dvol.nii.gz

    #extra files (keep in sourcedata)
    out_warp=$sourcedata/$folder/${fileprefix}_${filetype}_target-nativeGC_warp.nii.gz
    out_nointcorr=$sourcedata/$folder/${fileprefix}_${filetype}_nodetjac.nii.gz
    out_detjac=$sourcedata/$folder/${fileprefix}_${filetype}_target-nativeGC_warpdetjac.nii.gz
    out_graddev=$sourcedata/$folder/${fileprefix}_${filetype}_target-nativeGC_graddev.nii.gz
    out_inpaintmask=$sourcedata/$folder/${fileprefix}_${filetype}_inpaintMask.nii.gz 

    if [ -e $out_unwarped ]
    then
        echo "$file already gradient distortion corrected by this app, skipping..."
	echo "   to force re-processing: rm $out_unwarped"
	continue
    fi

    
    if [ "`fslval $nii dim4`" -lt  2 ]
    then
	    echo "3D volume, using as is"
            dimension=3
            in_vol=$nii
     else
            dimension=4
	    echo "4D volume, extracting 1st 3D vol"
            #extract 3d vol for procGradCorrect
            echo fslroi $nii $intermediate_3d 0 1
            fslroi $nii $intermediate_3d 0 1
            in_vol=$intermediate_3d
    fi


    #now, to avoid re-computing warps that are the same for different images, use a hash of the nii sform to store a link to the out_warp 
    echo "sform for $in_vol is `fslorient -getsform $in_vol`"
    hash=`fslorient -getsform $in_vol | cksum | cut -f 1 -d ' '`

    existing_warp=$scratch_dir/$subj.$hash.warp.nii.gz
    existing_detjac=$scratch_dir/$subj.$hash.detjac.nii.gz
    existing_graddev=$scratch_dir/$subj.$hash.graddev.nii.gz

    echo "hashed file for out_warp is: $existing_warp"
    if [ ! -e $existing_warp ]
    then
    echo "existing_warp doesn't exist, so going to run procGradCorrect"

    #generic command to generate output warp
    cmd="procGradCorrect -i $in_vol -g $grad_coeff_file -s $scratch_dir/$subj -w $out_warp -j $out_detjac -F $fovmin -N $numpoints -I $interporder"

    #add graddev for dwi
    if [ "$filetype" = "dwi" ]
    then
    cmd="$cmd -d $out_graddev"
    fi

    if [ ! -e $out_warp ]
    then
    echo $cmd
    $cmd
    fi

      #now that warp is computed, keep a reference to it
      echo linking $out_warp as $existing_warp
      ln -s $out_warp $existing_warp
      ln -s $out_detjac $existing_detjac
     if [ "$filetype" = "dwi" ]
      then
      ln -s $out_graddev $existing_graddev
      fi
    else
       #existing_warp exists, copy it to output
      echo copying to $out_warp from $existing_warp
       cp -Lv $existing_warp $out_warp 
       cp -Lv $existing_detjac $out_detjac
     if [ "$filetype" = "dwi" ]
      then
       cp -Lv $existing_graddev $out_graddev
      fi

    fi

    #now, at this point, out_warp exists, so apply as required:
   
    if echo $file | grep -qE 'part-phase|part-comb|phasediff'
    then    
        #phase image, skip detjac normalization, and use nearest neighbout (interporder=0) 
	echo phase image, using nn 
        applyinterp=nn
        isphase=1
    else
	echo non-phase image, using spline 
        applyinterp=spline
        isphase=0
    fi

    if echo $file | grep -qE 'T1map|MP2RAGE|SA2RAGE'
    then    
	echo mp2rage/sa2rage/t1map image, using spline, but skipping jac modulation
        applyinterp=spline
        isqmap=1
    else 
	isqmap=0
    fi
    
    #remove extra file
    rm -vf $intermediate_3d

    #this applies warp to input nifti if 4d
    echo "applying warp to $nii using $applyinterp interpolation with $out_warp"
    echo applywarp -i $nii -o $out_nointcorr -w $out_warp --abs --interp=$applyinterp -r $nii 
    applywarp -i $nii -o $out_nointcorr -w $out_warp --abs --interp=$applyinterp -r $nii 
  
            
        if [ "$isphase" = "0" ]
        then
	    if [ "$isqmap" = 1 ]
	    then
              cp -v $out_nointcorr $out_unwarped
	    else
	    echo "non-phase image, doing detjac modulation and cubic spline overshoot correction"
            #detjac modulation
            echo fslmaths $out_nointcorr -mul $out_detjac $out_unwarped
            fslmaths $out_nointcorr -mul $out_detjac $out_unwarped
            
	    fi
            #perform correction of cubic spline overshoot
            inpaint_iters=3
            echo fslmaths $out_unwarped -thr 0 $out_inpaintmask
            fslmaths $out_unwarped -thr 0 $out_inpaintmask
            echo "starting inpainting at `date`"
            echo ImageMath $dimension $out_unwarped InPaint $out_inpaintmask $inpaint_iters
            ImageMath $dimension $out_unwarped InPaint $out_inpaintmask $inpaint_iters
            echo "done inpainting at `date`"
	    
        else 
	  echo "phase image, so skipping detjac modulation and cubic spline correction (since nn interp)"
         cp -v $out_nointcorr $out_unwarped
        fi

	echo "settings datatype to short and resetting header from original image"

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
            cp -v --no-preserve mode $folder/${file_noext}.$ext $out_folder/$folder
        fi
    done


done #nii

#TODO: add check if existing first to avoid errors in log

for otherfile in `ls ./*.{tsv,json} ./.bidsignore $subj/${searchstring}.{tsv,json} $subj/*/${searchstring}.{tsv,json}`
do
 folder=${otherfile%/*} 
 file=${otherfile##*/}

    if echo $file | grep -q DIS
    then    
        continue
    fi

 cp -v --no-preserve mode $otherfile $out_folder/$folder/$file

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
 
 cp -v --no-preserve mode $otherfile $out_folder/$folder/$file

done

#TO DO: remove *DIS* scans from the _scans.tsv file

done #subj
