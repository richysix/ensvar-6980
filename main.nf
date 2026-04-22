#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/



/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { ENSEMBLVEP_VEP } from './modules/nf-core/ensemblvep/vep/main'

workflow {

    main:

    ENSEMBLVEP_VEP(
        [
            [id: "test"],
            "NA12878-chr1.vcf.gz",
            ""
        ],
        "GRCh38",
        "homo_sapiens",
        115,
        [
            [id: "test"],
            "/nfs/production/flicek/ensembl/variation/data/VEP"
        ],
        [
            [id: "test"],
            "/nfs/production/flicek/ensembl/variation/data/fasta/Homo_sapiens.GRCh38.dna.primary_assembly.fa"
        ]
    )

    ENSEMBLVEP_VEP.view()
}
