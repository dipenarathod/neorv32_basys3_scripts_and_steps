import keras
from keras import models
from keras import layers
from keras.datasets import mnist
from keras.utils import to_categorical
import numpy as np
import tensorflow as tf
from convert_weights import quantize_q07

(train_images, train_labels), (test_images, test_labels)= mnist.load_data()

#Add number of channels
train_images=train_images.reshape(train_images.shape[0], 28, 28, 1)
test_images=test_images.reshape(test_images.shape[0], 28, 28, 1)

#Normalize images
train_images=train_images.astype('float32')/255.0
test_images=test_images.astype('float32')/255.0

train_14 = tf.image.resize(train_images, (14, 14), method="bilinear")
test_14  = tf.image.resize(test_images,  (14, 14), method="bilinear")

#Flatten
train_vec = tf.reshape(train_14, [-1, 14 * 14])  
test_vec  = tf.reshape(test_14,  [-1, 14 * 14])  

print("Train:", train_vec.shape, train_labels.shape)
print("Test :", test_vec.shape, test_labels.shape)

model = keras.Sequential([
    layers.Input(shape=(196,)),
    layers.Dense(32, activation="relu"),
    layers.Dense(10,activation="softmax")
])

model.compile(
    optimizer=keras.optimizers.Adam(1e-3),
    loss=keras.losses.SparseCategoricalCrossentropy(),
    metrics=["accuracy"]
)

model.fit(
    train_vec, train_labels,
    batch_size=256,
    epochs=11,
    validation_split=0.1,
    verbose=2
)

test_loss, test_acc = model.evaluate(test_vec, test_labels, verbose=0)
print("Test acc:", test_acc)

print(train_vec[0])
print(quantize_q07(train_vec[0]))
print(train_labels[0])

model.save(filepath="14x14_mnist_model.keras")
