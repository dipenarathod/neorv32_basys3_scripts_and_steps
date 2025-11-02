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

model = models.Sequential([
    layers.Conv2D(32, kernel_size=(3, 3), input_shape=(28, 28, 1)), 
    layers.Activation("relu"),
    layers.MaxPooling2D(pool_size=(2, 2)),
    layers.Conv2D(64, kernel_size=(3, 3)),
    layers.Activation("relu"),
    layers.MaxPooling2D(pool_size=(2, 2)),
    layers.Flatten(),
    layers.Dropout(0.5), #TODO in NPU
    layers.Dense(10, activation="softmax"),
])

model.compile(optimizer="rmsprop", loss="categorical_crossentropy", metrics=["accuracy"])
#Optimizer, loss functions, and metrics are only required for training

model.fit(train_images, train_labels, epochs=100,batch_size=128,verbose=2,validation_split=0.3)

#Evaluate model
test_loss, test_acc = model.evaluate(test_images, test_labels)
print("Test accuracy: ", test_acc)
