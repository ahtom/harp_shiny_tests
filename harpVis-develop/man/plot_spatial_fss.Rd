% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_spatial_fss.R
\name{plot_spatial_fss}
\alias{plot_spatial_fss}
\title{Plot FSS scores}
\usage{
plot_spatial_fss(
  plot_data,
  score_name = "FSS",
  flip_axes = FALSE,
  colour_by = "fss",
  point_size = 1.2,
  line_width = 1,
  num_facet_cols = NULL,
  ...
)
}
\arguments{
\item{plot_data}{A tibble from \code{plot_spatial_verif} that contains necessary scores.}

\item{score_name}{Name of the score to plot. Technically not really necessary
but makes it more intuitive when calling from \code{plot_spatial_verif}.}

\item{flip_axes}{Logical of whether to swap the x and y axes.}

\item{colour_by}{The column to colour the plot lines by.
Can be an option between the score ("fss"), scale or threshold.}

\item{point_size}{The size of points to plot.}

\item{line_width}{The width of lines to plot. The default is 1.}

\item{num_facet_cols}{Number of columns in the faceted plot.}
}
\description{
Plot FSS scores
}
