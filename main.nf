#!/usr/bin/env nextflow

process ENSEMBLVEP_VEP {
    label 'process_medium'

    input:
    tuple val(meta), path(vcf), val(buffer_size), val(forks)
    val assembly
    val species
    val cache_version
    path(cache)
    path(fasta)

    output:
    tuple val(meta), path("*.vep.vcf.gz"), emit: vep_out
    tuple val(meta), path("*.vep.out"), emit: out_file

    script:
    def args = task.ext.args ?: ''
    def vep_out = "${meta.id}.vep.vcf.gz"
    def out_file = "${meta.id}.vep.out"
    def dir_cache = cache ? "${cache}" : "/.vep"
    def reference = fasta ? "--fasta ${fasta}" : ""
    """
    vep ${args} \\
        --i ${vcf} \\
        -o ${vep_out} \\
        --buffer_size ${buffer_size} \\
        --fork ${forks} \\
        --offline --vcf --compress_output bgzip \\
        --assembly ${assembly} \\
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

    ch_parameters = channel.fromList(params.buffer_size)
        .combine(channel.fromList(params.forks))
        .view()

    ch_samplesheet = channel.fromPath(params.input)
            .splitCsv(header: true)
            .map { row ->
                        [ [id: row.id], file(row.input_file) ]
            }
            .combine(ch_parameters)
            .view()

    ENSEMBLVEP_VEP(
        ch_samplesheet,
        params.assembly,
        params.species,
        params.cache_version,
        file(params.cache),
        file(params.fasta)
    )

    ENSEMBLVEP_VEP.out.vep_out.view()
    ENSEMBLVEP_VEP.out.out_file.view()

}
