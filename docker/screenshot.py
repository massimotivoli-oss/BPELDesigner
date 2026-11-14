from PIL import ImageGrab

ImageGrab.grab(xdisplay=':0').save('/tmp/eclipse-desktop.png')
print('/tmp/eclipse-desktop.png')
