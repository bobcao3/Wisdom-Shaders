import cv2
import numpy as np

img = np.array(cv2.imread('HDR_RGBA_0.png', cv2.IMREAD_UNCHANGED))

print(img.dtype)

img = img[:,:,0]
img = img.astype('uint16')
img.tofile('noise_256.dat')

print(img.shape)