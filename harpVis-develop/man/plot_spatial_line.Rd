% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_spatial_line.R
\name{plot_spatial_line}
\alias{plot_spatial_line}
\title{Plot "basic" scores that have only one value column such as MSE, bias, MAE etc.}
\usage{
plot_spatial_line(
  plot_data,
  score_name,
  point_size = 1.2,
  extend_y_to_zero = TRUE,
  line_width = 1,
  y_label = "auto",
  x_label = "auto",
  flip_axes = FALSE,
  ...
)
}
\arguments{
\item{plot_data}{A tibble from \code{plot_spatial_verif} that contains necessary scores.}

\item{score_name}{Name of the score to plot. Necessary (compared to other plotting functions)
since it will be used to select the respective table that contains the scores.}

\item{point_size}{The size of points to plot.}

\item{extend_y_to_zero}{Logical. Whether to extend the y-axis to include
zero.}

\item{line_width}{The width of lines to plot. The default is 1.}

\item{y_label}{Label for the y-axis. Set to "auto" to use score name. Anything else inside
quotes will be used as the y-axis label.}

\item{x_label}{Label for the x-axis. Set to "auto" to use "Forecast length".
Anything else inside quotes will be used as the x-axis label.}

\item{flip_axes}{Logical of whether to swap the x and y axes.}
}
\description{
Plot "basic" scores that have only one value column such as MSE, bias, MAE etc.
}
