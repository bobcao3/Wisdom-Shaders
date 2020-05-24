import cv2
import numpy as np

img = np.array(cv2.imread('HDR_RGBA_0.png', cv2.IMREAD_UNCHANGED))
img = img.astype('float') / 65536.0
img.astype('float16').tofile('noise_256.dat')

print(img.shape)