import keras
from keras import models
from keras import layers
from keras.datasets import mnist
from keras.utils import to_categorical
import numpy as np
(train_images, train_labels), (test_images, test_labels)= mnist.load_data()
#Print dataset dimensions
print(train_images.shape)
print(train_labels.shape)
print(test_images.shape)
print(test_labels.shape)

#Add number of channels
train_images=train_images.reshape(train_images.shape[0], 28, 28, 1)
test_images=test_images.reshape(test_images.shape[0], 28, 28, 1)

#Normalize images
train_images=train_images.astype('float32')/255.0
test_images=test_images.astype('float32')/255.0

train_labels=to_categorical(train_labels, 10)
test_labels=to_categorical(test_labels, 10)

#First parameter in Conv2D = number of filters = number of features

#Problem: creates a lot of weights
# model = models.Sequential([
#     layers.Conv2D(32, kernel_size=(3, 3), input_shape=(28, 28, 1)), 
#     layers.Activation("relu"),
#     layers.MaxPooling2D(pool_size=(2, 2)),
#     layers.Conv2D(64, kernel_size=(3, 3)),
#     layers.Activation("relu"),
#     layers.MaxPooling2D(pool_size=(2, 2)),
#     layers.Flatten(),
#     layers.Dropout(0.5), #TODO in NPU
#     layers.Dense(10, activation="softmax"),
# ])

#Lighter model
#Output shape of a convolutional layer: [(W−K+2P)/S]+1.
#https://stackoverflow.com/questions/53580088/calculate-the-output-size-in-convolution-layer
#W is the input image width
#K is the Kernel size
#P is the padding = 0
#S is the stride = 1

#For max pooling layer output: https://keras.io/2/api/layers/pooling_layers/max_pooling2d/
#output_shape = math.floor((input_shape - pool_size) / strides) + 1 (when input_shape >= pool_size)
#Stride defaults to pool size
model = models.Sequential([
    layers.Conv2D(4, kernel_size=(3, 3), input_shape=(28, 28, 1)),
    #output shape = [(28-3)/1+1] = 26x26x4 = 2704 (4 comes from number of filters)
    
    layers.Activation("relu"),
    layers.MaxPooling2D(pool_size=(2, 2)),
    #Output shape = [(26-2)/2] + 1 = 13x13x8 = 1352
    
    layers.Conv2D(8, kernel_size=(3, 3)),
    #output shape = [(13-3)/1+1] = 11x11x8 = 968 (8 comes from number of filters)
    
    layers.Activation("relu"),
    layers.MaxPooling2D(pool_size=(2, 2)),
    #Output shape = [(11-2)/2] + 1 = 6x6x8 = 288 (or 5x5x8 = 200)
    
    layers.Flatten(),  #6x6x8 = 288 (or 5x5x8 = 200)
    layers.Dropout(0.5),
    layers.Dense(10), #288*10 = 2880 or 200*10 = 2000 
    layers.Activation("softmax")
    #Total weights/biases = 2704 + 1352 + 968 + 288 + 288 + 2880 = 8.4KB
])

model.compile(optimizer="rmsprop", loss="categorical_crossentropy", metrics=["accuracy"])
#Optimizer, loss functions, and metrics are only required for training

model.fit(train_images, train_labels, epochs=100,batch_size=128,verbose=2,validation_split=0.3)

#Evaluate model
test_loss, test_acc = model.evaluate(test_images, test_labels)
print("Test accuracy: ", test_acc)

print(model.get_weights())
model.save_weights(filepath="/home/dipen/Downloads/PythonProjects/keras_mnist_test_weights/model_weights.weights.h5")
