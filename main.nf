#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
//include { ENSEMBLVEP_VEP } from './modules/nf-core/ensemblvep/vep/main'

process ENSEMBLVEP_VEP {
    label 'process_medium'

    input:
    tuple val(meta), path(vcf)
    val genome
    val species
    val cache_version
    path(cache)
    path(fasta)

    output:
    tuple val(meta), path("*.vep.vcf"), emit: vep_out
    tuple val(meta), path("*.vep.out"), emit: out_file

    script:
    def args = task.ext.args ?: '--vcf'
    def vep_out = "${meta.id}.vep.vcf"
    def out_file = "${meta.id}.vep.out"
    def dir_cache = cache ? "${cache}" : "/.vep"
    def reference = fasta ? "--fasta ${fasta}" : ""
    """
    vep \\
        --i ${vcf} \\
        -o ${vep_out} \\
        ${args} \\
        --assembly ${genome} \\
        --species ${species} \\
        --cache \\
        --cache_version ${cache_version} \\
        --dir_cache ${dir_cache} \\
        --stats_text \\
        --fasta ${fasta} \\
        > ${out_file} 2>&1
    """
}

workflow {

    main:

    ENSEMBLVEP_VEP(
        [
            [id: "NA12878-subset"],
            file("NA12878-subset.vcf.gz")
        ],
        params.assembly,
        params.species,
        params.cache_version,
        file(params.cache),
        file(params.fasta)
    )

    ENSEMBLVEP_VEP.out.vep_out.view()
    ENSEMBLVEP_VEP.out.out_file.view()

}
