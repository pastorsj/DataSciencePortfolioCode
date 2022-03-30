# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(
  tidyverse, gridExtra, fGarch, dynlm, tseries, astsa, xts, 
  fpp, quantmod, imputeTS, lubridate, plotly, htmlwidgets
)
# ---------------------------------------------

# Get Information on Chevron prices from Yahoo Finance
chevron.price <- getSymbols("CVX", auto.assign = FALSE, from = "2000-01-01", src = "yahoo")

chevron.price.df <- data.frame(chevron.price)
chevron.price.df <- data.frame(chevron.price.df, Date = rownames(chevron.price.df))
head(chevron.price.df)
write.csv(chevron.price.df, "../arch_data/price/price-data.csv", row.names = FALSE)

fig <- chevron.price.df %>% plot_ly(x = ~Date, type="candlestick",
                      open = ~CVX.Open, close = ~CVX.Close,
                      high = ~CVX.High, low = ~CVX.Low) 
fig <- fig %>% layout(title = "Candlestick Chart of Chevron Stock Prices")
htmlwidgets::saveWidget(fig, "../arch_visualizations/price/price_over_time.html")

price.close <- Ad(chevron.price)

returns <- diff(log(price.close))

png("../arch_visualizations/price/returns_chart.png", width = 8, height = 6, units = "in", res = 400)
chartSeries(returns, theme = 'white')
dev.off()

png("../arch_visualizations/price/returns_candle_plot.png", width = 8, height = 6, units = "in", res = 400)
candleChart(chevron.price, multi.col = TRUE, theme = "white")
dev.off()

ggAcf(log(price.close)) +
  ggtitle("ACF of Log Transformed Chevron Prices")
ggsave("../arch_visualizations/price/price_log_acf_plot.svg", width = 8, height = 6, units = "in")

ggAcf(returns, lag.max = 100) +
  ggtitle("ACF of Log Transformed and Differenced Chevron Prices")
ggsave("../arch_visualizations/price/price_log_diff_acf_plot.svg", width = 8, height = 6, units = "in")

ggPacf(returns, lag.max = 100) +
  ggtitle("PACF of Log Transformed and Differenced Chevron Prices")
ggsave("../arch_visualizations/price/price_log_diff_pacf_plot.svg", width = 8, height = 6, units = "in")

ggAcf(abs(returns), lag.max = 100) +
  ggtitle("ACF of Absolute Chevron Prices")
ggsave("../arch_visualizations/price/price_absolute_acf_plot.svg", width = 8, height = 6, units = "in")

ggAcf(returns^2, lag.max = 100) +
  ggtitle("ACF of Squared Chevron Prices")
ggsave("../arch_visualizations/price/price_squared_acf_plot.svg", width = 8, height = 6, units = "in")

ggPacf(returns^2, lag.max = 100) +
  ggtitle("PACF of Squared Chevron Prices")
ggsave("../arch_visualizations/price/price_squared_pacf_plot.svg", width = 8, height = 6, units = "in")

d = 1
i = 1
temp = data.frame()
ls = matrix(rep(NA,6*9),nrow=9)

for (p in 1:4)
{
  for(q in 1:3)
  {
    if(p + d + q <= 6)
    {
      model <- Arima(log(price.close),order=c(p,d,q), include.drift = TRUE)
      ls[i,] = c(p,d,q,model$aic,model$bic,model$aicc)
      i = i + 1
    }
  }
}

temp = as.data.frame(ls)
names(temp) = c("p","d","q","AIC","BIC","AICc")

write.csv(temp, "../arch_data/price/arma_results.csv", row.names = FALSE)

temp
temp[which.min(temp$AIC),]
temp[which.min(temp$BIC),]

fit <- arima(returns, order = c(1, 1, 1))
summary(fit)

auto.arima(log(price.close))

res.arima <- fit$res
squared.res.arima <- res.arima^2

autoplot(squared.res.arima, main = "Squared Residuals")
ggsave("../arch_visualizations/price/squared_residuals_plot.svg", width = 8, height = 6, units = "in")

ggAcf(squared.res.arima, na.action = na.pass) + ggtitle("ACF Squared Residuals")
ggsave("../arch_visualizations/price/squared_residuals_acf.svg", width = 8, height = 6, units = "in")

ggPacf(squared.res.arima, na.action = na.pass) + ggtitle("PACF Squared Residuals")
ggsave("../arch_visualizations/price/squared_residuals_pacf.svg", width = 8, height = 6, units = "in")

res.arima <- na.omit(res.arima)
ARCH <- list() ## set counter
cc <- 1
for (p in 1:7) {
  ARCH[[cc]] <- garch(res.arima, order = c(0, p), trace = F)
  cc <- cc + 1
}

## get AIC values for model evaluation
ARCH_AIC <- sapply(ARCH, AIC) ## model with lowest AIC is the best
min(ARCH_AIC)
which(ARCH_AIC == min(ARCH_AIC))
ARCH[[which(ARCH_AIC == min(ARCH_AIC))]]

arch.df <- data.frame(p = 1:7, q = 0, AIC = ARCH_AIC)

write.csv(arch.df, "../arch_data/price/arch_results.csv", row.names = FALSE)

g.fit <- garchFit(~ arma(1, 1) + garch(7, 0), returns[-1, ])
summary(g.fit)

fit2 <- garch(res.arima, order = c(0,7), trace = FALSE)
summary(fit2)

png("../arch_visualizations/price/residuals_plot.png", width = 8, height = 6, units = "in", res = 400)
checkresiduals(fit2)
dev.off()

png("../arch_visualizations/price/qqnorm_residuals.png", width = 8, height = 6, units = "in", res = 400)
qqnorm(fit2$residuals, pch = 1)
qqline(fit2$residuals, col = "blue", lwd = 2)
dev.off()

Box.test(fit2$residuals, type = "Ljung")
