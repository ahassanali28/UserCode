#!/bin/bash

WHAT=$1; 
ERA=$2;
if [ "$#" -ne 2 ]; then 
    echo "steerTOPWidthAnalysis.sh <SEL/MERGESEL/PLOTSEL/WWWSEL/ANA/MERGE/PLOT/WWW>";
    echo "        WORKSPACE       - create a workspace with the TopHypoTest model";
    echo "        SCAN            - scans the likelihood";
    echo "        CLs             - calculates CLs using higgs_combine";
    echo "        TOYS            - plots toys and saves locally";
    echo "        MERGE_DATACARDS - merge all datacards for one LFS/WID into one WID datacard";
    echo "        QUANTILES       - plots the quantiles chart for all distributions, by lepton final state";
    echo "        WWW             - moves the analysis plots to an afs-web-based area";
    echo " "
    echo "        ERA          - era2015/era2016";
    exit 1; 
fi

outdir=/afs/cern.ch/work/e/ecoleman/public/TopWidth/TopWidth_${ERA}_808p1
cardsdir=/afs/cern.ch/work/e/ecoleman/public/TopWidth/TopWidth_${ERA}_808p1/datacards
wwwdir=~/www/TopWidth_${ERA}/
CMSSW_7_4_7dir=~/CMSSW_7_4_7/src/
CMSSW_7_6_3dir=~/CMSSW_8_0_8_patch1/src/

lumi=2267.84
unblind=false
nPseudo=1000

lfs=(EE EM MM)
wid=(0p5w 1p0w 1p5w 2p0w 2p5w 3p0w 3p5w 4p0w 4p5w 5p0w)
dists=(mdrmlb minmlb incmlb sncmlb mt2mlb)
tdists=(mt2mlb)
cat=(1b 2b)
lbCat=(highpt lowpt)

RED='\e[31m'
NC='\e[0m'


distStr=""
lfsStr=""
widStr=""
for dist in ${dists[*]}
do
    if [[ "${distStr}" == "" ]];
    then
        distStr="${dist}"
    else
        distStr="${distStr},${dist}"
    fi
done

for tlfs in ${lfs[*]} ; do
    if [[ "${lfsStr}" == "" ]];
    then
        lfsStr="${tlfs}"
    else
        lfsStr="${lfsStr},${tlfs}"
    fi
done

for twid in ${wid[*]} ; do
    if [[ "${widStr}" == "" ]];
    then
        widStr="${twid}"
    else
        widStr="${widStr},${twid}"
    fi
done
       


case $WHAT in
    SHAPES )
        cd ${CMSSW_7_4_7dir}
        eval `scramv1 runtime -sh`
        cd ${CMSSW_7_6_3dir}/TopLJets2015/TopAnalysis/
        export PYTHONPATH=$PYTHONPATH:/usr/lib64/python2.6/site-packages/
        nohup python test/TopWidthAnalysis/createShapesFromPlotter.py \
                -s tbart,tW \
                --dists ${distStr} \
                -o ${outdir}/datacards/ \
                -i ${outdir}/analysis/plots/plotter.root \
                --systInput ${outdir}/analysis/plots/syst_plotter.root \
                --nomorph &
    ;;
    MORPHALL )
        cd ${CMSSW_7_4_7dir}
        eval `scramv1 runtime -sh`
        cd ${CMSSW_7_6_3dir}/TopLJets2015/TopAnalysis/
        export PYTHONPATH=$PYTHONPATH:/usr/lib64/python2.6/site-packages/

        # for each width, generate a truth dataset and produce the proper morph datacards for it
        # --> output in datacards_<wid>/
        for twid in ${wid[*]}; do
           rm -rf ${outdir}/datacards_${twid}
           nohup python test/TopWidthAnalysis/createShapesFromPlotter.py \
                   -s tbart,tW \
                   --dists ${distStr} \
                   -o ${outdir}/datacards_${twid}/ \
                   -i ${outdir}/analysis/plots/plotter.root \
                   --systInput ${outdir}/analysis/plots/syst_plotter.root \
                   --truth ${twid} &
        done
    ;;
    2DBIAS )
        cd ${CMSSW_7_4_7dir}
        eval `scramv1 runtime -sh`

        # Merge datacards
        for twid in ${wid[*]}; do
        for dist in ${dist[*]}; do
            cmd="python ${CMSSW_7_4_7dir}/HiggsAnalysis/CombinedLimit/scripts/combineCards.py "

            for tlbCat in ${lbCat[*]} ; do
            for tlfs in ${lfs[*]} ; do
            for tCat in ${cat[*]} ; do
                cardname="${tlbCat}${tlfs}${tCat}=${outdir}/datacards_${twid}/datacard_widfit__${tlbCat}${tlfs}${tCat}_${dist}.dat"
                cmd="${cmd} ${cardname} "
            done
            done
            done
        done
        done
            cmd="${cmd} > ${outdir}/datacards_${twid}/datacard_widfit__${twid}_${dist}.dat"
            eval `${cmd}`

        # Get workspaces 
        for twid in ${wid[*]}; do 
        for dist in ${dist[*]}; do
            cd ${outdir}/datacards_${twid}
            text2workspace.py ${outdir}/datacards_${twid}/datacard_widfit__${twid}_${dist}.dat \
                -o ${outdir}/datacards_${twid}/workspace_biascheck_${twid}_${dist}.root
        done
        done
       
        # Run combine
        for twid in ${wid[*]}; do 
        for dist in ${dist[*]}; do
            cd ${outdir}/datacards_${twid}
            combine ${outdir}/datacards_${twid}/workspace_biascheck_${twid}_${dist}.root \
                -M MultiDimFit --expectSignal=1 --poi r --poi alpha --poi beta \
                --setPhysicsModelParameterLimits alpha=0,9:beta=0,2 \
                --algo=grid --points=1000
        done
        done
    ;;
    MERGE_DATACARDS )
        cd ${CMSSW_7_4_7dir}
        eval `scramv1 runtime -sh`
        for dist in ${dists[*]} ; do
        for twid in ${wid[*]} ; do

        if [[ "${twid}" == "1p0w" ]] ; then
            continue
        fi

        # for a given width, merge all
        allcmd="python ${CMSSW_BASE}/src/HiggsAnalysis/CombinedLimit/scripts/combineCards.py "
        for tlbCat in ${lbCat[*]} ; do

            # for a given width and lbcat, merge all
            lbccmd="python ${CMSSW_BASE}/src/HiggsAnalysis/CombinedLimit/scripts/combineCards.py "
            for tlfs in ${lfs[*]} ; do

                # for a given width, lfs, and lbcat, merge all
                lfscmd="python ${CMSSW_BASE}/src/HiggsAnalysis/CombinedLimit/scripts/combineCards.py "
                for tCat in ${cat[*]} ; do
                    ## TODO: Address this tWttinterf "bad bin" 
                    #if [[ "${tlbCat}${tlfs}${tCat}" == "lowptMM1b" ]]; then
                    #    echo "Skipping lowptMM1b"
                    #    continue
                    #fi
                    #if [[ "${tlbCat}${tlfs}${tCat}" == "highptEM1b" ]]; then
                    #    echo "Skipping lowptMM1b"
                    #    continue
                    #fi
                    cardname="${tlbCat}${tlfs}${tCat}=${cardsdir}/datacard__${twid}_${tlbCat}${tlfs}${tCat}_${dist}.dat"
                    allcmd="${allcmd} ${cardname} "
                    lbccmd="${lbccmd} ${cardname} "
                    lfscmd="${lfscmd} ${cardname} "
                done

                #echo $lfscmd
                #echo " "
                lfscmd="${lfscmd} > ${cardsdir}/datacard__${twid}_${tlbCat}${tlfs}_${dist}.dat"
            done

            #echo $lbccmd
            #echo " "
            lbccmd="${lbccmd} > ${cardsdir}/datacard__${twid}_${tlbCat}_${dist}.dat"
        done

        #echo $allcmd
        #echo " "
        allcmd="${allcmd} > ${cardsdir}/datacard__${twid}_${dist}.dat"
            
        eval $allcmd
        eval $lbccmd
        eval $lfscmd

        done
        done
    ;;
    WORKSPACE )
        cd ${CMSSW_7_4_7dir}
        eval `scramv1 runtime -sh`
        mkdir ${outdir}
        for dist in ${dists[*]} ; do
        for twid in ${wid[*]} ; do
        #for tlfs in ${lfs[*]} ; do
        #for tlbCat in ${lbCat[*]} ; do
        #for tcat in ${cat[*]} ; do
        #   #echo "Creating workspace for ${twid}${tlfs}${dist}" 
        #   # text2workspace.py ${cardsdir}/datacard__${twid}_${tlbCat}${tlfs}${tcat}_${dist}.dat -P \
        #   #     HiggsAnalysis.CombinedLimit.TopHypoTest:twoHypothesisTest \
        #   #     -m 172.5 --PO verbose --PO altSignal=${twid} --PO muFloating \
        #   #     -o ${outdir}/${twid}_${tlbCat}${tlfs}${tcat}_${dist}.root
        #done
        #done
        #done
            
            # All datacards
            echo "Creating workspace for ${twid}${dist}" 
            text2workspace.py ${cardsdir}/datacard__${twid}_${dist}.dat -P \
                HiggsAnalysis.CombinedLimit.TopHypoTest:twoHypothesisTest \
                -m 172.5 --PO verbose --PO altSignal=${twid} --PO muFloating \
                -o ${outdir}/${twid}_${dist}.root 
        done
        done
    ;;
    SCAN )
        cd ${CMSSW_7_4_7dir}
        eval `scramv1 runtime -sh`
        cd ${outdir}
        for dist in ${dists[*]} ; do
        for twid in ${wid[*]} ; do

        if [[ "${twid}" == "1p0w" ]] ; then
            continue
        fi

        #for tlfs in ${lfs[*]} ; do
        #for tlbCat in ${lbCat[*]} ; do
        #for tcat in ${cat[*]} ; do
        #   # echo "combining for ${tlbCat}${tlfs}${tcat}"
        #   # combine ${outdir}/${twid}_${tlbCat}${tlfs}${tcat}_${dist}.root -M MultiDimFit \
        #   #     -m 172.5 -P x --floatOtherPOI=1 --algo=grid --points=200 \
        #   #     -t -1 --expectSignal=1 --setPhysicsModelParameters x=0,r=1 \
        #   #     -n x0_scan_Asimov_${twid}_${tlbCat}${tlfs}${tcat}_${dist}
        #done
        #done
        #done

            # All datacards
            combine ${outdir}/${twid}_${dist}.root -M MultiDimFit \
                -m 172.5 -P x --floatOtherPOI=1 --algo=grid --points=200 \
                -t -1 --expectSignal=1 --setPhysicsModelParameters x=0,r=1 \
                -n x0_scan_Asimov_${twid}_${dist}
        done
        done
    ;;
    CLs )
        cd ${CMSSW_7_4_7dir}
        eval `scramv1 runtime -sh`
        cd ${outdir}
        for dist in ${tdists[*]} ; do
        for twid in ${wid[*]} ; do

        if [[ "${twid}" == "1p0w" ]] ; then
            continue
        fi

        #for tlfs in ${lfs[*]} ; do
        #for tlbCat in ${lbCat[*]} ; do
        #for tcat in ${cat[*]} ; do
        #    #echo "combining for ${tlbCat}${tlfs}${tcat}"
        #    #combine ${outdir}/${twid}_${tlbCat}${tlfs}${tcat}_${dist}.root -M HybridNew --seed 8192 --saveHybridResult \
        #    #    -m 172.5  --testStat=TEV --singlePoint 1 -T ${nPseudo} -i 2 --fork 6 \
        #    #    --clsAcc 0 --fullBToys  --generateExt=1 --generateNuis=0 \
        #    #    --expectedFromGrid 0.5 -n x_pre-fit_exp_${twid}_${tlbCat}${tlfs}${tcat}_${dist} \
        #    #    &> ${outdir}/x_pre-fit_exp_${twid}_${tlbCat}${tlfs}${tcat}_${dist}.log
        #done
        #done
        #done

            # All datacards
            echo "Making CLs for ${twid}${dist}"
            nohup combine ${twid}_${dist}.root -M HybridNew --seed 8192 --saveHybridResult \
                -m 172.5  --testStat=TEV --singlePoint 1 -T ${nPseudo} -i 2 --fork 6 \
                --clsAcc 0 --fullBToys  --generateExt=1 --generateNuis=0 \
                --expectedFromGrid 0.5 -n x_pre-fit_exp_${twid}_${dist} \
                &> ${outdir}/x_pre-fit_exp__${twid}_${dist}.log &
        done
        done
    ;;
    TOYS )
        cd ${CMSSW_7_4_7dir}
        eval `scramv1 runtime -sh`
        cd ${outdir}
        for dist in ${dists[*]} ; do
        for twid in ${wid[*]} ; do

        if [[ "${twid}" == "1p0w" ]] ; then
            continue
        fi

        for tlfs in ${lfs[*]} ; do
        for tlbCat in ${lbCat[*]} ; do
        for tcat in ${cat[*]} ; do
            cd ${outdir}
            # each lfs datacard
            #root -l -q -b higgsCombinex_pre-fit_exp_${twid}_${tlfs}_${dist}.HybridNew.mH172.5.8192.quant0.500.root \
            #    "${CMSSW_7_6_3dir}/TopLJets2015/TopAnalysis/test/TopWidthAnalysis/hypoTestResultTreeTopWid.cxx(\"x_pre-fit_exp_${twid}_${tlfs}_${dist}.qvals.root\",172.5,1,\"x\",1000,\"${tlfs}\",\"${twid}\",\"${dist}\",${unblind})"
        done
        done
        done
            
            # All datacards
            root -l -q -b higgsCombinex_pre-fit_exp_${twid}_${dist}.HybridNew.mH172.5.8192.quant0.500.root \
                "${CMSSW_7_6_3dir}/TopLJets2015/TopAnalysis/test/TopWidthAnalysis/hypoTestResultTreeTopWid.cxx(\"x_pre-fit_exp__${twid}_${dist}.qvals.root\",172.5,1,\"x\",1000,\"\",\"${twid}\",\"${dist}\",${unblind})"
        done
        done
    ;;
    QUANTILES )
        cd ${outdir}
        #for dist in ${dists[*]} ; do
        #    #python ${CMSSW_7_6_3dir}/TopLJets2015/TopAnalysis/test/TopWidthAnalysis/getQuantilesPlot.py \
        #    #    -i ${outdir}/ -o ${outdir}/ \
        #    #    --lfs ${lfsStr} --wid ${widStr} \
        #    #    --dist ${dist} 

        #    # All datacards
        #    python ${CMSSW_7_6_3dir}/TopLJets2015/TopAnalysis/test/TopWidthAnalysis/getQuantilesPlot.py \
        #        -i ${outdir}/ -o ${outdir}/ \
        #        --wid ${widStr} \
        #        --dist ${dist}
        #    
        #    # Get Separation plots / LaTeX tables as well
        #    python ${CMSSW_7_6_3dir}/TopLJets2015/TopAnalysis/test/TopWidthAnalysis/getSeparationTables.py\
        #        -i ${outdir}/ -o ${outdir}/ \
        #        --wid ${widStr} \
        #        --dist ${dist}
        #done
        
        # Get Separation plots / LaTeX tables as well
        python ${CMSSW_7_6_3dir}/TopLJets2015/TopAnalysis/test/TopWidthAnalysis/getSeparationTables.py\
            -i ${outdir}/ -o ${outdir}/ \
            --dist ${distStr} \
            --doAll
    ;;
    WWW )
        mkdir -p ${wwwdir}/ana_${ERA}
        cp ${outdir}/analysis/plots/*.{png,pdf} ${wwwdir}/ana_${ERA} 
        cp ${outdir}/*.{png,pdf} ${wwwdir}/ana_${ERA} 
        cp test/index.php ${wwwdir}/ana_${ERA}
	;;
    FULL )
        thisFileLoc="${CMSSW_7_6_3dir}/TopLJets2015/TopAnalysis/test/TopWidthAnalysis/steerTOPWidthAnalysis.sh"
        sh ${thisFileLoc} SHAPES ${ERA}
        sh ${thisFileLoc} MERGE_DATACARDS ${ERA}
        sh ${thisFileLoc} WORKSPACE ${ERA}
        #sh ${thisFileLoc} SCAN ${ERA}
        #sh ${thisFileLoc} CLs ${ERA}
        #sh ${thisFileLoc} TOYS ${ERA}
        #sh ${thisFileLoc} QUANTILES ${ERA}
        sh ${thisFileLoc} WWW ${ERA}
    ;;
esac
