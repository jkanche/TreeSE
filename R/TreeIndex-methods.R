#' Subset TreeIndex
#' @param x TreeIndex to subset
#' @param i,j indices to subset or keep
#' @param ... other params to dataframe subset method
#' @param drop drop the dimensions of the object. defaults to FALSE
#' @importFrom methods callNextMethod
#' @return a `TreeIndex` subset object
#' 
#' @rdname TreeIndex-methods
setMethod("[", "TreeIndex",
          function(x, i, j, ..., drop = FALSE) {
            # obj <- callNextMethod()
            new_hierarchy_tree <-
              unique(x@hierarchy_tree[i, j, ..., drop = drop])
            new_feature_order <- colnames(new_hierarchy_tree)

            TreeIndex(hierarchy = new_hierarchy_tree,
                      feature_order = new_feature_order)
          })

#' Generic method to get nodes at a tree level
#' @param x object
#' @param ... other parameters
#' @examples 
#' library(metagenomeSeq)
#' data(mouseData)
#' counts <- MRcounts(mouseData)
#' hierarchy <- fData(mouseData)
#' tree <- TreeIndex(hierarchy)
#' getNodes(tree)
#' @return a generic
#' 
#' @rdname TreeIndex-methods
setGeneric("getNodes", signature = "x",
           function(x, ...)
             standardGeneric("getNodes"))

#' Method to get nodes at a tree level
#' @param x a TreeIndex object
#' @param selectedLevel tree level to select nodes from
#' @examples 
#' library(metagenomeSeq)
#' data(mouseData)
#' counts <- MRcounts(mouseData)
#' hierarchy <- fData(mouseData)
#' tree <- TreeIndex(hierarchy)
#' getNodes(tree)
#' @export
#' @return levels at node cut
#' 
#' @rdname TreeIndex-methods
setMethod("getNodes", "TreeIndex",
          function(x,
                   selectedLevel = NULL) {

            if (is.null(selectedLevel)) {
              return(x@nodes_table[,c("id", "lineage", "node_label", "level")])
            }
            nodes_at_level <-
              x@nodes_table[level == selectedLevel,]
            nodes_at_level_ids <- nodes_at_level[, id]
            unique(data.frame(ids = nodes_at_level_ids, names = nodes_at_level$node_label))
          })

#' Generic method for possible node states
#' @param x object
#' @return node state
#' @rdname TreeIndex-methods
setGeneric("getNodeStates", signature = "x",
           function(x)
             standardGeneric("getNodeStates"))

#' Method to get possible node states
#' a node state is 0 if removed, 1 if expanded to show children &
#' 2 if counts are aggregated to the node
#' @param x object
#' @return node states
#' @rdname TreeIndex-methods
setMethod("getNodeStates", "TreeIndex",
          function(x) {
            return(list(
              "removed" = 0,
              "expanded" = 1,
              "aggregate" = 2
            ))
          })


#' Generic method to split the tree
#' @param x object
#' @param ... other parameters
#' @examples 
#' \donttest{ 
#' library(metagenomeSeq)
#' data(mouseData)
#' counts <- MRcounts(mouseData)
#' hierarchy <- fData(mouseData)
#' tree <- TreeIndex(hierarchy)
#' splitAt(tree)
#' }
#' @return a generic
#' @rdname TreeIndex-methods
setGeneric("splitAt", signature = "x",
           function(x, ...)
             standardGeneric("splitAt"))

#' splitAt divides the TreeIndex into groups defined by the level,
#' node selections and filters(start, end)
#' @param x TreeIndex object
#' @param selectedLevel tree level to select nodes from
#' @param selectedNodes used to set states on individual nodes to define a cut on the tree
#' @param start,end indices to filter nodes by
#' @param format return format can be one of "list" or "TreeIndex"
#' @importFrom stats na.omit
#' @importFrom methods is
#' @examples 
#' \donttest{ 
#' library(metagenomeSeq)
#' data(mouseData)
#' counts <- MRcounts(mouseData)
#' hierarchy <- fData(mouseData)
#' tree <- TreeIndex(hierarchy)
#' splitAt(tree)
#' }
#' @export
#' @return a `TreeIndex` object or type set in format
#' @rdname TreeIndex-methods
setMethod("splitAt", "TreeIndex",
          function(x,
                   selectedLevel = 3,
                   selectedNodes = NULL,
                   start = 1,
                   end = NULL,
                   format = "list") {
            if (is.null(end)) {
              end <- nrow(x)
            }

            nodes_at_level <-
              x@nodes_table[level == selectedLevel,]
            nodes_at_level_ids <- nodes_at_level[, id]

            if (!is.null(selectedNodes) &&
                !(length(selectedNodes) == 0)) {
              nodes_at_level_selections <- rep(2, length(nodes_at_level_ids))
              names(nodes_at_level_selections) <- nodes_at_level_ids
              selectedNodes <-
                c(selectedNodes, nodes_at_level_selections)

              expand_selections <- which(selectedNodes == 1)
              if (!is.null(expand_selections) &&
                  length(expand_selections) > 0) {
                expand_selection_indices = which(names(selectedNodes) %in% names(expand_selections))
                selectedNodes <-
                  selectedNodes[-expand_selection_indices]
              }

              expanded_children <-
                x@nodes_table[parent %in% names(expand_selections), id]

              child_lineage <-
                x@nodes_table[id %in% names(selectedNodes), ]
              remove_selections <- which(selectedNodes == 0)
              if (length(remove_selections) > 0) {
                kept_nodes <-
                  child_lineage[!grepl(paste(paste(
                    names(remove_selections), collapse = ",|"
                  ), ",", sep = ""), lineage), ]
                kept_nodes <-
                  kept_nodes[!(id %in% names(remove_selections)), ]
              } else {
                kept_nodes <- child_lineage
              }

              agg_selections <- which(selectedNodes == 2)
              if (length(agg_selections) > 0) {
                kept_nodes <-
                  kept_nodes[!grepl(paste(paste(names(
                    agg_selections
                  ), collapse = ",|"), ",", sep = ""), lineage), ]
              }
              kept_nodes <- as.character(kept_nodes[, id])
              nodes_at_level <-
                x@nodes_table[id %in% c(kept_nodes, expanded_children), ]
            }

            leaf_order_table <-
              as.data.table(x@hierarchy_tree[, c(x@feature_order[length(x@feature_order)], "otu_index")])
            setnames(leaf_order_table, c("leaf", "otu_index"))
            leaf_order_table <-
              leaf_order_table[, leaf := as.character(leaf)]
            leaf_order_table <-
              leaf_order_table[otu_index >= start &
                                 otu_index <= end]

            leaf_indices <-
              merge(leaf_order_table,
                    merge(nodes_at_level, x@leaf_of_table, by = "id"),
                    by = "leaf")
            setorderv(leaf_indices, "otu_index.x")
            leaf_indices$lineage.y <- NULL
            leaf_indices$otu_index.y <- NULL
            leaf_indices$node_label.y <- NULL
            colnames(leaf_indices) <-
              c("leaf",
                "otu_index",
                "id",
                "parent",
                "lineage",
                "node_label",
                "level",
                "order")

            if (format == "aggTable") {
              return(leaf_indices)
            }
            else if (format == "TreeIndex") {
              toLevel <- selectedLevel
              new_feature_order <- x@feature_order[seq_len(toLevel)]
              new_hierarchy_tree <-
                unique(x@hierarchy_tree[start:end, new_feature_order])
              new_hierarchy_tree <- na.omit(new_hierarchy_tree)
              groups <-
                unique(leaf_indices[, .(
                  indices = paste0(otu_index, collapse = ","),
                  leaf_nodes = paste0(leaf, collapse = ",")
                ), by = .(id, parent, lineage, node_label, level, order)])
              rownames(new_hierarchy_tree) <- make.names(groups$node_label, unique = TRUE)

              # new_hierarchy_tree <- as.data.frame(unique(as.data.table(new_hierarchy_tree), by=new_feature_order[toLevel]))
              newTreeIndex <-
                TreeIndex(hierarchy = new_hierarchy_tree,
                          feature_order = new_feature_order)
              return(newTreeIndex)
            }
            else if (format == "dataframe") {
              groups <-
                leaf_indices[, .(
                  indices = paste0(otu_index, collapse = ","),
                  leaf_nodes = paste0(leaf, collapse = ",")
                ), by = .(id, parent, lineage, node_label, level, order)]
              return(groups)
            }
            else if (format == "list") {
              groups <-
                unique(leaf_indices[, .(
                  indices = paste0(otu_index, collapse = ","),
                  leaf_nodes = paste0(leaf, collapse = ",")
                ), by = .(id, parent, lineage, node_label, level, order)])
              nodes <- as.list(groups$indices)
              nodes_exp <- lapply(nodes, function(nl) {
                as.integer(strsplit(nl, ",")[[1]])
              })
              names(nodes_exp) <- make.names(groups$node_label, unique = TRUE)
              return(nodes_exp)
            }
          })

#' Show the TreeIndex object
#' @importFrom methods show
#' @param object TreeIndex object
#' @return object description of the `TreeIndex` object
#' @rdname TreeIndex-methods
setMethod("show", "TreeIndex", function(object) {
  cat(
    "Tree Index",
    "with height:",
    length(object@feature_order),
    "\n Tree levels:",
    paste(object@feature_order, collapse = " -> "),
    "\n Leaf nodes:",
    nrow(object),
    sep = " "
  )
})

setAs("DataFrame", "TreeIndex", function(from) {
  as.data.frame(from)
})
