#!/usr/bin/python3

"""
    Initialize plots

"""

import numpy as np
from PIL import Image
import matplotlib.pyplot as plt
import csv

fig = plt.figure('Evolutionary Algorithm')
rows = 2
cols = 3

"""
    Show input and output data

"""

# Define width and height
w, h = 128, 128

# Read input file #1 using numpy "fromfile()"
with open('LENA_S05.GRY', mode='rb') as f:
    d = np.fromfile(f,dtype=np.uint8,count=w*h).reshape(h,w)

# Convert into image and plot
img_in1 = Image.fromarray(d)
fig.add_subplot(rows, cols, 1)
plt.imshow(img_in1, cmap='gray')
plt.title('Input Image')

# Read result file #1 using numpy "fromfile()"
with open('RES1.GRY', mode='rb') as f:
    d = np.fromfile(f,dtype=np.uint8,count=w*h).reshape(h,w)

# Convert into image
img_res1 = Image.fromarray(d)
fig.add_subplot(rows, cols, 2)
plt.imshow(img_res1, cmap='gray')
plt.title('Output Image')

# Read input file #2 using numpy "fromfile()"
with open('LENA_B15.GRY', mode='rb') as f:
    d = np.fromfile(f,dtype=np.uint8,count=w*h).reshape(h,w)

# Convert into image
img_in2 = Image.fromarray(d)
fig.add_subplot(rows, cols, 4)
plt.imshow(img_in2, cmap='gray')

# Read result file #2 using numpy "fromfile()"
with open('RES2.GRY', mode='rb') as f:
    d = np.fromfile(f,dtype=np.uint8,count=w*h).reshape(h,w)

# Convert into image
img_res2 = Image.fromarray(d)
fig.add_subplot(rows, cols, 5)
plt.imshow(img_res2, cmap='gray')


"""
    Plot fitness

"""

x = []
y = []

with open('EVOLUTION1.CSV','r') as csvfile:
    plots = csv.reader(csvfile, delimiter = ',')
    next(plots)

    for row in plots:
        x.append(int(row[0]))
        y.append(int(row[1]))

fig.add_subplot(rows, cols, 3)
plt.plot(x, y)
plt.xlabel('Generation')
plt.ylabel('Fitness')
plt.grid()

x = []
y = []

with open('EVOLUTION2.CSV','r') as csvfile:
    plots = csv.reader(csvfile, delimiter = ',')
    next(plots)

    for row in plots:
        x.append(int(row[0]))
        y.append(int(row[1]))

fig.add_subplot(rows, cols, 6)
plt.plot(x, y)
plt.xlabel('Generation')
plt.ylabel('Fitness')
plt.grid()
plt.show()
