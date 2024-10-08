# Load necessary libraries
library(tidyverse)
library(readr)
library(dplyr)
library(stats)

# Load the dataset
data <- read_csv("output/VAERS_preprocessed.csv")

# Convert relevant columns to binary numeric for correlation analysis
convert_to_binary <- function(x) {
    if (is.character(x)) {
        return(as.numeric(!is.na(x)))
    } else {
        return(as.numeric(x))
    }
}

data <- data %>%
    mutate(across(c(DIED, L_THREAT, HOSPITAL, DISABLE), convert_to_binary))

# Check the first few rows to ensure correct conversion
head(data)

# Function to calculate feature optimality using Spearman’s Rho correlation
feature_optimality <- function(fv1, fv2) {
    # Rank the feature vectors
    rv1 <- rank(fv1)
    rv2 <- rank(fv2)

    # Calculate means
    M1 <- mean(rv1)
    M2 <- mean(rv2)

    # Subtract means from ranks
    rmd1 <- rv1 - M1
    rmd2 <- rv2 - M2

    # Calculate sum-differentiation (covariance)
    SD12 <- sum(rmd1 * rmd2)
    covariance <- SD12 / length(rv1)

    # Calculate standard deviations
    sigma1 <- sd(rv1)
    sigma2 <- sd(rv2)

    # Calculate Spearman’s rank correlation
    R <- covariance / (sigma1 * sigma2)

    # Calculate optimality
    optimality <- 1 - R
    return(optimality)
}

# Function to perform feature optimization for all feature pairs
optimize_features <- function(data) {
    features <- colnames(data)
    n <- length(features)
    optimal_scores <- matrix(NA, nrow = n, ncol = n)

    # Calculate optimality scores for all feature pairs
    for (i in 1:(n - 1)) {
        for (j in (i + 1):n) {
            optimal_scores[i, j] <- feature_optimality(data[[i]], data[[j]])
            optimal_scores[j, i] <- optimal_scores[i, j] # symmetry
        }
    }

    return(optimal_scores)
}

# Define labels
labels <- c("DIED", "L_THREAT", "HOSPITAL", "DISABLE")

# Initialize a list to store optimal features for each label
optimal_features_list <- list()

# For each label, calculate optimal feature scores
for (label in labels) {
    # Extract relevant data for the current label (where the label is TRUE)
    data_label <- subset(data, data[[label]] == TRUE)

    # Ensure the data only contains feature columns
    feature_data <- select(data_label, -one_of(labels)) # Exclude all label columns

    # Calculate optimal scores
    optimal_scores <- optimize_features(feature_data)

    # Calculate the optimality score coefficient for each feature set
    osF <- rowMeans(optimal_scores, na.rm = TRUE) # Mean of the optimal scores

    deviation <- apply(optimal_scores, 1, sd, na.rm = TRUE) # Deviation of the optimal scores
    osc <- osF + deviation

    # Determine features with scores greater than or equal to the coefficient
    optimal_features <- which(osF >= osc)

    # Store results
    optimal_features_list[[label]] <- list(
        osF = osF,
        deviation = deviation,
        osc = osc,
        optimal_features = optimal_features
    )
}

# Convert the results to a data frame for saving
results <- do.call(rbind, lapply(names(optimal_features_list), function(label) {
    # Extract optimal features and scores for the current label
    features <- optimal_features_list[[label]]$optimal_features
    scores <- optimal_features_list[[label]]$osF[features]

    # Create a data frame if there are any features; otherwise, return an empty data frame
    if (length(features) > 0) {
        data.frame(
            Label = label,
            Feature = features,
            Optimal_Score = scores
        )
    } else {
        # Return an empty data frame with the correct columns
        data.frame(
            Label = character(),
            Feature = integer(),
            Optimal_Score = numeric()
        )
    }
}))

# Print results
print(results)

# Save the results to a CSV file
write_csv(results, "output/optimal_features.csv")
