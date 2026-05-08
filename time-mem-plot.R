#!/usr/bin/env Rscript

library("optparse")

option_list <- list(
    make_option(c("-d", "--debug"), action = "store_true", default = FALSE,
                help = "Print extra output [default %default]")
)

desc <- paste("Script to plot runtime and memory for ENSVAR-6980 benchmarking", sep = "\n")

if (interactive()) {
    cmd_args <- c() # add test files here
} else {
    cmd_args <- commandArgs(trailingOnly = TRUE)
}
cmd_line_args <- parse_args(
    OptionParser(
        option_list = option_list,
        description = desc,
        usage = "Usage: %prog [options] results_dir"
    ),
    args = cmd_args,
    positional_arguments = 1
)

packages <- c("tidyverse")
for (package in packages) {
    library(package, character.only = TRUE) |>
        suppressWarnings() |>
        suppressPackageStartupMessages()
}

# function to load data file
load_data_file <- function(filename) {
    return(
        read_tsv(
            filename,
            col_types = cols(buffer_size = col_integer())
        ) 
        
    )
}

convert_to_mins <- function(vec) {
    minute_string <- "[0-9]+m"
    minutes <- str_extract(vec, minute_string) |>
        str_remove(pattern = "m") |>
        as.integer() |>
        replace_na(replace = 0)
    hour_string <- "[0-9]+h"
    hours <- str_extract(vec, hour_string) |>
        str_remove(pattern = "h") |>
        as.integer() |>
        replace_na(replace = 0)
    return(hours * 60 + minutes)
}

# load exome data file
exome_data <- load_data_file(
    file.path(cmd_line_args$args[1], "exome", "reports", "exome-results.tsv")) |>
    mutate(
        `Runtime (Minutes)` = convert_to_mins(`Job Wall-clock time`),
        buffer_size = factor(buffer_size, levels = c("5000", "10000", "50000", "100000")),
        options = factor(options, levels = c("None", "everything")),
        forks = factor(forks, levels = c("1", "8", "24", "48"))
    )

output_plot <- function(plot_obj, file_name) {
    png(
        filename = file_name,
        width = 1600,
        height = 1200,
        res = 200
    )
    print(plot_obj)
    invisible(dev.off())
}

time_plot_by_options <- function(data_df) {
    plot <- data_df |>
        ggplot() +
        aes(x = buffer_size, y = `Runtime (Minutes)`, fill = forks) +
        geom_boxplot(outliers = FALSE) +
        scale_fill_manual(values = biovisr::cbf_palette(nlevels(data_df$forks))) +
        scale_x_discrete(name = "Buffer size") +
        facet_wrap(vars(options)) +
        theme_minimal()
    return(plot)
}
time_plot_by_options(exome_data) |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "exome", 
            "reports", 
            "exome-runtime-by-options-plot.png")
    )

time_plot_by_forks <- function(data_df) {
    plot <- data_df |>
        ggplot() +
        aes(x = buffer_size, y = `Runtime (Minutes)`, fill = options) +
        geom_boxplot(outliers = FALSE) +
        scale_fill_manual(values = biovisr::cbf_palette(nlevels(data_df$options))) +
        scale_x_discrete(name = "Buffer size") +
        facet_wrap(vars(forks), labeller = label_both) +
        theme_minimal()
    return(plot)
}
time_plot_by_forks(exome_data) |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "exome", 
            "reports", 
            "exome-runtime-by-forks-plot.png")
    )

mem_plot_by_options <- function(data_df) {
    plot <- data_df |>
        ggplot() +
        aes(x = buffer_size, y = `Memory Utilized (GB)`, fill = forks) +
        geom_boxplot(outliers = FALSE) +
        scale_fill_manual(values = biovisr::cbf_palette(nlevels(data_df$forks))) +
        scale_x_discrete(name = "Buffer size") +
        facet_wrap(vars(options)) +
        theme_minimal()
    return(plot)
}
mem_plot_by_options(exome_data) |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "exome", 
            "reports", 
            "exome-memory-by-options-plot.png")
    )

mem_plot_by_forks <- function(data_df) {
    plot <- data_df |>
        ggplot() +
        aes(x = buffer_size, y = `Memory Utilized (GB)`, fill = options) +
        geom_boxplot(outliers = FALSE) +
        scale_fill_manual(values = biovisr::cbf_palette(nlevels(data_df$options))) +
        scale_x_discrete(name = "Buffer size") +
        facet_wrap(vars(forks), labeller = label_both) +
        theme_minimal()
    return(plot)
}
mem_plot_by_forks(exome_data) |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "exome", 
            "reports", 
            "exome-memory-by-forks-plot.png")
    )

########
# Genome data
# load exome data file
genome_data <- load_data_file(
    file.path(cmd_line_args$args[1], "genome", "reports", "genome-results.tsv")) |>
    mutate(
        `Runtime (Minutes)` = convert_to_mins(`Job Wall-clock time`),
        buffer_size = factor(buffer_size, levels = c("5000", "10000", "50000", "100000")),
        options = factor(options, levels = c("None", "everything")),
        forks = factor(forks, levels = c("1", "8", "24", "48"))
    )

time_plot_by_options(genome_data) |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "genome", 
            "reports", 
            "genome-runtime-by-options-plot.png")
    )

time_plot_by_forks(genome_data) |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "genome", 
            "reports", 
            "genome-runtime-by-forks-plot.png")
    )

genome_data |>
    filter(forks != 1) |>
    time_plot_by_forks() |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "genome", 
            "reports", 
            "genome-runtime-by-forks-gt1-plot.png")
    )

mem_plot_by_options(genome_data) |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "genome", 
            "reports", 
            "genome-memory-by-options-plot.png")
    )

mem_plot_by_forks(genome_data) |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "genome", 
            "reports", 
            "genome-memory-by-forks-plot.png")
    )

##############
# Structural variant data
sv_data <- load_data_file(
    file.path(cmd_line_args$args[1], "sv", "reports", "sv-results.tsv")) |>
    mutate(
        `Runtime (Minutes)` = convert_to_mins(`Job Wall-clock time`),
        buffer_size = factor(buffer_size, levels = c("250", "1250", "2500", "5000", "10000")),
        options = factor(options, levels = c("None", "everything")),
        forks = factor(forks, levels = c("1", "8", "16", "24", "48"))
    )

time_plot_by_options(sv_data) |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "sv", 
            "reports", 
            "sv-runtime-by-options-plot.png")
    )

move_legend <- function(plot_obj) {
    return(
        plot_obj +
            theme(legend.position = c(0.8, 0.3))
    )
}
time_plot_by_forks(sv_data) |>
    move_legend() |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "sv", 
            "reports", 
            "sv-runtime-by-forks-plot.png")
    )

sv_data |>
    filter(forks != 1) |>
    time_plot_by_forks() |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "sv", 
            "reports", 
            "sv-runtime-by-forks-gt1-plot.png")
    )

mem_plot_by_options(sv_data) |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "sv", 
            "reports", 
            "sv-memory-by-options-plot.png")
    )

mem_plot_by_forks(sv_data) |>
    move_legend() |>
    output_plot(file_name = 
        file.path(
            cmd_line_args$args[1], 
            "sv", 
            "reports", 
            "sv-memory-by-forks-plot.png")
    )

# Plot runtime speed up
# load summary files
load_summary_file <- function(type, options) {
    file_name <- file.path(
        cmd_line_args$args[1], 
        type, 
        "reports", 
        glue::glue("{type}-time-delta-{options}-results.tsv")
    )
    df <- read_tsv(
            file_name, 
            col_types = cols(
                variant_type = col_factor(),
                buffer_size = col_factor(levels = as.character(as.integer(c(250, 1250, 2500, 5000, 10000, 50000, 100000)))),
                forks = col_factor(levels = as.character(c(1, 8, 16, 24, 48))),
                options = col_factor()
            )
        )
    return(df)
}
params <- expand_grid(type = c("exome", "genome", "sv"), options = c("None", "everything"))

all_data <- map2(params$type, params$options, load_summary_file) |>
    list_rbind()

line_colours <- biovisr::cbf_palette(x = 8)[c(1:3,5:8)]
summary_plot <- all_data |>
    ggplot() +
    aes(
        x = forks,
        y = `x Speed up`,
        colour = buffer_size,
        group = interaction(variant_type, buffer_size)
    ) +
    geom_line(linewidth = 1) +
    geom_point() +
    scale_color_manual(values = line_colours) +
    facet_grid(rows = vars(variant_type), cols = vars(options)) +
    theme_minimal() +
    theme(strip.background = element_rect(fill = "#cccccc"))

output_plot(summary_plot, file.path(cmd_line_args$args[1], "time-fold-change.png"))

# AUTHOR
#
# Richard White <rich.white@cantab.net>
#
# COPYRIGHT AND LICENSE
#
# This software is Copyright (c) 2026 EMBL-European Bioinformatics Institute
#
# This is free software, licensed under:
#
#  The GNU General Public License, Version 3, June 2007
