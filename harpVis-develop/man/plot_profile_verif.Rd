% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_profile_verif.R
\name{plot_profile_verif}
\alias{plot_profile_verif}
\title{Plot verification scores for vertical profiles}
\usage{
plot_profile_verif(
  verif_data,
  score,
  y_axis = "p",
  lead_time = NA,
  plot_num_cases = TRUE,
  num_cases_position = c("right", "left"),
  ...
)
}
\arguments{
\item{verif_data}{The verification data.}

\item{score}{The score to be plotted. Must be unquoted.}

\item{y_axis}{The y axis for the plot. Must be unquoted. Be default this is
p, for pressure on the y axis, otherwise it should be set to the column
name in \code{verif_data} that you wish to use for the y axis.}

\item{lead_time}{The leadtime (or leadtimes) to plot. By default all lead
times in the data are plotted. If more than one lead time is to be plotted,
they must be separated by setting \code{colour_by = leadtime} and / or
\code{facet_by = vars(leadtime)}. See \link{plot_point_verif} for details
of these arguments.}

\item{plot_num_cases}{Logical of whether to inlclude a panel for the number
of cases. Note that the number of cases will not be plotted if
\code{facet_by} is set.}

\item{num_cases_position}{The position of the number of cases panel relative
to the score panel. For profile scores, this can only be "left", or
"right".}

\item{...}{Other arguments for \link{plot_point_verif}.}
}
\value{
A \link[ggplot2]{ggplot} object of vertical profiles of verification
scores.
}
\description{
This is a wrapper for \link{plot_point_verif} that ensures the coordinate
system is properly set up for plots of verification scores for vertical
profiles.
}
\examples{
# Not filtering or faceting results in overplotting
plot_profile_verif(verif_data_prf, bias)

# Facet by lead_time
plot_profile_verif(verif_data_prf, bias, facet_by = vars(lead_time))

# Remove rows with few cases using filter_by
plot_profile_verif(
  verif_data_prf,
  bias,
  facet_by = vars(lead_time),
  filter_by = vars(num_cases > 1)
)

# Filter to only a single panel
plot_profile_verif(verif_data_prf, bias, filter_by = vars(lead_time == 24))

}
