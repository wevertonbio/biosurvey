#' Sample points from a 2D environmental space
#'
#' @description Sample one or more points from a two dimensional environmental
#' space according to a selection rule and with the possibility of having
#' distinct sets of points to be sampled independently.
#'
#' @param data matrix or data.frame that contains at least four columns:
#' "Longitude" and "Latitude" to represent geographic position, and two other
#' columns to represent the variables of the 2D environmental space.
#' @param variable_1 (character or numeric) name or position of the first
#' variable (x-axis).
#' @param variable_2 (character or numeric) name or position of the second
#' variable (y-axis). Must be different from the first one.
#' @param n (numeric) number of points to be selected. If \code{id_column} is
#' defined this argument indicates the number of points per set. Default = 1.
#' @param select_point (character) how or which point will be selected. Three
#' options are available: "random", "E_centroid", and "G_centroid". E_ or G_
#' centroid indicate that the point(s) closest to the respective centroid will
#' be selected. Default = "E_centroid".
#' @param id_column (character or numeric) name or numeric index of the column
#' in \code{data} containing identifiers of one or distinct sets of points.
#' If, NULL, the default, only one set is assumed.
#'
#' @return
#' A data.frame containing \code{n} rows corresponding to the point or points
#' that were sampled.
#'
#' @usage
#' point_sample(data, variable_1, variable_2, n = 1,
#'              select_point = "E_centroid", id_column = NULL)
#'
#' @export
#'
#' @examples
#' # Data
#' data("m_matrix", package = "biosurvey")
#'
#' # Sampling points
#' points_s <- point_sample(m_matrix$data_matrix,
#'                          variable_1 = "Max_temperature",
#'                          variable_2 = "Min_temperature", n = 1,
#'                          select_point = "E_centroid", id_column = NULL)
#'
#' points_s


point_sample <- function(data, variable_1, variable_2, n = 1,
                         select_point = "E_centroid", id_column = NULL) {
  # Initial tests
  if (missing(data)) {
    stop("Argument 'data' must be defined.")
  }
  if (missing(variable_1)) {
    stop("Argument 'variable_1' must be defined.")
  }
  if (missing(variable_2)) {
    stop("Argument 'variable_2' must be defined.")
  }
  coln <- colnames(data)
  if (!variable_1 %in% coln) {
    stop(variable_1, " is not one o the columns in 'data'.")
  }
  if (!variable_2 %in% coln) {
    stop(variable_2, " is not one o the columns in 'data'.")
  }
  if (!select_point[1] %in% c("random", "E_centroid", "G_centroid")) {
    stop("Argument 'select_point' is not valid, options are:\n'random', 'E_centroid', 'G_centroid'")
  }

  # Preparing data
  e_cols <- c(variable_1, variable_2)
  g_cols <- c("Longitude", "Latitude")
  bda <- data[, id_column]
  bs <- unique(bda)

  # Random option
  if (select_point[1] == "random") {
    samp <- lapply(bs, function(x) {
      bd <- data[bda == x, ]
      bd <- bd[sample(1:nrow(bd), n), ]
      unique(bd)
    })
    bsam <- do.call(rbind, samp)
    colnames(bsam) <- colnames(data)
  }

  # E centroid option
  if (select_point[1] == "E_centroid") {
    bsam <- closest_to_centroid(data, e_cols[1], e_cols[2], space = "E", n = n,
                                id_column = id_column)
  }

  # G centroid option
  if (select_point[1] == "G_centroid") {
    bsam <- closest_to_centroid(data, g_cols[1], g_cols[2], space = "G", n = n,
                                id_column = id_column)
  }

  return(bsam)
}





#' Unimodality test for list of one or multiple sets of values
#'
#' @description Test of unimodality based in Hartigans' dip statistic D.
#' Calculations of the statistic and p-value are done as in
#' \code{\link[diptest]{dip.test}}.
#'
#' @param values_list named list of vectors of class numeric. Names in
#' \code{values_list} are required. If only one set of values is used the list
#' must contain only one element.
#' @param MC_replicates (numeric) number of replicates for the Monte Carlo test
#' to calculate p-value. Default = 1000.
#'
#' @return
#' A data.frame with the results of the test.
#'
#' @usage
#' unimodal_test(values_list, MC_replicates= 1000)
#'
#' @export
#' @importFrom diptest dip.test
#'
#' @examples
#' # Data
#' data("dist_list", package = "biosurvey")
#'
#' # Testing unimodality
#' u_test <- unimodal_test(values_list = dist_list, MC_replicates = 500)
#' u_test


unimodal_test <- function(values_list, MC_replicates= 1000) {
  # Initial tests
  if (missing(values_list)) {
    stop("Argument 'values_list' must be defined.")
  }

  # Preparing data
  bs <- names(values_list)

  # Tests in loop
  dss <- lapply(bs, function(x) {
    ds <- values_list[[x]]

    if (length(ds) <= 2) {
      return(data.frame(Block = x, D = NA, p_alue = NA))
    } else {
      dp <- diptest::dip.test(ds, simulate.p.value = TRUE, B = MC_replicates)
      return(data.frame(Block = x, D = dp$statistic, p_alue = dp$p.value))
    }
  })

  return(do.call(rbind, dss))
}





#' Find modes in a multimodal distribution
#'
#' @description Find modes in a multimodal distribution of values based on the
#' density of such values.
#'
#' @param density object of class density obtained using the function
#' \code{\link{density}}.
#'
#' @return
#' A data.frame containing the values corresponding to the modes and the
#' density for those particular values.
#'
#' @usage
#' find_modes(density)
#'
#' @export
#'
#' @examples
#' # Data
#' data("dist_list", package = "biosurvey")
#'
#' dens <- density(dist_list$`12`)
#'
#' # Finding modes
#' modes <- find_modes(density = dens)
#' modes


find_modes <- function(density) {
  # Initial tests
  if (missing(density)) {
    stop("Argument 'density' must be defined.")
  }

  # Preparing data
  density_y <- density$y
  modes <- NULL

  # Finding modes in loop
  for (i in 2:(length(density_y) - 1)) {
    if ((density_y[i] > density_y[i - 1]) & (density_y[i] > density_y[i + 1])) {
      modes <- c(modes, i)
    }
  }

  # Returning results in a data.frame
  if ( length(modes) == 0 ) {
    message("This is a monotonic distribution. Returning NA.")
    return(data.frame(mode = NA, density = NA))
  } else {
    return(data.frame(mode = density$x[modes], density = density_y[modes]))
  }
}






#' Detection of clusters in 2D spaces
#'
#' @description Finds clusters of data in two dimensions based on distinct
#' methods.
#'
#' @param data matrix or data.frame that contains at least two columns.
#' @param x_column (character) the name of the x-axis.
#' @param y_column (character) the name of the y-axis.
#' @param space (character) space in which the thinning will be performed.
#' There are two options available: "G", if it will be in the geographic space,
#' and "E", if it will be in the environmental space.
#' @param cluster_method (character) name of the method to be used for detecting
#' clusters. Options are "hierarchical" and "k-means"; default = "hierarchical".
#' @param split_distance (numeric) distance in meters (if \code{space} = "G")
#' or Euclidean distance (if \code{space} = "E") to identify clusters if
#' \code{cluster_method} = "hierarchical".
#' @param n_k_means (numeric) number of clusters to be identified when using the
#' "k-means" in \code{cluster_method}.
#'
#' @return
#' A data frame containing \code{data} and an additional column defining
#' clusters.
#'
#' @details
#' Clustering methods make distinct assumptions and one of them may perform
#' better than the other depending on the pattern of the data.
#'
#' The k-means method tends to perform better when data are grouped spatially
#' (spherically) and clusters are of a similar size. The hierarchical
#' clustering algorithm usually takes more time than the k-means method. Both
#' methods make assumptions and may work well on some data sets but fail
#' on others.
#'
#' @usage
#' find_clusters(data, x_column, y_column, space,
#'               cluster_method = "hierarchical", n_k_means = NULL,
#'               split_distance = NULL)
#'
#' @export
#' @importFrom stats hclust cutree kmeans dist as.dist
#' @importFrom terra distance
#'
#' @examples
#' # Data
#' data("m_matrix", package = "biosurvey")
#'
#' # Cluster detection
#' clusters <-  find_clusters(m_matrix$data_matrix, x_column = "PC1",
#'                            y_column = "PC2", space = "E",
#'                            cluster_method = "hierarchical", n_k_means = NULL,
#'                            split_distance = 4)
#' head(clusters)


find_clusters <- function(data, x_column, y_column, space,
                          cluster_method = "hierarchical",
                          n_k_means = NULL, split_distance = NULL) {
  # Initial tests
  if (missing(data)) {
    stop("Argument 'data' must be defined.")
  }
  if (missing(x_column)) {
    stop("Argument 'x_column' must be defined.")
  }
  if (missing(y_column)) {
    stop("Argument 'y_column' must be defined.")
  }
  coln <- colnames(data)
  if (!x_column %in% coln) {
    stop(x_column, " is not one o the columns in 'data'.")
  }
  if (!y_column %in% coln) {
    stop(y_column, " is not one o the columns in 'data'.")
  }
  if (missing(space)) {
    stop("Argument 'space' is not defined.")
  }

  if (cluster_method %in% c("hierarchical", "k-means")) {
    if (cluster_method[1] == "hierarchical") {
      # Finding clusters hierarchically by distance
      if (is.null(split_distance)) {
        stop("Argument 'split_distance' must be defined if 'cluster_method' = 'hierarchical'.")
      }

      if (space == "E") {
        ## In E
        cluster <- stats::hclust(dist(data[, c(x_column, y_column)]),
                                 method = "complete")
      } else {
        ## In G
        cluster <- stats::hclust(as.dist(
          terra::distance(x = data[, c(x_column, y_column)], lonlat = TRUE)),
                                 method = "complete")
      }

      ## Vector defining clusters
      cluster_vector <- stats::cutree(cluster, h = split_distance)

    } else {
      if (is.null(n_k_means)) {
        stop("Argument 'n_k_means' must be defined if 'cluster_method' = 'k-means'.")
      }

      ## Vector defining clusters
      set.seed(1)
      cluster_vector <- stats::kmeans(as.matrix(data[, c(x_column, y_column)]),
                                      n_k_means)$cluster
    }
  } else {
    stop("Argument 'cluster_method' is not valid.")
  }

  # Returning results
  data <- data.frame(data, clusters = cluster_vector)
  return(data)
}





#' Sample points from a 2D environmental space potentially disjoint in
#' geography
#'
#' @description Sample one or more points from a two-dimensional environmental
#' space according to a selection rule and with the possibility of having
#' distinct sets of points to be sampled independently. Points to be sampled
#' can be disjoint in geographic space and when that happens two points are
#' selected considering the most numerous clusters.
#'
#' @param data matrix or data.frame that contains at least four columns:
#' "Longitude" and "Latitude" to represent geographic position, and two other
#' columns to represent the variables of the 2D environmental space.
#' @param variable_1 (character or numeric) name or position of the first
#' variable (x-axis).
#' @param variable_2 (character or numeric) name or position of the second
#' variable (y-axis). Must be different from the first one.
#' @param n (numeric) number of points to be selected. If \code{id_column} is
#' defined this argument indicates the number of points per set. Default = 1.
#' @param distance_list list of vectors of geographic distances among all
#' points. If \code{id_column} is not defined, only one element in the list is
#' needed, otherwise, \code{distance_list} must contain as many elements as
#' unique IDs in \code{id_column}. In the latter case, the names in
#' \code{distance_list} must match the IDs in \code{id_column}.
#' @param n (numeric) number of points that are close to the centroid to be
#' detected. Default = 1.
#' @param cluster_method (character) there are two options available:
#' "hierarchical" and "k-means". Default = "hierarchical".
#' @param select_point (character) how or which point will be selected. Three
#' options are available: "random", "E_centroid", and "G_centroid". E_ or G_
#' centroid indicate that the point(s) closest to the respective centroid will
#' be selected. Default = "E_centroid".
#' @param id_column (character or numeric) name or numeric index of the column
#' in \code{data} containing identifiers of one or distinct sets of points.
#' If, NULL, the default, only one set is assumed.
#'
#' @return
#' A data.frame containing \code{n} rows corresponding to the point or points
#' that were sampled.
#'
#' @usage
#' point_sample_cluster(data, variable_1, variable_2, distance_list,
#'                      n = 1, cluster_method = "hierarchical",
#'                      select_point = "E_centroid", id_column = NULL)
#'
#' @export
#' @importFrom stats density
#'
#' @examples
#' # Data
#' data("m_matrix", package = "biosurvey")
#' data("dist_list", package = "biosurvey")
#'
#' # Making blocks for analysis
#' m_blocks <- make_blocks(m_matrix, variable_1 = "PC1", variable_2 = "PC2",
#'                         n_cols = 10, n_rows = 10, block_type = "equal_area")
#'
#' datam <- m_blocks$data_matrix
#' datam <- datam[datam$Block %in% names(dist_list), ]
#'
#' # Sampling points
#' point_clus <- point_sample_cluster(datam, variable_1 = "PC1",
#'                                    variable_2 = "PC2",
#'                                    distance_list = dist_list, n = 1,
#'                                    cluster_method = "hierarchical",
#'                                    select_point = "E_centroid",
#'                                    id_column = "Block")


point_sample_cluster <- function(data, variable_1, variable_2, distance_list,
                                 n = 1, cluster_method = "hierarchical",
                                 select_point = "E_centroid",
                                 id_column = NULL) {
  # Initial tests
  if (missing(data)) {
    stop("Argument 'data' must be defined.")
  }
  if (missing(variable_1)) {
    stop("Argument 'variable_1' must be defined.")
  }
  if (missing(variable_2)) {
    stop("Argument 'variable_2' must be defined.")
  }
  coln <- colnames(data)
  if (!variable_1 %in% coln) {
    stop(variable_1, " is not one o the columns in 'data'.")
  }
  if (!variable_2 %in% coln) {
    stop(variable_2, " is not one o the columns in 'data'.")
  }
  if (!select_point[1] %in% c("random", "E_centroid", "G_centroid")) {
    stop("Argument 'select_point' is not valid, options are:\n'random', 'E_centroid', 'G_centroid'")
  }
  if (missing(distance_list)) {
    stop("Argument 'distance_list' must be defined")
  }
  if (!cluster_method[1] %in% c("hierarchical", "k-means")) {
    stop("Argument 'cluster_method' is not valid.")
  }

  # Preparing data
  bda <- data[, id_column]
  bs <- unique(bda)

  mgsel <- lapply(bs, function(x) {
    # Finding modes
    md <- suppressMessages(find_modes(density = density(distance_list[[as.character(x)]])))

    if (nrow(md) > 1) {
      # Defining clusters for locks with more than one mode
      dens <- md$density
      mdss <- md[order(dens), ]
      dd <- abs(diff(mdss[(length(dens) - 1):length(dens), 1]))

      clush <- find_clusters(data = data[bda == x, ], "Longitude", "Latitude",
                             space = "G", cluster_method = cluster_method,
                             split_distance = dd)

      # Sampling blocks according to most numerous clusters
      sel <- as.numeric(names(sort(table(clush$clusters), decreasing = T)[1:2]))

      bse <- point_sample(data = clush[clush$clusters %in% sel, ],
                          variable_1, variable_2, n = n,
                          select_point = select_point, id_column = "clusters")
      bse$clusters <- NULL
    } else {
      # Sampling if unimodal
      bse <- point_sample(data = data[bda == x, ], variable_1, variable_2,
                          n = n, select_point = select_point,
                          id_column = id_column)
    }
    return(bse)
  })
  mgsel <- do.call(rbind, mgsel)

  # Returning results
  return(mgsel)
}

