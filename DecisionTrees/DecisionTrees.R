if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(tidyverse, rpart, rpart.plot, aws.s3, plotly, rattle, caret, randomForest, caTools, ggplot2, ggthemes, cvms, tibble)

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

decisionTreeData <- 'decision_tree_data/survey_results'
decisionTreeDataVisualizations = 'decision_tree_data_visualizations/survey_results'
randomForestData <- 'random_forest_data/survey_results'
randomForestDataVisualizations = 'random_forest_data_visualizations/survey_results'

createDirectoryIfNotExists(decisionTreeData)
createDirectoryIfNotExists(decisionTreeDataVisualizations)
createDirectoryIfNotExists(randomForestData)
createDirectoryIfNotExists(randomForestDataVisualizations)

householdSurveyData <- '../DataSourcing/processed_data/consolidated_survey_data/standard/all'
lockdownData <- '../DataSourcing/processed_data/lockdown_data'

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
head(df)

# Remove state, topic, week, date, total, and did not report columns
df.clean <- df %>% 
  drop_na() %>%
  select(-Topic, -Week, -Date, -Total, -Did.not.report) %>%
  filter(Characteristic != 'total') %>%
  rename(Label = Characteristic,
         Enough = Enough.of.the.kinds.of.food.wanted,
         Lack.Variety = Enough.food.but.not.always.the.kinds.wanted,
         Sometimes = Sometimes.not.enough.to.eat,
         Not.Enough = Often.not.enough.to.eat) %>%
  transform(Label = as.factor(Label),
            InLockdown = ifelse(InLockdown == 'True', 'Yes', 'No')) %>%
  transform(InLockdown = as.factor(InLockdown)) %>%
  filter(InLockdown == 'Yes') %>%
  select(-InLockdown)

df.clean$Region <- lapply(df.clean$State, FUN = function(s) levels(state.region)[state.region[s == state.abb]])
df.clean <- df.clean %>% 
  select(-State) %>%
  transform(Region = factor(Region, levels = unique(state.region)))
write.csv(as.data.frame(df.clean), paste(decisionTreeData, 'raw-dt-data.csv', sep = '/'), row.names = FALSE)

####################### Build Decision Tree #######################
runDecisionTree <- function(training.sample, test.sample, labels.test, graph.title, file.prefix, cp) {
  dt <- rpart(training.sample$Label ~ ., data = training.sample, method = 'class', cp = cp)
  summary(dt)
  
  print('Created a decision tree')
  
  df.importance <- data.frame(importance = dt$variable.importance)
  df.importance <- df.importance %>% 
    tibble::rownames_to_column() %>% 
    dplyr::rename("variable" = rowname) %>% 
    dplyr::arrange(importance) %>%
    dplyr::mutate(variable = forcats::fct_inorder(variable))
  
  p <- ggplot(df.importance, aes(x = variable, y = importance)) +
    geom_bar(stat = 'identity', fill = 'steelblue') +
    guides(fill = FALSE) +
    xlab("Feature") + ylab("Importance") +
    ggtitle(paste('Importance of features for ', file.prefix, sep = ''))
  
  ggsave(paste(decisionTreeDataVisualizations, paste(file.prefix, '-feature-importance.png', sep = ''), sep = '/'), plot = p)
  write.csv(df.importance, paste(decisionTreeData, paste(file.prefix, '-feature-importance.csv', sep = ''), sep = '/'), row.names = FALSE)
  
  print('Plotted feature importance for decision')
  
  dt.prediction <- predict(dt, test.sample, type = 'class')
  # Create confusion matrix
  print('Creating plot of confusion matrix')
  cfm <- as_tibble(table(dt.prediction, labels.test))
  pc <- plot_confusion_matrix(cfm, 
                        target_col = "labels.test", 
                        prediction_col = "dt.prediction",
                        counts_col = "n",
                        place_x_axis_above = FALSE,
                        add_normalized = FALSE,
                        add_col_percentages = FALSE,
                        add_row_percentages = FALSE,
                        rotate_y_text = FALSE,
                        rm_zero_text = FALSE,
                        palette = "Oranges")
  ggsave(paste(decisionTreeDataVisualizations, paste(file.prefix, '-confusion-matrix.png', sep = ''), sep = '/'), plot = pc)
  
  c.m <- as.data.frame.matrix(table(dt.prediction, labels.test))
  c.m <- cbind(Label = rownames(c.m), c.m)
  write.csv(c.m, paste(decisionTreeData, paste(file.prefix, '-confusion-matrix.csv', sep = ''), sep = '/'), row.names = FALSE)
  
  
  print('Predicted using the decision tree and test set')
  
  png(paste(decisionTreeDataVisualizations, paste(file.prefix, '-dt.png', sep = ''), sep = '/'), width = 6, height = 4, units='in', res = 400)
  fancyRpartPlot(dt, main = graph.title, sub = '')
  dev.off()
  
  print('Visualized the decision tree')
}


runTrees <- function(dt.filtered, graph.title, file.prefix) {
  size.training <- floor(nrow(dt.filtered) * 0.8)
  size.test <- nrow(dt.filtered) - size.training
  
  set.seed(123)
  training.sample.rows <- sample(nrow(dt.filtered), size.training, replace = FALSE)
  training.sample <- droplevels(dt.filtered[training.sample.rows, ])
  write.csv(training.sample, paste(decisionTreeData, paste(file.prefix, '-training-data.csv', sep = ''), sep = '/'), row.names = FALSE)
  table(training.sample$Label)
  
  test.sample <- droplevels(dt.filtered[-training.sample.rows, ])
  write.csv(test.sample, paste(decisionTreeData, paste(file.prefix, '-test-data.csv', sep = ''), sep = '/'), row.names = FALSE)
  table(test.sample$Label)
  
  labels.test <- test.sample$Label
  test.sample <- test.sample %>% select(-Label)
  
  print('Split data into training and testing sets')
  
  print('Create a decision tree with complexity parameter set to 0.01')
  runDecisionTree(training.sample, test.sample, labels.test, graph.title, paste(file.prefix, 'default', sep = '-'), 0.01)
  print('Create a decision tree with complexity parameter set to 0.025')
  runDecisionTree(training.sample, test.sample, labels.test, graph.title, paste(file.prefix, '0.025', sep = '-'), 0.025)
  print('Creating a decision tree purposely overfit')
  runDecisionTree(training.sample, test.sample, labels.test, graph.title, paste(file.prefix, 'overfit', sep = '-'), 0)
  
  rf <- randomForest(Label ~ ., data = training.sample)
  print('Generated random forest')
  
  png(paste(randomForestDataVisualizations, paste(file.prefix, '-error-rate-rf.png', sep = ''), sep = '/'), width = 6, height = 4, units='in', res = 400)
  p.rf <- plot(rf, main = paste("Error rate of random forest for ", file.prefix, sep = ''))
  dev.off()
  print('Visualized error rate for random forest')
  
  png(paste(randomForestDataVisualizations, paste(file.prefix, '-feature-importance-rf.png', sep = ''), sep = '/'), width = 6, height = 4, units='in', res = 400)
  p.rf.vi <- varImpPlot(rf,
     sort = T,
     n.var = 10,
     main = paste("Variable Importance for Random Forest (", file.prefix, ')', sep = ''))
  dev.off()
  print('Visualized variable importance for random forest')
  variable.importance = round(importance(rf), 2)
  write.csv(variable.importance, paste(randomForestData, paste(file.prefix, '-variable-importance.csv', sep = ''), sep = '/'))
  
  rf.predict <- predict(rf, newdata = test.sample)
  print('Predicted labels using random forest and test set')
  
  
  c.m <- as.data.frame.matrix(table(rf.predict, labels.test))
  c.m <- cbind(Label = rownames(c.m), c.m)
  write.csv(c.m, paste(randomForestData, paste(file.prefix, '-confusion-matrix.csv', sep = ''), sep = '/'), row.names = FALSE)
  print('Created confusion matrix for random forest')
  
  cfm <- as_tibble(table(rf.predict, labels.test))
  pc <- plot_confusion_matrix(cfm, 
                              target_col = "labels.test", 
                              prediction_col = "rf.predict",
                              counts_col = "n",
                              place_x_axis_above = FALSE,
                              add_normalized = FALSE,
                              add_col_percentages = FALSE,
                              add_row_percentages = FALSE,
                              rotate_y_text = FALSE,
                              rm_zero_text = FALSE,
                              palette = "Greens")
  ggsave(paste(randomForestDataVisualizations, paste(file.prefix, '-confusion-matrix.png', sep = ''), sep = '/'), plot = pc)
  print('Created plot of confusion matrix for random forest')
}
################################################################ 

# Build a decision tree for only age groups
df.ages <- df.clean %>%
  filter(Label %in% c('18 - 24', '25 - 39', '40 - 54', '55 - 64', '65 and above'))

head(df.ages)

runTrees(df.ages, 'Decision Tree by Age', 'age')

# Build a decision tree for only female/male
df.gender <- df.clean %>%
  filter(Label %in% c('female', 'male'))

head(df.gender)
runTrees(df.gender, 'Decision Tree by Gender', 'gender')

# Build a decision for only race
df.race <- df.clean %>%
  filter(Label %in% c('hispanic or latino', 'white alone', 'black alone', 'asian alone', 'two or more races'))

head(df.race)
runTrees(df.race, 'Decision Tree by Race', 'race')

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
  allFiles <- list.files(decisionTreeData, full.names = TRUE, pattern = '*')
  print('Uploading decision tree data to S3')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f) })
  allFiles <- list.files(decisionTreeDataVisualizations, full.names = TRUE, pattern = '*', recursive = TRUE)
  print('Uploading decision tree data visualizations to S3')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f) })
  allFiles <- list.files(randomForestData, full.names = TRUE, pattern = '*', recursive = TRUE)
  print('Uploading random forest data to S3')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f) })
  allFiles <- list.files(randomForestDataVisualizations, full.names = TRUE, pattern = '*', recursive = TRUE)
  print('Uploading random forest visualizations data to S3')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f) })
}


