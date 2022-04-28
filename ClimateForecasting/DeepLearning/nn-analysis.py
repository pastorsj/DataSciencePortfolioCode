import numpy as np
import pandas as pd
import math
from sklearn.metrics import mean_squared_error
from matplotlib import pyplot as plt

from keras.models import Sequential
from keras.layers import Dense, SimpleRNN, LSTM, GRU
from keras import regularizers

weather_df = pd.read_csv('../cleaned_data/weather/weather_data.csv')
weather_df = weather_df[weather_df['State'] == 'California'].reset_index()
print(weather_df.shape)
weather_df = weather_df[['Date', 'AverageTemperature']]
weather_df['Date'] = pd.to_datetime(weather_df['Date'])
weather_df['AverageTemperature'] = pd.to_numeric(
    weather_df['AverageTemperature'], errors='coerce')
weather_df = weather_df.dropna(subset=['AverageTemperature'])
weather_df.sort_values('Date', inplace=True, ascending=True)
weather_df = weather_df.reset_index(drop=True)


"""
---- Source ----
https://towardsdatascience.com/single-and-multi-step-temperature-time-series-forecasting-for-vilnius-using-lstm-deep-learning-b9719a0009de
"""


def create_X_Y(ts: np.array, lag=1, n_ahead=1, target_index=0) -> tuple:
    """
    A method to create X and Y matrix from a time series array for the training of 
    deep learning models 
    """
    # Extracting the number of features that are passed from the array
    n_features = ts.shape[1]

    # Creating placeholder lists
    X, Y = [], []

    if len(ts) - lag <= 0:
        X.append(ts)
    else:
        for i in range(len(ts) - lag - n_ahead):
            Y.append(ts[(i + lag):(i + lag + n_ahead), target_index])
            X.append(ts[i:(i + lag)])

    X, Y = np.array(X), np.array(Y)

    # Reshaping the X array to an RNN input shape
    X = np.reshape(X, (X.shape[0], lag, n_features))

    return X, Y


print(weather_df.head())
print(weather_df.shape)

ts = weather_df[['AverageTemperature']].values
print(ts)
print(ts.shape)

nrows = ts.shape[0]
test_share = 0.1
# Spliting into train and test sets
train = ts[0:int(nrows * (1 - test_share))]
test = ts[int(nrows * (1 - test_share)):]

# Scaling the data
train_mean = train.mean()
train_std = train.std()
train = (train - train_mean) / train_std
test = (test - train_mean) / train_std

# Creating the final scaled frame
ts_s = np.concatenate([train, test])

lag = 12
ahead = 3

# Creating the X and Y for training
X, Y = create_X_Y(ts_s, lag=lag, n_ahead=ahead)

Xtrain = X[0:int(X.shape[0] * (1 - test_share))]
Ytrain = Y[0:int(X.shape[0] * (1 - test_share))]

Xval = X[int(X.shape[0] * (1 - test_share)):]
Yval = Y[int(X.shape[0] * (1 - test_share)):]


def plot_model(history, model_title, filename):
    print('History', history.history)
    loss = history.history['loss']
    epochs = range(1, len(loss) + 1)
    plt.figure()
    plt.plot(epochs, loss, 'b', label='Training loss')
    plt.title(f'Training loss ({model_title})')
    plt.legend()
    plt.savefig(f'../nn_visualizations/{filename}')


def print_error(trainY, testY, train_predict, test_predict):
    # Error of predictions
    train_rmse = math.sqrt(mean_squared_error(
        trainY[:, 0], train_predict[:, 0]))
    test_rmse = math.sqrt(mean_squared_error(testY[:, 0], test_predict[:, 0]))
    # Print RMSE
    print('Train RMSE: %.3f RMSE' % (train_rmse))
    print('Test RMSE: %.3f RMSE' % (test_rmse))
    return train_rmse, test_rmse


def create_RNN(hidden_units, dense_units, input_shape, activation, kernel_regularizer=None):
    model = Sequential()
    # Create a simple neural network layer
    model.add(SimpleRNN(hidden_units, input_shape=input_shape,
              activation=activation[0]))
    # Add a dense layer (only one, more layers would make it a deep neural net)
    model.add(Dense(units=dense_units,
              activation=activation[1],
              kernel_regularizer=kernel_regularizer))
    # Compile the model and optimize on mean squared error
    model.compile(loss='mean_squared_error', optimizer='adam')
    return model


# Create a LSTM Neural Network
def create_LSTM(hidden_units, dense_units, input_shape, activation, kernel_regularizer=None):
    model = Sequential()
    # Create a simple long short term memory neural network
    model.add(LSTM(hidden_units,
              activation=activation[0], input_shape=input_shape))
    # Add a dense layer (only one, more layers would make it a deep neural net)
    model.add(Dense(units=dense_units,
              activation=activation[1], kernel_regularizer=kernel_regularizer))
    # Compile the model and optimize on mean squared error
    model.compile(optimizer="RMSprop", loss='mae')
    return model


# Create a GRU Neural Network
def create_GRU(hidden_units, dense_units, input_shape, activation, kernel_regularizer=None):
    model = Sequential()
    # Create a simple GRU neural network layer
    model.add(GRU(hidden_units, input_shape=input_shape,
              activation=activation[0]))
    # Add a dense layer (only one, more layers would make it a deep neural net)
    model.add(Dense(units=dense_units,
              activation=activation[1], kernel_regularizer=kernel_regularizer))
    # Compile the model and optimize on mean squared error
    model.compile(loss='mean_squared_error', optimizer='sgd')
    return model

# ------------------------------------------------------------------------------------


# Create a recurrent neural network
model = create_RNN(hidden_units=3, dense_units=1, input_shape=(lag, Xtrain.shape[-1]),
                   activation=['tanh', 'tanh'])
history = model.fit(Xtrain, Ytrain, epochs=20, batch_size=1, verbose=2)
plot_model(history, 'Recurrent Neural Network Model', 'rnn_model.png')

yhat_d = [x[0] for x in model.predict(Xval)]
y = [y[0] for y in Yval]

train_predict = model.predict(Xtrain)
test_predict = model.predict(Xval)

# Print error
train_rmse, test_rmse = print_error(Ytrain, Yval, train_predict, test_predict)
rmse_table = {
    'model': ['Recurrent Neural Network'],
    'training_rmse': [train_rmse],
    'testing_rmse': [test_rmse]
}

# ------------------------------------------------------------------------------------

# Create a recurrent neural network with regularization
model = create_RNN(hidden_units=3, dense_units=1, input_shape=(lag, Xtrain.shape[-1]),
                   activation=['tanh', 'tanh'], kernel_regularizer=regularizers.L1L2(l1=1e-5, l2=1e-4))
history = model.fit(Xtrain, Ytrain, epochs=20, batch_size=1, verbose=2)
plot_model(history, 'Recurrent Neural Network Model (with L1L2 Regularization)',
           'rnn_reg_model.png')

yhat_d_reg = [x[0] for x in model.predict(Xval)]

train_predict = model.predict(Xtrain)
test_predict = model.predict(Xval)

# Print error
train_rmse, test_rmse = print_error(Ytrain, Yval, train_predict, test_predict)
rmse_table['model'].append(
    'Recurrent Neural Network (with L1L2 Regularization)')
rmse_table['training_rmse'].append(train_rmse)
rmse_table['testing_rmse'].append(test_rmse)

# ------------------------------------------------------------------------------------

# Training and evaluating a GRU-based model
model = create_GRU(hidden_units=3, dense_units=1, input_shape=(lag, Xtrain.shape[-1]),
                   activation=['tanh', 'relu'])
history = model.fit(Xtrain, Ytrain, epochs=20, batch_size=1, verbose=2)
plot_model(history, 'GRU Model', 'gru_model.png')

yhat_gru = [x[0] for x in model.predict(Xval)]

train_predict = model.predict(Xtrain)
test_predict = model.predict(Xval)

# Print error
train_rmse, test_rmse = print_error(Ytrain, Yval, train_predict, test_predict)
rmse_table['model'].append('GRU Neural Network')
rmse_table['training_rmse'].append(train_rmse)
rmse_table['testing_rmse'].append(test_rmse)

# ------------------------------------------------------------------------------------

# Training and evaluating a GRU-based model with regularization
model = create_GRU(hidden_units=3, dense_units=1, input_shape=(lag, Xtrain.shape[-1]),
                   activation=['tanh', 'relu'], kernel_regularizer=regularizers.L1L2(l1=1e-5, l2=1e-4))
history = model.fit(Xtrain, Ytrain, epochs=20, batch_size=1, verbose=2)
plot_model(history, 'GRU Model (with L1L2 Regularization)', 'gru_reg_model.png')

yhat_gru_reg = [x[0] for x in model.predict(Xval)]

train_predict = model.predict(Xtrain)
test_predict = model.predict(Xval)

# Print error
train_rmse, test_rmse = print_error(Ytrain, Yval, train_predict, test_predict)
rmse_table['model'].append('GRU Neural Network (with L1L2 Regularization)')
rmse_table['training_rmse'].append(train_rmse)
rmse_table['testing_rmse'].append(test_rmse)

# ------------------------------------------------------------------------------------

# Create an LSTM neural network
model = create_LSTM(hidden_units=3, dense_units=1, input_shape=(lag, Xtrain.shape[-1]),
                    activation=['tanh', 'linear'])
history = model.fit(Xtrain, Ytrain, epochs=20, batch_size=1, verbose=2)
plot_model(history, 'LSTM Model', 'lstm_model.png')

yhat_lstm = [x[0] for x in model.predict(Xval)]

train_predict = model.predict(Xtrain)
test_predict = model.predict(Xval)

# Print error
train_rmse, test_rmse = print_error(Ytrain, Yval, train_predict, test_predict)
rmse_table['model'].append('LSTM Neural Network')
rmse_table['training_rmse'].append(train_rmse)
rmse_table['testing_rmse'].append(test_rmse)

# ------------------------------------------------------------------------------------

# Create an LSTM neural network with regularization
model = create_LSTM(hidden_units=3, dense_units=1, input_shape=(lag, Xtrain.shape[-1]),
                    activation=['tanh', 'linear'], kernel_regularizer=regularizers.L1L2(l1=1e-5, l2=1e-4))
history = model.fit(Xtrain, Ytrain, epochs=20, batch_size=1, verbose=2)
plot_model(history, 'LSTM Model (with L1L2 Regularization)',
           'lstm_reg_model.png')

yhat_lstm_reg = [x[0] for x in model.predict(Xval)]

train_predict = model.predict(Xtrain)
test_predict = model.predict(Xval)

# Print error
train_rmse, test_rmse = print_error(Ytrain, Yval, train_predict, test_predict)
rmse_table['model'].append('LSTM Neural Network (with L1L2 Regularization)')
rmse_table['training_rmse'].append(train_rmse)
rmse_table['testing_rmse'].append(test_rmse)

# ------------------------------------------------------------------------------------

# Creating the frame to store both predictions
days = weather_df['Date'].values[-len(y):]
frame = pd.concat([
    pd.DataFrame({'day': days, 'temp': y, 'type': 'original'}),
    pd.DataFrame({'day': days, 'temp': yhat_d, 'type': 'rnn_forecast'}),
    pd.DataFrame({'day': days, 'temp': yhat_gru, 'type': 'gru_forecast'}),
    pd.DataFrame({'day': days, 'temp': yhat_lstm, 'type': 'lstm_forecast'})
])
# Creating the unscaled values column
frame['temp_absolute'] = [(x * train_std) + train_mean for x in frame['temp']]
# Pivoting
pivoted = frame.pivot_table(index='day', columns='type')
print('Pivoted', pivoted)
pivoted.columns = ['_'.join(x).strip() for x in pivoted.columns.values]

plt.figure(figsize=(12, 10))
plt.plot(pivoted.index, pivoted.temp_absolute_original,
         color='blue', label='original')
plt.plot(pivoted.index, pivoted.temp_absolute_rnn_forecast,
         color='red', label='RNN Forecast', alpha=0.6)
plt.plot(pivoted.index, pivoted.temp_absolute_gru_forecast,
         color='green', label='GRU Forecast', alpha=0.6)
plt.plot(pivoted.index, pivoted.temp_absolute_lstm_forecast,
         color='orange', label='LSTM Forecast', alpha=0.6)
plt.title('Temperature Forecasts')
plt.legend()
plt.savefig('../nn_visualizations/nn_forecasts.png')

# ------------------------------------------------------------------------------------

# Creating the frame to store both predictions
days = weather_df['Date'].values[-len(y):]
frame = pd.concat([
    pd.DataFrame({'day': days, 'temp': y, 'type': 'original'}),
    pd.DataFrame({'day': days, 'temp': yhat_d_reg, 'type': 'rnn_forecast'}),
    pd.DataFrame({'day': days, 'temp': yhat_gru_reg, 'type': 'gru_forecast'}),
    pd.DataFrame({'day': days, 'temp': yhat_lstm_reg, 'type': 'lstm_forecast'})
])
# Creating the unscaled values column
frame['temp_absolute'] = [(x * train_std) + train_mean for x in frame['temp']]
# Pivoting
pivoted = frame.pivot_table(index='day', columns='type')
print('Pivoted', pivoted)
pivoted.columns = ['_'.join(x).strip() for x in pivoted.columns.values]

plt.figure(figsize=(12, 10))
plt.plot(pivoted.index, pivoted.temp_absolute_original,
         color='blue', label='original')
plt.plot(pivoted.index, pivoted.temp_absolute_rnn_forecast,
         color='red', label='RNN Forecast', alpha=0.6)
plt.plot(pivoted.index, pivoted.temp_absolute_gru_forecast,
         color='green', label='GRU Forecast', alpha=0.6)
plt.plot(pivoted.index, pivoted.temp_absolute_lstm_forecast,
         color='orange', label='LSTM Forecast', alpha=0.6)
plt.title('Temperature Forecasts (with Regularization)')
plt.legend()
plt.savefig('../nn_visualizations/nn_reg_forecasts.png')

# ------------------------------------------------------------------------------------

rmse_df = pd.DataFrame(rmse_table)
print(rmse_df)
rmse_df.to_csv('../nn_data/rmse.csv', index=False)
