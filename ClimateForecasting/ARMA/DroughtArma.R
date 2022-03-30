# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(
  tidyverse, gridExtra, TSstudio,
  fpp, forecast, astsa, lubridate, zoo
)
# ---------------------------------------------

weather.df <- read.csv("../cleaned_data/weather/weather_data.csv") %>% drop_na()
head(weather.df)

# Start with California
drought.ts.ca <- weather.df %>%
  filter(StateAbbreviation == "CA") %>%
  select(DroughtIndex) %>%
  ts(start = c(1895, 1), end = c(2021, 12), frequency = 12)

autoplot(drought.ts.ca) +
  ggtitle("California Droughts") +
  xlab("Year (1895-2021)") +
  ylab("Drought Index")

drought.ts.log <- log10(drought.ts.ca + 1 - min(drought.ts.ca))

ggAcf(drought.ts.ca) +
  ggtitle("ACF of California Droughts Time Series")

drought.ts.diff <- diff(diff(drought.ts.ca)) # d=1-2

ggsave("../arma_visualizations/drought/drought_stationary_acf_plot.svg", width = 8, height = 6, units = "in")
ggAcf(drought.ts.diff) +
  ggtitle("Diff ACF of California Droughts") # q=1-2
dev.off()

png("../arma_visualizations/drought/drought_stationary_pacf_plot.png", width = 8, height = 6, units = "in", res = 400)
pacf(drought.ts.diff, main = "PACF of California Droughts") # p=1-7
dev.off()

tseries::adf.test(drought.ts.log.diff)

i <- 1
temp <- data.frame()
ls <- matrix(rep(NA, 6 * 35), nrow = 35)

for (p in 1:7)
{
  for (q in 1:5)
  {
    for (d in 1:2)
    {
      if (p + d + q <= 8) {
        model <- Arima(drought.ts.ca, order = c(p, d, q), include.drift = FALSE)
        ls[i, ] <- c(p, d, q, model$aic, model$bic, model$aicc)
        print(ls[i, ])
        i <- i + 1
      }
    }
  }
}

temp <- as.data.frame(ls) %>%
  mutate_if(is.numeric, round, 3)
names(temp) <- c("p", "d", "q", "AIC", "BIC", "AICc")

write.csv(temp, "../arma_data/drought/arma_results.csv", row.names = FALSE)

temp[which.min(temp$AIC), ] # (5,1,1)
temp[which.min(temp$BIC), ] # (1,1,1) -- Generally the best

auto.arima(drought.ts.ca) # (0,1,0)

png("../arma_visualizations/drought/drought_sarima_1_1_1.png", width = 8, height = 6, units = "in", res = 400)
sarima(drought.ts.ca, 1, 1, 1)
dev.off()

png("../arma_visualizations/drought/drought_sarima_5_1_1.png", width = 8, height = 6, units = "in", res = 400)
sarima(drought.ts.ca, 5, 1, 1)
dev.off()

fit <- Arima(drought.ts.ca, order = c(5, 1, 1), include.drift = FALSE)
png("../arma_visualizations/drought/drought_arima_forecast_5_1_1.png", width = 8, height = 6, units = "in", res = 400)
autoplot(forecast(fit))
dev.off()

png("../arma_visualizations/drought/drought_sarima_forecast_5_1_1.png", width = 8, height = 6, units = "in", res = 400)
sarima.for(drought.ts.ca, 60, 5, 1, 1)
dev.off()

viz.forecast <- drought.ts.ca %>%
  Arima(order = c(5, 1, 1), include.drift = FALSE) %>%
  forecast() %>%
  autoplot() +
  ylab("Number of Droughts") + xlab("Year")
ggsave("../arma_visualizations/drought/drought_forecast_5_1_1.svg", plot = viz.forecast, width = 10, height = 6, units = "in")

length(drought.ts.ca)

train <- ts(drought.ts.ca[1:1200])
test <- ts(drought.ts.ca[1201:1524])
fit <- Arima(train, order = c(5, 1, 1), include.drift = FALSE)
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
  Model = c("Arima", "Mean Forecast", "Naive", "Random Walk Forecast"),
  MAE = c(mae1, mae11, mae12, mae13),
  MSE = c(mse1, mse11, mse12, mse13)
) %>%
  mutate_if(is.numeric, round, 3)
df
write.csv(df, "../arma_data/drought/drought_forecast_data.csv", row.names = FALSE)
