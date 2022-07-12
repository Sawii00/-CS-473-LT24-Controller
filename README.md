# Hardware Controller for LT24 LCD

This is the final project for the course CS-473 (Embedded Systems) at EPFL, where we had to design both the hardware implementation and software for an accelerator that fetches in DMA-like fashion from memory an image and transmits it to the LT24 display by adhering to the custom protocol defined by the ILI9341 controller. 
The user can specify the configuration of the display by sending command packets, and finally start the image transmission. 

The image can be read from a file to memory, or directly written there by an external camera. 

The final task was indeed to interface with another group to directly display the image captured by their camera on our display.

![image](https://user-images.githubusercontent.com/23176335/178516121-5508a517-b671-4fda-9f84-097a6d2400fb.png)

![image](https://user-images.githubusercontent.com/23176335/178516198-64544445-530b-4e70-9c6d-187d1e204777.png)
