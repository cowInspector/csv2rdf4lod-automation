#!/bin/bash
#
# Usage:
#    (pwd: source/DDD, e.g. source/data-gov):
#
#    cr-rerun-convert-sh.sh --layer raw 1623
#       deletes automatic/* and only runs the raw conversion.
#
#    cr-rerun-convert-sh.sh 1623
#       same as `cr-rerun-convert-sh.sh --layer e1 1623`
#
#    cr-rerun-convert-sh.sh --layer e1 1623
#       if raw conversion is NOT in automatic/, runs the raw conversion
#       if raw conversion is     in automatic/, runs the e1  conversion
#
#    cr-rerun-convert-sh.sh --layer raw `cr-list-sources-datasets.sh`
#
#    todo:
#       deletes publish/* (not automatic/*) and runs ./convert-1263.sh in all version directories.

if [ "$1" == "--help" ]; then
   echo "usage: `basename $0` [-w] [--layer {raw,e1,e2,...,cr:ALL}] [-sourceDir {source,manual}] <cr:ALL | datasetID [datasetID]*>"
   echo ""
   echo "Remove everything in:"
   echo " source/SSS/DDD/version/VVV/automatic/* and"
   echo " source/SSS/DDD/version/VVV/publish/* "
   echo ""
   echo "Rerun raw and all enhancement conversions using"
   echo " source/SSS/DDD/version/VVV/automatic/convert-DDD.sh if it is present."
   echo ""
   echo "   -w:         prevent dry run; actually run scripts."
   echo "   --layer:    conversion identifier to publish (raw, e1, e2, ...) (if not specified, converts all layers.)"
   echo "   -sourceDir: if specified, replace source/SSS/DDD/version/VVV/automatic/convert-DDD.sh "
   echo "               with a newly-generated convert-DDD.sh for CSVs in the {source,manual} directory."
   echo ""
   echo "Invoke from source/SSS to re-convert the given conversion layers for the given dataset-ids."
   echo "Invoke from source/    to re-convert the given conversion layers for the given dataset-ids from all sources."
   exit 1
fi

CSV2RDF4LOD_HOME=${CSV2RDF4LOD_HOME:?"not set; source csv2rdf4lod/source-me.sh or see https://github.com/timrdf/csv2rdf4lod-automation/wiki/CSV2RDF4LOD-not-set"}

# cr:data-root cr:source cr:directory-of-datasets cr:dataset cr:directory-of-versions cr:conversion-cockpit
ACCEPTABLE_PWDs="cr:data-root cr:source cr:dataset cr:conversion-cockpit"
if [ `${CSV2RDF4LOD_HOME}/bin/util/is-pwd-a.sh $ACCEPTABLE_PWDs` != "yes" ]; then
   cr-pwd.sh
   cr-pwd-type.sh
   ${CSV2RDF4LOD_HOME}/bin/util/pwd-not-a.sh $ACCEPTABLE_PWDs
   exit 1
fi

orig_params="$*"

TEMP="_"`basename $0``date +%s`_$$.tmp

if [[ `is-pwd-a.sh cr:data-root` == "yes" ]]; then
   echo "  Rerunning conversions for all `cr-list-sources.sh | wc -l` sources."
   for source in `cr-list-sources.sh`; do
      pushd $source &>/dev/null
         echo "##############################################`echo $source | sed 's/./#/g'`##############################################"
         echo "##############################################`echo $source | sed 's/./#/g'`##############################################"
         echo "############################################# $source #############################################"
         echo "############################################# `echo $source | sed 's/./ /g'` #############################################"
         echo "############################################# `echo $source | sed 's/./ /g'` #############################################"
         $0 $* # Run this same script now that we are in the source/ directory, using the same params we were given.
      popd &>/dev/null
   done
elif [[ `is-pwd-a.sh cr:source` == "yes" ]]; then
   for dataset in `cr-list-sources-datasets.sh -s`; do
      pushd $dataset &>/dev/null
         $0 $* # Run this same script with the same params we were given.
      popd &>/dev/null
   done
elif [[ `is-pwd-a.sh cr:dataset` == "yes" ]]; then
   for version in `cr-list-versions.sh`; do
      pushd version/$version &>/dev/null
         $0 $* # Run this same script with the same params we were given.
      popd &>/dev/null
   done
elif [[ `is-pwd-a.sh cr:conversion-cockpit` == "yes" ]]; then

   dryRun="true"
   if [ "$1" == "-w" ]; then
      dryRun="false"
      shift 
   fi

   focusLayer="cr:ALL"
   if [ "$1" == "--layer" ]; then
      focusLayer="$2"
      shift 2
   fi

   # This was needed when first transitioning to the csv2rdf4lod file organization,
   # when the CSVs were in place but no conversion triggers (convert-*.sh) existed.
   csvLoc=""
   if [ "$1" == "-sourceDir" ]; then
      csvLoc="$2"
      shift 2
   fi

   if [ "$dryRun" == "true" ]; then
      echo ""
      echo "WARNING: Only performing dryrun; add -w parameter to actually convert.)"
      echo ""
   fi

   echo "orig params: $orig_params"

   source=`cr-source-id.sh`
   datasetID=`cr-dataset-id.sh`
   version=`cr-list-versions.sh`
 
   echo "`cr-pwd.sh` ($source - $datasetID - $version)"
   echo

#   if [ ${focusLayer:-"."} == "raw" -o ${focusLayer:-"."} == "cr:ALL" ]; then
#      echo "`basename $0` removing $automaticDir/*"
#      if [ ${dryRun:-"."} != "true" ]; then
#         rm automatic/* &> /dev/null
#      fi
#   fi
#   echo "`basename $0` removing publish/*"
#   if [ ${dryRun:-"."} != "true" ]; then
#      #rm publish/* &> /dev/null
#      #touch manual/*.params.ttl
#   fi

   if [ -e convert-$datasetID.sh ]; then
      for conversionIdentifier in `cr-list-enhancement-identifiers.sh`; do  # e.g. "1", "2" (not "e1", "e2")
         if [ $conversionIdentifier == "raw" -o $conversionIdentifier == "1" ]; then
            eFlag=""
         else
            eFlag="-e $conversionIdentifier"
         fi
         if [ ${#focusLayer} -eq 0 -o "$focusLayer" == "cr:ALL" ]; then
            # No focus layer was specified, so process all of them.
            echo "    `basename $0` pulling conversion trigger for layer $conversionIdentifier: ./convert-$datasetID.sh $eFlag"
            if [ "$dryRun" != "true" ]; then
               ./convert-$datasetID.sh $eFlag
            fi
         elif [ ${focusLayer} == $conversionIdentifier ]; then
            # Process only the requested focus conversion.
            echo "    `basename $0` pulling conversion trigger for layer $conversionIdentifier: ./convert-$datasetID.sh $eFlag"
            if [ ${dryRun:-"."} != "true" ]; then
               ./convert-$datasetID.sh $eFlag
            fi
         else
            echo "    `basename $0` skipping   layer: $conversionIdentifier b/c given parameter '--layer $focusLayer'"
         fi
      done
   elif [[ "$csvLoc" == "manual" || \
           "$csvLoc" == "source" ]]; then
      # There was no conversion trigger, and we were asked to create one if it wasn't here.
      #
      # Create convert-DDD.sh
      #
      # This was added for bulk processing of datasets where csvs were placed into manual/
      # and no attention was paid to their individual conversion.
      echo "`basename $0` making new convert-DDD.sh"
      if [ ${dryRun:-"."} != "true" ]; then
         cr-create-convert-sh.sh -w $csvLoc/*[Cc][Ss][Vv]
      else 
         echo "INFO: `basename $0` convert-$datasetID.sh does not exist; not running conversion."
      fi
   fi
fi
