# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(tidyverse, gridExtra, TSstudio, 
               fpp, forecast, astsa, lubridate, zoo) 
# ---------------------------------------------

flood.df <- read.csv('../cleaned_data/floods/aggregated_flood_data.csv') %>% drop_na()
head(flood.df)
str(flood.df)

# Start with California
flood.ts.ca <- flood.df %>%
  filter(StateAbbreviation == 'CA') %>%
  select(NumberOfFloods) %>%
  ts(start = c(2006, 1), end = c(2020, 12), frequency = 12)

acf(flood.ts.ca, main = 'ACF of California Floods Time Series') # q = 1-2

pacf(flood.ts.ca, main = 'PACF of California Floods Time Series') # p = 1-2

tseries::adf.test(flood.ts.ca)

i = 1
temp = data.frame()
ls = matrix(rep(NA,6*8),nrow=8)

for (p in 0:1)
{
  for(q in 1:2)
  {
    for (d in 0:1)
    {
      if(p + d + q <= 6)
      {
        model <- Arima(flood.ts.ca,order=c(p,d,q), include.drift = FALSE)
        ls[i,] = c(p,d,q,model$aic,model$bic,model$aicc)
        i = i + 1
      }
    }
  }
}

temp <- as.data.frame(ls)
names(temp) <- c("p","d","q","AIC","BIC","AICc")

write.csv(temp, '../arma_data/floods/arma_results.csv', row.names = FALSE)

temp[which.min(temp$AIC),] # (0,1,2)
temp[which.min(temp$BIC),] # (0,1,2)

auto.arima(flood.ts.ca) # (0,1,2)

png('../arma_visualizations/floods/flood_sarima_0_1_2.png', width = 8, height = 6, units = 'in', res = 400)
sarima(flood.ts.ca,0,1,2)
dev.off()

fit <- Arima(flood.ts.ca, order=c(0,1,2), include.drift = FALSE)
png('../arma_visualizations/floods/flood_arima_forecast_0_1_2.png', width = 8, height = 6, units = 'in', res = 400)
autoplot(forecast(fit))
dev.off()

png('../arma_visualizations/floods/flood_sarima_forecast_0_1_2.png', width = 8, height = 6, units = 'in', res = 400)
sarima.for(flood.ts.ca, 60, 0,1,2)
dev.off()

viz.forecast <- flood.ts.ca %>%
  Arima(order=c(0,1,2),include.drift = FALSE) %>%
  forecast %>%
  autoplot() +
  ylab("Number of Floods") + xlab("Year")
ggsave('../arma_visualizations/floods/flood_forecast_0_1_2.svg', plot = viz.forecast, width = 10, height = 6, units = 'in')

length(flood.ts.ca)

train = ts(flood.ts.ca[1:150])
test = ts(flood.ts.ca[151:180])
fit <- Arima(train, order = c(0, 1, 2), include.drift = TRUE)
summary(fit)

pred <- forecast(fit, 30)
accuracy(pred)

f1 <- meanf(train, h = 30) 
accuracy(f1)
f2 <- naive(train, h = 30) 
accuracy(f2)
f3 <- rwf(train, drift = TRUE, h = 30)
accuracy(f3) 

mae1 <- abs(mean(as.numeric(pred$mean) - as.numeric((test))))
mae11 <- abs(mean(as.numeric(f1$mean) - as.numeric((test))))
mae12 <- abs(mean((as.numeric(f2$mean) - as.numeric((test)))))
mae13 <- abs(mean((as.numeric(f3$mean) - as.numeric((test)))))

mse1 <- abs(mean((as.numeric(pred$mean) - as.numeric((test))) ^ 2))
mse11 <- abs(mean((as.numeric(f1$mean) - as.numeric((test))) ^ 2))
mse12 <- abs(mean((as.numeric(f2$mean) - as.numeric((test))) ^ 2))
mse13 <- abs(mean((as.numeric(f3$mean) - as.numeric((test))) ^ 2))

df <- data.frame(Model = c('Arima', 'Mean Forecast', 'Naive', 'Random Walk Forecast'), 
                 MAE = c(mae1, mae11, mae12, mae13),
                 MSE = c(mse1, mse11, mse12, mse13))
df
write.csv(df, '../arma_data/floods/flood_forecast_data.csv', row.names = FALSE)
