# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(
  tidyverse,
  gridExtra,
  TSstudio,
  fpp,
  forecast,
  astsa,
  lubridate,
  zoo,
  scales
)
# ---------------------------------------------

weather.df <-
  read.csv("../cleaned_data/weather/weather_data.csv") %>% drop_na()
head(weather.df)

temperature.ts.ca <- weather.df %>%
  filter(StateAbbreviation == "CA") %>%
  select(AverageTemperature) %>%
  ts(
    start = c(1895, 1),
    end = c(2021, 12),
    frequency = 12
  )

autoplot(temperature.ts.ca) +
  ggtitle("Average Temperature in California") +
  xlab("Year (1895-2021)") +
  ylab("Average Temperature")

ggAcf(diff(temperature.ts.ca, 12), lag.max = 100) +
  ggtitle("ACF of Average Temperature in California") # q=1-2, Q=1
ggsave("../arma_visualizations/weather/temperature_stationary_acf_plot.svg", width = 8, height = 6, units = "in")

ggPacf(diff(temperature.ts.ca, 12), lag.max = 100) +
  ggtitle("PACF of Average Temperature in California") # q=1-2, Q=1
ggsave("../arma_visualizations/weather/temperature_stationary_pacf_plot.svg", width = 8, height = 6, units = "in")

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

output <- SARIMA.c(p1 = 0, p2 = 2, q1 = 0, q2 = 2, P1 = 1, P2 = 2, Q1 = 1, Q2 = 2, data = temperature.ts.ca) %>%
  drop_na()

minaic <- output[which.min(output$AIC), ]
minbic <- output[which.min(output$BIC), ]

minaic
minbic

write.csv(output, "../arma_data/weather/arma_results.csv", row.names = FALSE)

(fit <- Arima(temperature.ts.ca, order = c(1, 0, 1), seasonal = c(1, 1, 1), lambda = 0))
png("../arma_visualizations/weather/residuals_fit.png", width = 8, height = 6, units = "in", res = 400)
checkresiduals(fit, lag = 36)
dev.off()

auto.arima(temperature.ts.ca)

forecasted.viz <- temperature.ts.ca %>%
  Arima(order = c(1, 0, 1), seasonal = c(1, 1, 1)) %>%
  forecast() %>%
  autoplot()
ggsave("../arma_visualizations/weather/forecast_viz.svg", plot = forecasted.viz, width = 10, height = 6, units = "in")

png("../arma_visualizations/weather/weather_sarima_1_0_1_1_1_1.png", width = 8, height = 6, units = "in", res = 400)
sarima(temperature.ts.ca, p = 1, d = 0, q = 1, P = 1, D = 1, Q = 1, S = 12)
dev.off()

png("../arma_visualizations/weather/weather_sarima_forecast_1_0_1_1_1_1.png", width = 8, height = 6, units = "in", res = 400)
sarima.for(temperature.ts.ca, 60, 1, 0, 1, 1, 1, 1, 12)
dev.off()

# Compare against other methods

length(temperature.ts.ca)

train <- ts(temperature.ts.ca[1:1200])
test <- ts(temperature.ts.ca[1201:1524])
fit <- Arima(train, order = c(1, 0, 1), seasonal = c(1, 1, 1), lambda = 0)
summary(fit)

pred <- forecast(fit, 324)
accuracy(pred)

f1 <- meanf(train, h = 324)
accuracy(f1)
f2 <- naive(train, h = 324)
accuracy(f2)
f3 <- rwf(train, drift = TRUE, h = 324)
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
write.csv(df, "../arma_data/weather/weather_forecast_data.csv", row.names = FALSE)


# Seasonal Cross Validation (1 Step Ahead)

k <- 60
n <- length(temperature.ts.ca)

head(temperature.ts.ca)

mae <- matrix(NA, n - k, 12)
st <- tsp(temperature.ts.ca)[1] + (k - 2) / 12

i <- 1

for (i in 1:(n - k)) {
  print(paste0("Running cross validation iteration ", i))
  xtrain <- window(temperature.ts.ca, end = st + i / 12)
  xtest <- window(temperature.ts.ca, start = st + (i + 1) / 12, end = st + (i + 12) / 12)

  fit <- Arima(xtrain, order = c(1, 0, 1), seasonal = c(1, 1, 1), lambda = 0)
  fcast <- forecast(fit, h = 12)

  mae[i, 1:length(xtest)] <- abs(fcast$mean - xtest)
}

one.step.viz <- data.frame(h = 1:12, MSE = colMeans(mae, na.rm = TRUE)) %>%
  ggplot(aes(x = h, y = MSE)) +
  geom_point() +
  geom_line() +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(x = "Horizon", y = "MSE", title = "Seasonal Cross Validation (1 Step Ahead)")
ggsave("../arma_visualizations/weather/seasonal_cv_1_step.svg", plot = one.step.viz, width = 10, height = 6, units = "in")

write.csv(data.frame(h = 1:12, MSE = colMeans(mae, na.rm = TRUE)), "../arma_data/weather/cv_1_step.csv", row.names = FALSE)

# Seasonal Cross Validation (12 Steps Ahead)

mae1 <- matrix(NA, (n - k) / 12, 12)
st <- tsp(temperature.ts.ca)[1] + (k - 1) / 12
e <- (n - k) / 12

i <- 1

for (i in 1:e) {
  print(paste0("Running cross validation iteration ", i))
  xtrain <- window(temperature.ts.ca, end = st + (i - 1))
  xtest <- window(temperature.ts.ca, start = st + (i - 1) + 1 / 12, end = st + i)

  fit <- Arima(xtrain, order = c(1, 0, 1), seasonal = c(1, 1, 1), lambda = 0)
  fcast <- forecast(fit, h = 12)

  mae1[i, 1:length(xtest)] <- abs(fcast$mean - xtest)
}

twelve.step.viz <- data.frame(h = 1:12, MSE = colMeans(mae1, na.rm = TRUE)) %>%
  ggplot(aes(x = h, y = MSE)) +
  geom_point() +
  geom_line() +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(x = "Horizon", y = "MSE", title = "Seasonal Cross Validation (12 Steps Ahead)")
ggsave("../arma_visualizations/weather/seasonal_cv_12_steps.svg", plot = twelve.step.viz, width = 10, height = 6, units = "in")

write.csv(data.frame(h = 1:12, MSE = colMeans(mae1, na.rm = TRUE)), "../arma_data/weather/cv_12_step.csv", row.names = FALSE)
