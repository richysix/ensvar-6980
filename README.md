# ensvar-6980
Benchmarking task for Ensembl VEP

The main script (`main.nf`) is a Nextflow pipeline, for running on the compute cluster.
```
Nextflow run -profile codon -params-file sv-params.yaml main.nf
```

The pipeline uses a csv sample sheet to specify the input files. Parameters such as numbers of forks and buffer size can be specified in a YAML file. There are examples in this repository (example-samplesheet.csv and example-params.yaml).

After the pipeline has run there are 2 scripts to collate the data and plot some graphs
```
dir=/path/to/nextflow/dir
type=exome
uv run collate-results.py \
--output_base $dir/reports/$type \
$dir/reports/trace.txt $dir/reports/task-params.tsv $dir/reports/output.seff 

Rscript time-mem-plot.R $dir
```
