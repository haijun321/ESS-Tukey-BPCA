#!/usr/bin/env Rscript
# Own I/O adapter. The original author's numerical functions are loaded from
# a separately downloaded, SHA256-pinned file, not reimplemented here.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4L) stop("Expected: mode official_source work_directory R_library")
mode <- args[[1L]]
official_source <- args[[2L]]
work <- args[[3L]]
user_library <- args[[4L]]
required <- c("argparse", "rTensor", "Rcpp", "cellWise", "ggplot2", "RcppArmadillo",
              "devtools", "OmicsPLS", "combinat", "fastmatrix", "Matrix", "abind",
              "rrcov", "robustbase", "scales", "reshape2", "RSpectra")
if (dir.exists(user_library)) .libPaths(c(user_library, .libPaths()))
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]

if (mode == "install") {
  dir.create(user_library, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(user_library, .libPaths()))
  if (length(missing)) {
    install.packages(missing, lib = user_library, repos = "https://cloud.r-project.org", dependencies = TRUE)
  }
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop(paste("Packages still unavailable:", paste(missing, collapse = ", ")))
  cat("DEPENDENCIES_INSTALLED\n")
  quit(save = "no", status = 0L)
}
if (length(missing)) {
  cat("BLOCKED_MISSING_R_PACKAGES:", paste(missing, collapse = ", "), "\n")
  quit(save = "no", status = 21L)
}
if (!file.exists(official_source)) stop("Original author ROMPCA source is absent")
if (mode == "check") {
  cat("R_VERSION|", R.version.string, "\n", sep = "")
  for (pkg in required) cat("PACKAGE_VERSION|", pkg, "|", as.character(packageVersion(pkg)), "\n", sep = "")
  cat("R_DEPENDENCIES_PRESENT_NOT_A_FIT_VALIDATION\n")
  quit(save = "no", status = 0L)
}
if (mode != "fit") stop("Unknown bridge mode")

for (pkg in required) suppressPackageStartupMessages(library(pkg, character.only = TRUE))
E <- new.env(parent = globalenv())
expressions <- parse(official_source, encoding = "UTF-8")
for (expression in expressions) {
  # The source's top-level installer is an environment-changing convenience,
  # not part of ROMPCA. It is deliberately disabled in scientific runs.
  is_installer <- is.call(expression) && is.symbol(expression[[1L]]) &&
    identical(as.character(expression[[1L]]), "install_if_missing")
  if (!is_installer) eval(expression, envir = E)
}

d <- scan(file.path(work, "dimensions.txt"), quiet = TRUE)
if (length(d) != 8L || any(!is.finite(d))) stop("Invalid input dimensions")
p <- as.integer(d[[1L]]); q <- as.integer(d[[2L]]); n <- as.integer(d[[3L]])
r <- as.integer(d[[4L]]); c <- as.integer(d[[5L]])
seed <- as.integer(d[[6L]]); max_itr <- as.integer(d[[7L]]); tolerance <- d[[8L]]
if (min(p, q, n, r, c, max_itr) < 1L || r >= p || c >= q || tolerance <= 0) stop("Invalid input rank/budget")
connection <- file(file.path(work, "X.bin"), "rb")
values <- readBin(connection, "double", n = p * q * n, size = 8L, endian = "little")
close(connection)
if (length(values) != p * q * n || any(!is.finite(values))) stop("Incomplete/nonfinite tensor")
X <- array(values, dim = c(p, q, n))
rm(values)

# The author's example defines these symbols in the surrounding workspace.
# ROMPCA references N in its diagnostic section even with ranks supplied.
E$N <- n
E$dimension <- dim(X)
set.seed(seed)

# Observe the native initialization comparison without changing its output.
native_compare <- E$init.scale.comp
initializations <- list()
algorithm_start <- proc.time()[["elapsed"]]
initialization_seconds <- NA_real_
E$init.scale.comp <- function(X, b = 1.5, init, m.name = NULL) {
  value <- native_compare(X, b = b, init = init, m.name = m.name)
  if (!is.null(m.name)) {
    initializations[[m.name]] <<- list(value = as.numeric(value), V = init$V, Center = init$Center)
    initialization_seconds <<- proc.time()[["elapsed"]] - algorithm_start
  }
  value
}

# silent=FALSE is native and necessary: the author's L1 initialization calls
# setTxtProgressBar without guarding it. Output is captured by the MATLAB log.
fit <- E$ROMPCA(X = X, ranks = c(r, c), b = 1.5, max_itr = max_itr,
                tol = tolerance, delta = 1e-5, cut_out = FALSE, silent = FALSE)
algorithm_seconds <- proc.time()[["elapsed"]] - algorithm_start
if (!length(initializations)) stop("Native initialization record was not captured")
best <- which.min(vapply(initializations, function(a) a$value[[1L]], numeric(1)))
init <- initializations[[best]]
mean_image <- if (!is.null(fit$Center.corr)) fit$Center.corr else fit$Center
outputs <- list(U = fit$V[[1L]], V = fit$V[[2L]], mean = mean_image,
                U0 = init$V[[1L]], V0 = init$V[[2L]], mean0 = init$Center)
expected <- c(p * r, q * c, p * q, p * r, q * c, p * q)
for (j in seq_along(outputs)) {
  a <- as.double(outputs[[j]])
  if (length(a) != expected[[j]] || any(!is.finite(a))) stop(paste("Invalid native output", names(outputs)[[j]]))
  connection <- file(file.path(work, paste0(names(outputs)[[j]], ".bin")), "wb")
  writeBin(a, connection, size = 8L, endian = "little")
  close(connection)
}
metadata <- data.frame(
  Key = c("iterations", "converged", "algorithm_seconds", "initialization_seconds", "seed", "max_outer",
          "tolerance", "b", "native_initialization", "R_version", "mean_convention"),
  Value = c(as.character(fit$itr), as.character(as.integer(isTRUE(fit$converged))),
            format(algorithm_seconds, digits = 17L), format(initialization_seconds, digits = 17L),
            as.character(seed), as.character(max_itr), format(tolerance, digits = 17L), "1.5",
            names(initializations)[[best]], R.version.string,
            if (!is.null(fit$Center.corr)) "Center.corr" else "Center"),
  stringsAsFactors = FALSE)
write.csv(metadata, file.path(work, "metadata.csv"), row.names = FALSE)
loss <- as.data.frame(fit$loss)
if (ncol(loss) == 2L) names(loss) <- c("Iteration", "NativeLoss")
write.csv(loss, file.path(work, "loss.csv"), row.names = FALSE)
versions <- data.frame(Package = required, Version = vapply(required, function(pkg) as.character(packageVersion(pkg)), character(1)))
write.csv(versions, file.path(work, "package_versions.csv"), row.names = FALSE)
cat("ROMPCA_NATIVE_FIT_FINISHED\n")
