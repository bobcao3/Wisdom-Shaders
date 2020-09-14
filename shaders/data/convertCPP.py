import cv2
import numpy as np

img = np.array(cv2.imread('HDR_RGBA_0.png', cv2.IMREAD_UNCHANGED))

print(img.dtype)

img = img[:,:,0]
img = img.astype('uint16')

cpp = "const uint16_t _blueNoise[" + str(img.size) + "] = {"

perLine = 0
for i in img.flatten():
    cpp += str(i) + "u, "
    perLine += 1
    if perLine % 16 == 0:
        cpp += "\n"

cpp += "};"

print(cpp)