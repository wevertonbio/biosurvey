#' Selection of blocks in environmental space
#'
#' @description Select a user-defined number of blocks in environmental space
#' to be used in further analysis to define sampling sites for a survey system.
#'
#' @param master master_matrix object derived from the function
#' \code{\link{prepare_master_matrix}} or a master_selection object derived
#' from functions \code{\link{random_selection}},
#' \code{\link{uniformG_selection}}, or \code{\link{uniformE_selection}}.
#' @param expected_blocks (numeric) number of blocks to be selected.
#' @param selection_type (character) type of selection. Two options are
#' available: "uniform" and "random". Default = "uniform".
#' @param replicates (numeric) number of thinning replicates performed to
#' select blocks uniformly. Default = 10.
#' @param set_seed (numeric) integer value to specify a initial seed.
#' Default = 1.
#'
#' @details
#' When blocks in \code{master} are defined using the option "equal_points"
#' (see \code{\link{make_blocks}}), "uniform" \code{selection_type} could
#' result in blocks with high density per area being overlooked.
#'
#' @return
#' An S3 object of class master_matrix or master_selection, containing the same
#' elements found in the input object, with an additional column in the
#' master_matrix data.frame containing a binary code for selected (1) and
#' non-selected (0) blocks.
#'
#' @usage
#' block_sample(master, expected_blocks, selection_type = "uniform",
#'              replicates = 10, set_seed = 1)
#'
#' @export
#'
#' @examples
#' # Data
#' data("m_matrix", package = "biosurvey")
#'
#' # Making blocks for analysis
#' m_blocks <- make_blocks(m_matrix, variable_1 = "PC1",
#'                         variable_2 = "PC2", n_cols = 10, n_rows = 10,
#'                         block_type = "equal_area")
#'
#' # Checking column names and values in variables to define initial distance
#' colnames(m_blocks$data_matrix)
#' summary(m_blocks$data_matrix[, c("PC1", "PC2")])
#'
#' # Selecting blocks uniformly in E space
#' block_sel <- block_sample(m_blocks, expected_blocks = 10,
#'                           selection_type = "uniform")
#'
#' head(block_sel$data_matrix)


block_sample <- function(master, expected_blocks, selection_type = "uniform",
                         replicates = 10, set_seed = 1) {
  # Initial tests
  if (missing(master)) {
    stop("Argument 'master' needs to be defined.")
  }
  if (!class(master)[1] %in% c("master_matrix", "master_selection")) {
    stop("Object defined in 'master' is not valid, see function's help.")
  }
  if (is.null(master$data_matrix$Block)) {
    stop("Blocks are not defined in data_matrix, see function 'make_blocks'.")
  } else {
    sel_args <- attributes(master$data_matrix)

    variable_1 <- sel_args$arguments$variable_1
    variable_2 <- sel_args$arguments$variable_2

    coln <- colnames(master$data_matrix)
    if (!variable_1 %in% coln) {
      stop(variable_1, " is not one o the columns in 'master$data_matrix'.")
    }
    if (!variable_2 %in% coln) {
      stop(variable_2, " is not one o the columns in 'master$data_matrix'.")
    }
  }
  if (missing(expected_blocks)) {
    stop("Argument 'expected_blocks' needs to be defined.")
  }
  if (!selection_type[1] %in% c("uniform", "random")) {
    stop("Argument 'selection_type' is not valid, see function's help.")
  }

  # Block selection
  if (selection_type[1] == "uniform") {
    ## Searching for uniformity in E space
    pairs_sel <- uniformE_selection(master, variable_1, variable_2,
                                    selection_from = "block_centroids",
                                    expected_blocks, max_n_samplings = 1,
                                    replicates = replicates,
                                    use_preselected_sites = FALSE,
                                    set_seed = set_seed, verbose = FALSE)
    pairs_sel <- pairs_sel$selected_sites_E$selection_1$Block
  } else {
    ## Randomly
    pairs_sel <- sample(unique(master$data_matrix$Block),
                        expected_blocks)
  }

  # Preparing results
  pairs_sel <- ifelse(master$data_matrix$Block %in% pairs_sel, 1, 0)
  master$data_matrix$Selected_blocks <- pairs_sel

  return(master)
}
