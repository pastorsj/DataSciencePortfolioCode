# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(
  tidyverse, gridExtra, TSstudio,
  fpp, forecast, astsa, lubridate,
  zoo, fpp
)
# ---------------------------------------------

wildfire.df <- read.csv("../cleaned_data/wildfire/aggregated_wildfire_data.csv") %>% drop_na()
head(wildfire.df)

# Start with California
wildfire.ts.ca <- wildfire.df %>%
  filter(StateAbbreviation == "CA") %>%
  select(NumberOfWildfires) %>%
  ts(start = c(1992, 1), end = c(2015, 12), frequency = 12)
wildfire.ts.ca <- data.frame(Y = as.matrix(wildfire.ts.ca)) %>%
  ts(start = c(1992, 1), end = c(2015, 12), frequency = 12)

wildfire.ts.ca.log <- log(wildfire.ts.ca)

str(wildfire.ts.ca)


ggAcf(diff(wildfire.ts.ca.log, 12), lag.max = 100) +
  ggtitle("ACF of California Wildfires") # q=1-2
ggsave("../arma_visualizations/wildfire/wildfire_stationary_acf_plot.svg", width = 8, height = 6, units = "in")

ggPacf(diff(wildfire.ts.ca.log, 12), lag.max = 100) +
  ggtitle("PACF of Average Temperature in California") # q=1-2, Q=1
ggsave("../arma_visualizations/wildfire/wildfire_stationary_pacf_plot.svg", width = 8, height = 6, units = "in")

SARIMA.c <- function(p1, p2, q1, q2, P1, P2, Q1, Q2, data) {
  temp <- c()
  d <- 0
  D <- 1
  s <- 12

  i <- 1
  temp <- data.frame()
  ls <- matrix(rep(NA, 9 * 81), nrow = 81)


  for (p in p1:p2)
  {
    for (q in q1:q2)
    {
      for (P in P1:P2)
      {
        for (Q in Q1:Q2)
        {
          if (p + d + q + P + D + Q <= 10) {
            model <- tryCatch(
              {
                print(paste0("p = ", p, ", q = ", q, ", P = ", P, ", Q = ", Q))
                Arima(data, order = c(p, d, q), seasonal = list(order = c(P, D, Q), period = 12), include.drift = TRUE, lambda = 0, method = "ML")
              },
              error = function(cond) {
                print("This failed")
                print(cond)
                return(NA)
              }
            )
            if (!is.na(model)) {
              ls[i, ] <- c(p, d, q, P, D, Q, model$aic, model$bic, model$aicc)
            }
            i <- i + 1
          }
        }
      }
    }
  }


  temp <- as.data.frame(ls)
  names(temp) <- c("p", "d", "q", "P", "D", "Q", "AIC", "BIC", "AICc")

  temp
}

output <- SARIMA.c(p1 = 0, p2 = 2, q1 = 0, q2 = 2, P1 = 0, P2 = 2, Q1 = 0, Q2 = 2, data = wildfire.ts.ca.log) %>%
  drop_na()

minaic <- output[which.min(output$AIC), ]
minbic <- output[which.min(output$BIC), ]

minaic
minbic

write.csv(output, "../arma_data/wildfire/arma_results.csv", row.names = FALSE)


(fit <- Arima(wildfire.ts.ca.log,
  order = c(1, 0, 1), seasonal = list(order = c(1, 1, 1), period = 12),
  include.drift = TRUE, lambda = 0, method = "ML"
))
png("../arma_visualizations/wildfire/residuals_fit.png", width = 8, height = 6, units = "in", res = 400)
checkresiduals(fit, lag = 36)
dev.off()

auto.arima(wildfire.ts.ca.log)

forecasted.viz <- wildfire.ts.ca.log %>%
  Arima(order = c(1, 0, 1), seasonal = c(1, 1, 1)) %>%
  forecast() %>%
  autoplot()
ggsave("../arma_visualizations/wildfire/forecast_viz.svg", plot = forecasted.viz, width = 10, height = 6, units = "in")

png("../arma_visualizations/wildfire/wildfire_sarima_1_0_1_1_1_1.png", width = 8, height = 6, units = "in", res = 400)
sarima(wildfire.ts.ca.log, p = 1, d = 0, q = 1, P = 1, D = 1, Q = 1, S = 12)
dev.off()

png("../arma_visualizations/wildfire/wildfire_sarima_forecast_1_0_1_1_1_1.png", width = 8, height = 6, units = "in", res = 400)
sarima.for(wildfire.ts.ca.log, 60, 1, 0, 1, 1, 1, 1, 12)
dev.off()

# Compare against other methods

length(wildfire.ts.ca.log)

train <- ts(wildfire.ts.ca.log[1:230])
test <- ts(wildfire.ts.ca.log[231:288])
fit <- Arima(train,
  order = c(1, 0, 1), seasonal = list(order = c(1, 1, 1), period = 12),
  include.drift = TRUE, lambda = 0, method = "ML"
)
summary(fit)

pred <- forecast(fit, 58)
accuracy(pred)

f1 <- meanf(train, h = 58)
accuracy(f1)
f2 <- naive(train, h = 58)
accuracy(f2)
f3 <- rwf(train, drift = TRUE, h = 58)
accuracy(f3)

mae1 <- abs(mean(as.numeric(pred$mean) - as.numeric((test))))
mae11 <- abs(mean(as.numeric(f1$mean) - as.numeric((test))))
mae12 <- abs(mean((as.numeric(f2$mean) - as.numeric((test)))))
mae13 <- abs(mean((as.numeric(f3$mean) - as.numeric((test)))))

mse1 <- abs(mean((as.numeric(pred$mean) - as.numeric((test)))^2))
mse11 <- abs(mean((as.numeric(f1$mean) - as.numeric((test)))^2))
mse12 <- abs(mean((as.numeric(f2$mean) - as.numeric((test)))^2))
mse13 <- abs(mean((as.numeric(f3$mean) - as.numeric((test)))^2))

df <- data.frame(
  Model = c("Sarima", "Mean Forecast", "Naive", "Random Walk Forecast"),
  MAE = c(mae1, mae11, mae12, mae13),
  MSE = c(mse1, mse11, mse12, mse13)
) %>%
  mutate_if(is.numeric, round, 3)
df
write.csv(df, "../arma_data/wildfire/wildfire_forecast_data.csv", row.names = FALSE)


# Seasonal Cross Validation (1 Step Ahead)

k <- 60
n <- length(wildfire.ts.ca.log)

mae <- matrix(NA, n - k, 12)
st <- tsp(wildfire.ts.ca.log)[1] + (k - 2) / 12

i <- 1

for (i in 1:(n - k)) {
  print(paste0("Running cross validation iteration ", i))
  xtrain <- window(wildfire.ts.ca.log, end = st + i / 12)
  xtest <- window(wildfire.ts.ca.log, start = st + (i + 1) / 12, end = st + (i + 12) / 12)

  fit <- Arima(xtrain,
    order = c(1, 0, 1), seasonal = list(order = c(1, 1, 1), period = 12),
    include.drift = TRUE, lambda = 0, method = "ML"
  )
  fcast <- forecast(fit, h = 12)

  mae[i, 1:length(xtest)] <- abs(fcast$mean - xtest)
}

one.step.viz <- data.frame(h = 1:12, MSE = colMeans(mae, na.rm = TRUE)) %>%
  ggplot(aes(x = h, y = MSE)) +
  geom_point() +
  geom_line() +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(x = "Horizon", y = "MSE", title = "Seasonal Cross Validation (1 Step Ahead)")
ggsave("../arma_visualizations/wildfire/seasonal_cv_1_step.svg", plot = one.step.viz, width = 10, height = 6, units = "in")

write.csv(data.frame(h = 1:12, MSE = colMeans(mae, na.rm = TRUE)), "../arma_data/wildfire/cv_1_step.csv", row.names = FALSE)

# Seasonal Cross Validation (12 Steps Ahead)

mae1 <- matrix(NA, (n - k) / 12, 12)
st <- tsp(wildfire.ts.ca.log)[1] + (k - 1) / 12
e <- (n - k) / 12

i <- 1

for (i in 1:e) {
  print(paste0("Running cross validation iteration ", i))
  xtrain <- window(wildfire.ts.ca.log, end = st + (i - 1))
  xtest <- window(wildfire.ts.ca.log, start = st + (i - 1) + 1 / 12, end = st + i)

  fit <- Arima(xtrain,
    order = c(1, 0, 1), seasonal = list(order = c(1, 1, 1), period = 12),
    include.drift = TRUE, lambda = 0, method = "ML"
  )
  fcast <- forecast(fit, h = 12)

  mae1[i, 1:length(xtest)] <- abs(fcast$mean - xtest)
}

twelve.step.viz <- data.frame(h = 1:12, MSE = colMeans(mae1, na.rm = TRUE)) %>%
  ggplot(aes(x = h, y = MSE)) +
  geom_point() +
  geom_line() +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(x = "Horizon", y = "MSE", title = "Seasonal Cross Validation (12 Steps Ahead)")
ggsave("../arma_visualizations/wildfire/seasonal_cv_12_steps.svg", plot = twelve.step.viz, width = 10, height = 6, units = "in")

write.csv(data.frame(h = 1:12, MSE = colMeans(mae1, na.rm = TRUE)), "../arma_data/wildfire/cv_12_step.csv", row.names = FALSE)
