#!/usr/bin/env python
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "polars>=1.40.1",
#     "pyarrow>=24.0.0",
# ]
# ///

import argparse
import polars as pl
import datetime as dt
from typing import TextIO

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
        jobinfo[key].append(current_job[key])  # append to list
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
    jobinfo["CPU Utilized"] = [
        time_string_to_delta(item) for item in jobinfo["CPU Utilized"]
    ]
    jobinfo["Job Wall-clock time"] = [
        time_string_to_delta(item) for item in jobinfo["Job Wall-clock time"]
    ]
    jobinfo["Memory Utilized"] = [
        mem_string_to_gb(item) for item in jobinfo["Memory Utilized"]
    ]
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

    # load params file
    params = pl.read_csv(
        args.task_params_file,
        separator="\t",
    ).with_columns(
        pl.col("options").str.replace(r"^\-\-", "").fill_null("None"),
        variant_type = pl.col("sample_id").str.replace(r"^.*\-", ""),
    )

    # load trace file
    trace = pl.read_csv(args.trace_file, separator="\t", infer_schema_length=10000)

    # figure out how to join the tables
    # if the params file has the SLURM job id it is easy
    if "job_id" in params.columns:
        df_all = (
            trace
            .join(params, left_on="native_id", right_on="job_id")
            .join(df_jobinfo, left_on="native_id", right_on="Job ID")
        )
    else:
        # if a job has failed and been rerun the task id won't match in the params file
        # so we need to group by job name
        # get the first value for task_id for each job name
        # rejoin it back to the original trace dataframe
        # then get rid of the second task id and filter for COMPLETED jobs
        original_col_order = trace.columns
        trace = (
            trace.group_by("name", maintain_order=True)
            .first()
            .select(pl.col("name"), pl.col("task_id"))
            .join(trace, "name")
            .select(original_col_order)
            .filter(pl.col("status") == "COMPLETED")
        )

        # join all 3 together
        df_all = trace.join(params, on="task_id").join(
            df_jobinfo, left_on="native_id", right_on="Job ID"
        )

    # output combined table
    (
        df_all.with_columns(
            pl.col(pl.Duration).dt.to_string(format="polars")
        ).write_csv(f"{args.output_base}-results.tsv", separator="\t")
    )

    time_table = (
        df_all.group_by(("variant_type", "buffer_size", "forks", "options"))
        .agg(
            pl.min("Job Wall-clock time").alias("Min(time)").dt.to_string("polars"),
            pl.median("Job Wall-clock time").alias("Median(time)"),
            pl.max("Job Wall-clock time").alias("Max(time)").dt.to_string("polars"),
        )
        .sort("options", "buffer_size", "forks")
    )
    for option in ("None", "everything"):
        # extract baseline runtime value
        baseline_time = (
            time_table
            .filter(pl.col("buffer_size") == 5000, pl.col("forks") == 1, pl.col("options") == option)
            .select("Median(time)")
            .item()
        )
        # subset to option and
        # subtract baseline time from table
        (
            time_table
            .filter(pl.col("options") == option)
            .with_columns(
                (pl.col("Median(time)") - baseline_time).alias("Delta (Time)"),
                (baseline_time/pl.col("Median(time)"))
                .round(1, mode="half_away_from_zero")
                .alias("x Speed up")
            )
            .with_columns(
                pl.col(pl.Duration)
                .dt.total_seconds(fractional=True)
                .round(0, mode="half_away_from_zero")
                .mul(1_000_000)
                .cast(pl.Duration("us"))
                .dt.to_string("polars"),
            )
        ).write_csv(f"{args.output_base}-time-delta-{option}-results.tsv", separator="\t")

    mem_table = (
        df_all.group_by(("variant_type", "buffer_size", "forks", "options"))
        .agg(
            pl.min("Memory Utilized (GB)").alias("Min(mem)"),
            pl.median("Memory Utilized (GB)").alias("Median(mem)")
            .round(2, mode="half_away_from_zero"),
            pl.max("Memory Utilized (GB)").alias("Max(mem)"),
        )
        .sort("options", "buffer_size", "forks")
    )
    for option in ("None", "everything"):
        # extract baseline memory value
        baseline_mem = (
            mem_table
            .filter(pl.col("buffer_size") == 5000, pl.col("forks") == 1, pl.col("options") == option)
            .select("Median(mem)")
            .item()
        )
        # subset to option and
        # subtract baseline mem from table
        (
            mem_table
            .filter(pl.col("options") == option)
            .with_columns(
                (pl.col("Median(mem)") - baseline_mem)
                .round(1, mode="half_away_from_zero")
                .alias("Delta (mem)"),
                (baseline_mem/pl.col("Median(mem)"))
                .round(1, mode="half_away_from_zero")
                .alias("x Mem")
            )
        ).write_csv(f"{args.output_base}-mem-delta-{option}-results.tsv", separator="\t")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Script to join the outputs from the benchmarking pipeline and produce a summary file",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "trace_file",
        metavar="TRACE_FILE",
        type=str,
        help="Input trace file",
    )
    parser.add_argument(
        "task_params_file",
        metavar="TASK_PARAMS_FILE",
        type=str,
        help="Input task parameters file",
    )
    parser.add_argument(
        "seff_file",
        metavar="SEFF_FILE",
        type=str,
        help="Input seff file",
    )
    parser.add_argument(
        "--output_base",
        metavar="OUTFILE_BASE",
        type=str,
        default="time-mem",
        help="Base file name for the output files",
    )
    parser.add_argument(
        "--debug", action="count", default=0, help="Prints debugging information"
    )
    params = parser.parse_args()
    main(params)
