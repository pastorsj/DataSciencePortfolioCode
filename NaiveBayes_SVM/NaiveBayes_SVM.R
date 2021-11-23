if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(tidyverse, aws.s3, plotly, rattle, caret, ggplot2, ggthemes, 
               cvms, tibble, e1071, rsvg, ggimage, psych, naivebayes, rminer)

saveToS3 <- TRUE

#' Creates a directory if it does not exist yet
#' 
#' @param path A path to create
#' @examples 
#' createDirectoryIfNotExists('path/to/file')
createDirectoryIfNotExists <- function(path) {
  # Create the directory if it doesn't exist.
  if (dir.exists(path) == FALSE) {
    dir.create(path, recursive = TRUE)
  }
}

naiveBayesData <- 'naive_bayes_data/survey_results'
naiveBayesDataVisualizations = 'naive_bayes_data_visualizations/survey_results'
svmData <- 'svm_data/survey_results'
svmDataVisualizations = 'svm_data_visualizations/survey_results'

createDirectoryIfNotExists(naiveBayesData)
createDirectoryIfNotExists(naiveBayesDataVisualizations)
createDirectoryIfNotExists(svmData)
createDirectoryIfNotExists(svmDataVisualizations)

householdSurveyData <- '../DataSourcing/processed_data/consolidated_survey_data/standard/all'
lockdownData <- '../DataSourcing/processed_data/lockdown_data'
fredData <- '../Fred/processed_data'


# Retrieve household survey data
allFiles <- list.files(householdSurveyData, full.names = TRUE, pattern = '*-normalized.csv')
df <- data.frame()
new.dfs <- lapply(allFiles, FUN = function(f) read.csv(f))
for (n.df in new.dfs) {
  df <- rbind(df, n.df)
}
print('Retrieved household survey data and combined')


# Retrieve lockdown data and combine
matchLockdownData <- function(x, lockdownDf) {
  stateName <- state.name[state.abb == x['State']]
  reduced.df <- lockdownDf[lockdownDf$State == stateName, ]
  res <- reduced.df[
    (strftime(as.Date(reduced.df$Date), '%Y-%m') == strftime(as.Date(x['Date']), '%Y-%m')), ]$InLockdown
  if (identical(res, character(0))) {
    res <- 'False'
  }
  return(res)
}

allFiles <- list.files(lockdownData, full.names = TRUE, pattern = '*.csv')
lockdownDf <- data.frame()
new.dfs <- lapply(allFiles, FUN = function(f) read.csv(f))
for (n.df in new.dfs) {
  lockdownDf <- rbind(lockdownDf, n.df)
}
df$InLockdown <- apply(df[, c('Date', 'State')], 1, FUN = function(x) matchLockdownData(x, lockdownDf))


allFiles <- list.files(fredData, full.names = TRUE, pattern = '*.csv')
df.fred.1 <- data.frame()
for (f in allFiles) {
  if (endsWith(basename(f), '-employment-food-manufacturing.csv')) {
    extracted.state = gsub('-employment-food-manufacturing.csv', '', basename(f))
    df.fred.next <- read.csv(f) %>% 
      transform(FoodManufacturingEmploymentRate = count, 
                MergeDate = timestamp,
                State = state.abb[state.name == extracted.state]) %>%
      dplyr::select(FoodManufacturingEmploymentRate, MergeDate, State)
    df.fred.1 <- bind_rows(df.fred.1, df.fred.next)
  }
}
df.fred.2 <- data.frame()
for (f in allFiles) {
  if (endsWith(basename(f), '-employment-food-and-hospitality.csv')) {
    extracted.state = gsub('-employment-food-and-hospitality.csv', '', basename(f))
    df.fred.next <- read.csv(f) %>% 
      transform(FoodHospitalityEmploymentRate = count, 
                MergeDate = timestamp,
                State = state.abb[state.name == extracted.state]) %>%
      dplyr::select(FoodHospitalityEmploymentRate, MergeDate, State)
    df.fred.2 <- bind_rows(df.fred.2, df.fred.next)
  }
}
df.fred <- merge(df.fred.1, df.fred.2, by = c('MergeDate', 'State'), all.x = TRUE) %>%
  drop_na(FoodManufacturingEmploymentRate, FoodHospitalityEmploymentRate)

monthStart <- function(x) {
  x <- as.POSIXlt(x)
  x$mday <- 1
  as.Date(x)
}

df <- df %>% transform(MergeDate = monthStart(Date))
df <- merge(df, df.fred, by = c('MergeDate', 'State'), all.x = TRUE) %>%
  drop_na(FoodManufacturingEmploymentRate, FoodHospitalityEmploymentRate)
print(df)

# Remove state, topic, week, date, total, and did not report columns
df.clean <- df %>% 
  drop_na() %>%
  dplyr::select(-Topic, -Week, -Total, -Did.not.report, -MergeDate) %>%
  filter(Characteristic == 'total') %>%
  rename(Enough = Enough.of.the.kinds.of.food.wanted,
         LackVariety = Enough.food.but.not.always.the.kinds.wanted,
         Sometimes = Sometimes.not.enough.to.eat,
         NotEnough = Often.not.enough.to.eat) %>%
  transform(Characteristic = as.factor(Characteristic),
            State = as.factor(State),
            InLockdown = ifelse(InLockdown == 'True', 'Yes', 'No')) %>%
  transform(InLockdown = as.factor(InLockdown)) %>%
  dplyr::select(-Characteristic)

df.clean$Region <- lapply(df.clean$State, FUN = function(s) levels(state.region)[state.region[s == state.abb]])
df.clean <- df.clean %>% 
  transform(Region = factor(Region, levels = unique(state.region))) %>%
  dplyr::select(-Date)
write.csv(as.data.frame(df.clean), paste(naiveBayesData, 'raw-nb-data.csv', sep = '/'), row.names = FALSE)

pairs.panels(df.clean %>% dplyr::select(-State))
dev.copy(png, filename = paste(naiveBayesDataVisualizations, 'raw-nb-data.png', sep = '/'), width = 1200, height = 800)
dev.off()

# Split training and testing data
trainIndex = df.clean$Enough %>% createDataPartition(p = 0.9, list = FALSE)
training.sample = df.clean[trainIndex, ] %>% dplyr::select(-Region)
test.sample = df.clean[-trainIndex, ] %>% dplyr::select(-Region)

write.csv(training.sample, paste(naiveBayesData, 'nb-training-data.csv', sep = '/'), row.names = FALSE)
write.csv(test.sample, paste(naiveBayesData, 'nb-test-data.csv', sep = '/'), row.names = FALSE)

table(training.sample$State)
table(test.sample$State)

labels.training <- training.sample$State
labels.test <- test.sample$State

training.sample <- training.sample %>% dplyr::select(-State)
test.sample <- test.sample %>% dplyr::select(-State)

######################################### Run Naive Bayes #########################################
nb.model <- naiveBayes(training.sample, 
                       labels.training, 
                       laplace = 1)

nb.prediction <- predict(nb.model, test.sample)

cfm <- as_tibble(table(nb.prediction, labels.test))
(pc <- plot_confusion_matrix(cfm, 
                            target_col = "labels.test", 
                            prediction_col = "nb.prediction",
                            counts_col = "n",
                            place_x_axis_above = FALSE,
                            add_normalized = FALSE,
                            add_col_percentages = FALSE,
                            add_row_percentages = FALSE,
                            rotate_y_text = FALSE,
                            rm_zero_text = FALSE,
                            palette = "Oranges"))
ggsave(paste(naiveBayesDataVisualizations, 'nb-confusion-matrix.png', sep = '/'), plot = pc)

c.m <- as.data.frame.matrix(table(nb.prediction, labels.test))
c.m <- cbind(Label = rownames(c.m), c.m)
write.csv(c.m, paste(naiveBayesData, 'nb-confusion-matrix.csv', sep = '/'), row.names = FALSE)

nb.model.2 <- naive_bayes(training.sample, 
                       labels.training, 
                       laplace = 1)
nb.prediction.2 <- predict(nb.model.2, test.sample)

cfm.2 <- as_tibble(table(nb.prediction.2, labels.test))
(pc.2 <- plot_confusion_matrix(cfm.2, 
                             target_col = "labels.test", 
                             prediction_col = "nb.prediction.2",
                             counts_col = "n",
                             place_x_axis_above = FALSE,
                             add_normalized = FALSE,
                             add_col_percentages = FALSE,
                             add_row_percentages = FALSE,
                             rotate_y_text = FALSE,
                             rm_zero_text = FALSE,
                             palette = "Oranges"))
ggsave(paste(naiveBayesDataVisualizations, 'nb-2-confusion-matrix.png', sep = '/'), plot = pc.2)

c.m <- as.data.frame.matrix(table(nb.prediction, labels.test))
c.m <- cbind(Label = rownames(c.m), c.m)
write.csv(c.m, paste(naiveBayesData, 'nb-2-confusion-matrix.csv', sep = '/'), row.names = FALSE)


# Plot nb model variables
png(paste(naiveBayesDataVisualizations, 'enough_variable_density_plot.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(nb.model.2, which = 'Enough', prob = "conditional")
dev.off()
write.csv(nb.model.2$tables$Enough, paste(naiveBayesData, 'enough_variable_statistics.csv', sep = '/'), row.names = FALSE)

png(paste(naiveBayesDataVisualizations, 'lock_variety_variable_density_plot.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(nb.model.2, which = 'LackVariety', prob = "conditional")
dev.off()
write.csv(nb.model.2$tables$LackVariety, paste(naiveBayesData, 'lack_variety_variable_statistics.csv', sep = '/'), row.names = FALSE)

png(paste(naiveBayesDataVisualizations, 'sometimes_variable_density_plot.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(nb.model.2, which = 'Sometimes', prob = "conditional")
dev.off()
write.csv(nb.model.2$tables$Sometimes, paste(naiveBayesData, 'sometimes_variable_statistics.csv', sep = '/'), row.names = FALSE)

png(paste(naiveBayesDataVisualizations, 'not_enough_variable_density_plot.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(nb.model.2, which = 'NotEnough', prob = "conditional")
dev.off()
write.csv(nb.model.2$tables$NotEnough, paste(naiveBayesData, 'not_enough_variable_statistics.csv', sep = '/'), row.names = FALSE)

png(paste(naiveBayesDataVisualizations, 'lockdown_variable_density_plot.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(nb.model.2, which = 'InLockdown', prob = "conditional")
dev.off()
write.csv(nb.model.2$tables$InLockdown, paste(naiveBayesData, 'lockdown_variable_statistics.csv', sep = '/'), row.names = FALSE)

png(paste(naiveBayesDataVisualizations, 'food_man_employment_variable_density_plot.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(nb.model.2, which = 'FoodManufacturingEmploymentRate', prob = "conditional")
dev.off()
write.csv(nb.model.2$tables$FoodManufacturingEmploymentRate, paste(naiveBayesData, 'food_man_employment_variable_statistics.csv', sep = '/'), row.names = FALSE)

png(paste(naiveBayesDataVisualizations, 'food_hosp_employment_variable_density_plot.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(nb.model.2, which = 'FoodHospitalityEmploymentRate', prob = "conditional")
dev.off()
write.csv(nb.model.2$tables$FoodHospitalityEmploymentRate, paste(naiveBayesData, 'food_hosp_employment_variable_statistics.csv', sep = '/'), row.names = FALSE)


trainIndex.t <- df.clean$Enough %>% createDataPartition(p = 0.9, list = FALSE)
training.sample.t <- df.clean[trainIndex, ] %>% dplyr::select(-Region)
test.sample.t <- df.clean[-trainIndex, ] %>% dplyr::select(-Region)
labels.test <- test.sample.t$State
model.tm <- fit(State~., data = training.sample.t, model = "naiveBayes", task = 'class')
tm.prediction <- predict(model.tm, test.sample.t %>% select(-State))
feature.importance <- Importance(model.tm, data = training.sample.t, method = "DSA")

cfm.3 <- as_tibble(table(tm.prediction, labels.test))
(pc.3 <- plot_confusion_matrix(cfm.3, 
                               target_col = "labels.test", 
                               prediction_col = "tm.prediction",
                               counts_col = "n",
                               place_x_axis_above = FALSE,
                               add_normalized = FALSE,
                               add_col_percentages = FALSE,
                               add_row_percentages = FALSE,
                               rotate_y_text = FALSE,
                               rm_zero_text = FALSE,
                               palette = "Oranges"))
ggsave(paste(naiveBayesDataVisualizations, 'nb-3-confusion-matrix.png', sep = '/'), plot = pc.2)

c.m <- as.data.frame.matrix(table(tm.prediction, labels.test))
c.m <- cbind(Label = rownames(c.m), c.m)
write.csv(c.m, paste(naiveBayesData, 'nb-3-confusion-matrix.csv', sep = '/'), row.names = FALSE)

L <- list(runs = 1,sen = t(feature.importance$imp),sresponses = feature.importance$sresponses)
png(paste(naiveBayesDataVisualizations, 'nb_feature_importance.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
mgraph(L,graph = "IMP", leg = names(df.clean), col = "cyan", Grid = 10)
dev.off()

######################################### Run Support Vector Machines #########################################

trainIndex.svm = df.clean$Enough %>% createDataPartition(p = 0.8, list = FALSE)
training.sample.svm = df.clean[trainIndex.svm, ] %>% dplyr::select(-InLockdown, -State)
test.sample.svm = df.clean[-trainIndex.svm, ] %>% dplyr::select(-InLockdown, -State)

write.csv(training.sample.svm, paste(svmData, 'svm-training-data.csv', sep = '/'), row.names = FALSE)
write.csv(test.sample.svm, paste(svmData, 'svm-test-data.csv', sep = '/'), row.names = FALSE)

labels.test.svm <- test.sample.svm$Region
test.sample.svm <- test.sample.svm %>% dplyr::select(-Region)

### Polynomial Kernel
svm.model.poly <- svm(Region ~ FoodManufacturingEmploymentRate + FoodHospitalityEmploymentRate,
                      data = training.sample.svm,
                      kernel = "polynomial",
                      cost = 0.1)

svm.prediction.poly <- predict(svm.model.poly, test.sample.svm, type = "class")

cfm.svm <- as_tibble(table(svm.prediction.poly, labels.test.svm))
(pc.svm <- plot_confusion_matrix(cfm.svm, 
                               target_col = "labels.test.svm", 
                               prediction_col = "svm.prediction.poly",
                               counts_col = "n",
                               place_x_axis_above = FALSE,
                               add_normalized = FALSE,
                               add_col_percentages = FALSE,
                               add_row_percentages = FALSE,
                               rotate_y_text = FALSE,
                               rm_zero_text = FALSE,
                               palette = "Greens"))
ggsave(paste(svmDataVisualizations, 'svm_poly_confusion_matrix.png', sep = '/'), plot = pc.2)

png(paste(svmDataVisualizations, 'svm_poly_classification.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(svm.model.poly, training.sample.svm, formula = FoodManufacturingEmploymentRate ~ FoodHospitalityEmploymentRate)
dev.off()

c.m <- as.data.frame.matrix(table(svm.prediction.poly, labels.test.svm))
c.m <- cbind(Label = rownames(c.m), c.m)
write.csv(c.m, paste(svmData, 'svm_poly_confusion_matrix.csv', sep = '/'), row.names = FALSE)

(misclassification.rate <- 1 - sum(diag(table(svm.prediction.poly, labels.test.svm)))/sum(table(svm.prediction.poly, labels.test.svm)))

### Linear Kernel
svm.model.linear <- svm(Region ~ FoodManufacturingEmploymentRate + FoodHospitalityEmploymentRate,
                      data = training.sample.svm,
                      kernel = "linear",
                      cost = 0.1)

svm.prediction.linear <- predict(svm.model.linear, test.sample.svm, type = "class")

cfm.svm.linear <- as_tibble(table(svm.prediction.linear, labels.test.svm))
(pc.svm.linear <- plot_confusion_matrix(cfm.svm.linear, 
                                 target_col = "labels.test.svm", 
                                 prediction_col = "svm.prediction.linear",
                                 counts_col = "n",
                                 place_x_axis_above = FALSE,
                                 add_normalized = FALSE,
                                 add_col_percentages = FALSE,
                                 add_row_percentages = FALSE,
                                 rotate_y_text = FALSE,
                                 rm_zero_text = FALSE,
                                 palette = "Greens"))
ggsave(paste(svmDataVisualizations, 'svm_linear_confusion_matrix.png', sep = '/'), plot = pc.2)

png(paste(svmDataVisualizations, 'svm_linear_classification.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(svm.model.linear, training.sample.svm, formula = FoodManufacturingEmploymentRate ~ FoodHospitalityEmploymentRate)
dev.off()

c.m <- as.data.frame.matrix(table(svm.prediction.linear, labels.test.svm))
c.m <- cbind(Label = rownames(c.m), c.m)
write.csv(c.m, paste(svmData, 'svm_linear_confusion_matrix.csv', sep = '/'), row.names = FALSE)

(misclassification.rate <- 1 - sum(diag(table(svm.prediction.linear, labels.test.svm)))/sum(table(svm.prediction.linear, labels.test.svm)))

### Sigmoid Kernel
svm.model.sigmoid <- svm(Region ~ FoodManufacturingEmploymentRate + FoodHospitalityEmploymentRate,
                        data = training.sample.svm,
                        kernel = "sigmoid",
                        cost = 0.1)

svm.prediction.sigmoid <- predict(svm.model.sigmoid, test.sample.svm, type = "class")

cfm.svm.sigmoid <- as_tibble(table(svm.prediction.sigmoid, labels.test.svm))
(pc.svm.sigmoid <- plot_confusion_matrix(cfm.svm.sigmoid, 
                                        target_col = "labels.test.svm", 
                                        prediction_col = "svm.prediction.sigmoid",
                                        counts_col = "n",
                                        place_x_axis_above = FALSE,
                                        add_normalized = FALSE,
                                        add_col_percentages = FALSE,
                                        add_row_percentages = FALSE,
                                        rotate_y_text = FALSE,
                                        rm_zero_text = FALSE,
                                        palette = "Greens"))
ggsave(paste(svmDataVisualizations, 'svm_sigmoid_confusion_matrix.png', sep = '/'), plot = pc.2)

png(paste(svmDataVisualizations, 'svm_sigmoid_classification.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(svm.model.sigmoid, training.sample.svm, formula = FoodManufacturingEmploymentRate ~ FoodHospitalityEmploymentRate)
dev.off()

c.m <- as.data.frame.matrix(table(svm.prediction.sigmoid, labels.test.svm))
c.m <- cbind(Label = rownames(c.m), c.m)
write.csv(c.m, paste(svmData, 'svm_sigmoid_confusion_matrix.csv', sep = '/'), row.names = FALSE)

(misclassification.rate <- 1 - sum(diag(table(svm.prediction.sigmoid, labels.test.svm)))/sum(table(svm.prediction.sigmoid, labels.test.svm)))

### Radial Basis Kernel
svm.model.radial <- svm(Region ~ FoodManufacturingEmploymentRate + FoodHospitalityEmploymentRate,
                         data = training.sample.svm,
                         kernel = "radial",
                         cost = 0.1)

svm.prediction.radial <- predict(svm.model.radial, test.sample.svm, type = "class")

cfm.svm.radial <- as_tibble(table(svm.prediction.radial, labels.test.svm))
(pc.svm.radial <- plot_confusion_matrix(cfm.svm.radial, 
                                         target_col = "labels.test.svm", 
                                         prediction_col = "svm.prediction.radial",
                                         counts_col = "n",
                                         place_x_axis_above = FALSE,
                                         add_normalized = FALSE,
                                         add_col_percentages = FALSE,
                                         add_row_percentages = FALSE,
                                         rotate_y_text = FALSE,
                                         rm_zero_text = FALSE,
                                         palette = "Greens"))
ggsave(paste(svmDataVisualizations, 'svm_radial_confusion_matrix.png', sep = '/'), plot = pc.2)

png(paste(svmDataVisualizations, 'svm_radical_classification.png', sep = '/'), width = 6, height = 4, units = 'in', res = 400)
plot(svm.model.radial, training.sample.svm, formula = FoodManufacturingEmploymentRate ~ FoodHospitalityEmploymentRate)
dev.off()

c.m <- as.data.frame.matrix(table(svm.prediction.radial, labels.test.svm))
c.m <- cbind(Label = rownames(c.m), c.m)
write.csv(c.m, paste(svmData, 'svm_radial_confusion_matrix.csv', sep = '/'), row.names = FALSE)

(misclassification.rate <- 1 - sum(diag(table(svm.prediction.radial, labels.test.svm)))/sum(table(svm.prediction.radial, labels.test.svm)))

### Best Version (Kernel = Radial and Cost = 0.5)
svm.model.best <- svm(Region ~ .,
                        data = training.sample.svm,
                        kernel = "radial",
                        cost = 0.5)

svm.prediction.best <- predict(svm.model.best, test.sample.svm, type = "class")

cfm.svm.best <- as_tibble(table(svm.prediction.best, labels.test.svm))
(pc.svm.best <- plot_confusion_matrix(cfm.svm.best, 
                                        target_col = "labels.test.svm", 
                                        prediction_col = "svm.prediction.best",
                                        counts_col = "n",
                                        place_x_axis_above = FALSE,
                                        add_normalized = FALSE,
                                        add_col_percentages = FALSE,
                                        add_row_percentages = FALSE,
                                        rotate_y_text = FALSE,
                                        rm_zero_text = FALSE,
                                        palette = "Greens"))
ggsave(paste(svmDataVisualizations, 'svm_best_confusion_matrix.png', sep = '/'), plot = pc.2)

c.m <- as.data.frame.matrix(table(svm.prediction.best, labels.test.svm))
c.m <- cbind(Label = rownames(c.m), c.m)
write.csv(c.m, paste(svmData, 'svm_best_confusion_matrix.csv', sep = '/'), row.names = FALSE)

(misclassification.rate <- 1 - sum(diag(table(svm.prediction.best, labels.test.svm)))/sum(table(svm.prediction.best, labels.test.svm)))

############################################# S3 #############################################

#' Stores a file in S3
#'  
#' @param file A file
#' @param suffix The type of data. Used to strip from the filename for cleaning purposes
#' @param directory The inner directory used to store the data in S3
storeDataInS3 <- function(file) {
  print('Storing file in s3')
  print(file)
  put_object(file = file, object = file, bucket = 'datastore.portfolio.sampastoriza.com')
  print('Uploaded file to S3 successfully')
}

if (saveToS3) {
  allFiles <- list.files(svmData, full.names = TRUE, pattern = '*')
  print('Uploading svm data to S3')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f) })
  allFiles <- list.files(svmDataVisualizations, full.names = TRUE, pattern = '*', recursive = TRUE)
  print('Uploading svm data visualizations to S3')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f) })
  allFiles <- list.files(naiveBayesData, full.names = TRUE, pattern = '*', recursive = TRUE)
  print('Uploading naive bayes data to S3')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f) })
  allFiles <- list.files(naiveBayesDataVisualizations, full.names = TRUE, pattern = '*', recursive = TRUE)
  print('Uploading naive bayes visualizations data to S3')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f) })
}
