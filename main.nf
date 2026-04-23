#!/usr/bin/env nextflow

process ENSEMBLVEP_VEP {
    label 'process_medium'
    cpus "${forks}"

    input:
    tuple val(meta), path(vcf), val(buffer_size), val(forks)
    val assembly
    val species
    val cache_version
    path(cache)
    path(fasta)
    each iter

    output:
    tuple val(meta), path("*.vep.vcf.gz"), emit: vep_out
    tuple val(meta), path("*.vep.out"), emit: out_file
    tuple val("${task.index}"), val("${meta.id}"), val(buffer_size), val(forks), emit: process_info
    path("task-${task.index}-${iter}-params.csv"), emit: params_file

    script:
    def args = task.ext.args ?: ''
    def vep_out = "${meta.id}.vep.vcf.gz"
    def out_file = "${meta.id}.vep.out"
    def dir_cache = cache ? "${cache}" : "/.vep"
    def reference = fasta ? "--fasta ${fasta}" : ""
    """
    echo "${task.index},${iter},${meta.id},${buffer_size},${forks}" > task-${task.index}-${iter}-params.csv

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

process COLLECT_PARAMS_DATA {
    executor 'local'
    publishDir 'reports', pattern: "task-params.csv", mode: 'copy'

    input:
    path("task-*-params.csv")

    output:
    path('task-params.csv')

    script:
    """
    cat <( echo "task_id,iteration,sample_id,buffer_size,forks" ) task-*-params.csv > task-params.csv
    """
}

workflow {

    main:

    ch_parameters = channel.fromList(params.buffer_size)
        .combine(channel.fromList(params.forks))

    ch_samplesheet = channel.fromPath(params.input)
            .splitCsv(header: true)
            .map { row ->
                        [ [id: row.id], file(row.input_file) ]
            }
            .combine(ch_parameters)

    loop = Channel.from(1..params.repeat)

    ENSEMBLVEP_VEP(
        ch_samplesheet,
        params.assembly,
        params.species,
        params.cache_version,
        file(params.cache),
        file(params.fasta),
        loop
    )

    ch_params_files = ENSEMBLVEP_VEP.out.params_file
        .collect()
    COLLECT_PARAMS_DATA(
        ch_params_files
    )

    if (params.verbose) {
        ch_parameters.view { x -> "Buffer size and forks: $x" }
        ch_samplesheet.view { x -> "Input info: $x" }
        ENSEMBLVEP_VEP.out.vep_out.view { x -> "VEP output vcf: $x" }
        ENSEMBLVEP_VEP.out.out_file.view { x -> "VEP output file: $x" }
        ENSEMBLVEP_VEP.out.process_info.view { x -> "Process info: $x" }
        ENSEMBLVEP_VEP.out.params_file.view { x -> "Params file: $x" }
    }
}
