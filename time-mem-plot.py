#!/usr/bin/env python
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "plotnine>=0.15.3",
#     "polars>=1.40.1",
#     "pyarrow>=24.0.0",
# ]
# ///

import argparse
import polars as pl
import datetime as dt
from typing import TextIO
import plotnine as p9
#from great_tables import GT, md, html

def create_empty_job() -> dict:
    return {
        "Job ID": None,
        "Cores": None,
        "CPU Utilized": None,
        "Job Wall-clock time": None,
        "Memory Utilized": None,
    }


def add_job_to_jobinfo(current_job: dict, jobinfo: dict) -> dict:
    for key in current_job.keys():
        jobinfo[key].append(current_job[key]) # append to list
    return jobinfo


def time_string_to_delta(string: str) -> dt.timedelta:
    h, m, s = string.split(":")
    if "-" in h:
        d, h = h.split("-")
    else:
        d = 0
    (d, h, m, s) = (int(x) for x in (d, h, m, s))
    return dt.timedelta(days=d, hours=h, minutes=m, seconds=s)


def mem_string_to_gb(string: str) -> float:
    multiplier = {
        "GB": 1024 * 1024 * 1024,
        "MB": 1024 * 1024,
        "KB": 1024,
    }
    value, unit = string.split(" ")
    bytes = float(value) * multiplier[unit]
    return bytes / multiplier["GB"]


def convert_data_types(jobinfo: dict) -> dict:
    jobinfo["Job ID"] = [int(item) for item in jobinfo["Job ID"]]
    jobinfo["CPU Utilized"] = [time_string_to_delta(item) for item in jobinfo["CPU Utilized"]]
    jobinfo["Job Wall-clock time"] = [time_string_to_delta(item) for item in jobinfo["Job Wall-clock time"]]
    jobinfo["Memory Utilized"] = [mem_string_to_gb(item) for item in jobinfo["Memory Utilized"]]
    return jobinfo


def parse_seff_file(seff_fh: TextIO) -> dict:
    jobinfo = {
        "Job ID": [],
        "Cores": [],
        "CPU Utilized": [],
        "Job Wall-clock time": [],
        "Memory Utilized": [],
    }
    current_job = create_empty_job()
    for line in seff_fh:
        if line == "\n":
            continue
        category, value = line.rstrip().split(": ")
        if category == "Job ID":
            # new record
            # add job to jobinfo dict
            if current_job["Job ID"] is not None:
                jobinfo = add_job_to_jobinfo(current_job, jobinfo)
                # new empty job
                current_job = create_empty_job()
        elif category == "Cores per node":
            category = "Cores"

        if category in current_job:
            current_job[category] = value

    jobinfo = add_job_to_jobinfo(current_job, jobinfo)
    jobinfo = convert_data_types(jobinfo)

    return jobinfo


def main(args: dict) -> None:
    # load and parse seff file
    with open(args.seff_file) as seff_fh:
        jobinfo = parse_seff_file(seff_fh)
    df_jobinfo = pl.DataFrame(jobinfo)
    df_jobinfo = df_jobinfo.rename({"Memory Utilized": "Memory Utilized (GB)"})

    # load trace file
    trace = pl.read_csv(
        args.trace_file,
        separator="\t",
        infer_schema_length=10000
    )
    # if a job has failed and been rerun the task id won't match in the params file
    # so we need to group by job name
    # get the first value for task_id for each job name
    # rejoin it back to the original trace dataframe
    # then get rid of the second task id and filter for COMPLETED jobs
    trace = trace.group_by("name", maintain_order=True
    ).first(
    ).select(pl.col("name"), pl.col("task_id")
    ).join(trace, "name"
    ).select(pl.all().exclude("task_id_right")
    ).filter(pl.col("status") == "COMPLETED"
    )

    # load params file
    params = pl.read_csv(
        args.task_params_file,
        separator="\t",
    )
    # work out categories
    buffer_categories = [str(buffer) for buffer in sorted(set(params["buffer_size"].to_list()))]
    fork_categories = [str(fork) for fork in sorted(set(params["forks"].to_list()))]
    # reload data with categories
    params = pl.read_csv(
        args.task_params_file,
        separator="\t",
        schema_overrides={
            "buffer_size": pl.Enum(buffer_categories),
            "forks": pl.Enum(fork_categories)
        }
    ).with_columns(
        pl.col("sample_id").str.replace(r"^.*\-", "")
    )

    # join all 3 together
    df_all = params.join(
        trace, on="task_id"
    ).join(
        df_jobinfo,
        left_on="native_id",
        right_on="Job ID"
    )
    # output combined table
    (
        df_all
            .with_columns(pl.col(pl.Duration).dt.to_string(format="polars"))
            .write_csv(f"{args.output_base}-results.tsv", separator="\t")
    )

    # plot time amd mem stats
    time_boxplot = (
        p9.ggplot(data=df_all,
            mapping=p9.aes(x="buffer_size", y="Job Wall-clock time", fill="factor(options, categories=('None', '--everything'))"))
            + p9.geom_boxplot(outlier_shape="")
            + p9.geom_point(position=p9.position_dodge2(width=0.5))
            + p9.scale_fill_manual(name="Options", values=("#0073B3", "#CC6600"))
            + p9.facet_wrap("forks")
            + p9.theme(legend_position=(0.9, 0.25))
    )

    time_boxplot.save(
        f"{args.output_base}.time.png",
        width=6,
        height=4,
        dpi=200
    )

    mem_boxplot = (
        p9.ggplot(data=df_all,
            mapping=p9.aes(x="buffer_size", y="Memory Utilized (GB)", fill="factor(options, categories=('None', '--everything'))"))
            + p9.geom_boxplot(outlier_shape="")
            + p9.geom_point(position=p9.position_dodge2(width=0.5))
            + p9.scale_fill_manual(name="Options", values=("#0073B3", "#CC6600"))
            + p9.facet_wrap("forks")
    )
    mem_boxplot.save(
        f"{args.output_base}.mem.png",
        width=6,
        height=4,
        dpi=200
    )

    time_table = (
        df_all
            .group_by(("sample_id", "buffer_size", "forks", "options"))
            .agg(
                pl.min("Job Wall-clock time").alias("Min(time)").dt.to_string("polars"),
                pl.median("Job Wall-clock time").alias("Median(time)").dt.total_seconds(fractional=True).round(0, mode="half_away_from_zero").mul(1_000_000).cast(pl.Duration("us")).dt.to_string("polars"),
                pl.max("Job Wall-clock time").alias("Max(time)").dt.to_string("polars")
            )
            .sort("sample_id", "buffer_size", "forks")
    )
    print(time_table)
    #GT(time_table)

    mem_table = (
        df_all
            .group_by(("sample_id", "buffer_size", "forks", "options"))
            .agg(
                pl.min("Memory Utilized (GB)").alias("Min(mem)"),
                pl.median("Memory Utilized (GB)").alias("Median(mem)"),
                pl.max("Memory Utilized (GB)").alias("Max(mem)")
            )
            .sort("sample_id", "buffer_size", "forks")
    )
    print(mem_table)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Script to plot time and memory usage',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('trace_file', metavar='TRACE_FILE',
        type=str, default='reports/trace.txt',
        help='Input trace file')
    parser.add_argument('task_params_file', metavar='TASK_PARAMS_FILE',
        type=str, default='reports/task-params.tsv',
        help='Input task parameters file')
    parser.add_argument('seff_file', metavar='SEFF_FILE',
        type=str, default='reports/output.seff',
        help='Input seff file')
    parser.add_argument('--output_base', metavar='OUTFILE_BASE',
        type=str, default="time-mem",
        help='Base file name for the output files')
    parser.add_argument('--debug', action='count', default=0,
        help='Prints debugging information')
    params = parser.parse_args()
    main(params)
