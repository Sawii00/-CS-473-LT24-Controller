# Hardware Controller for LT24 LCD

This is the final project for the course CS-473 (Embedded Systems) at EPFL, where we had to design both the hardware implementation and software for an accelerator that fetches in DMA-like fashion from memory an image and transmits it to the LT24 display by adhering to the custom protocol defined by the ILI9341 controller. 
The user can specify the configuration of the display by sending command packets, and finally start the image transmission. 

The image can be read from a file to memory, or directly written there by an external camera. 

The final task was indeed to interface with another group to directly display the image captured by their camera on our display.

## Top-Level Overview
![image](https://user-images.githubusercontent.com/23176335/178516121-5508a517-b671-4fda-9f84-097a6d2400fb.png)

![image](https://user-images.githubusercontent.com/23176335/178516198-64544445-530b-4e70-9c6d-187d1e204777.png)

## Hardware Implementation

We split the design across two main components: DMA, and LCD Controller. 
The DMA has the task of fetching the image from memory and inserting the pixel values within a hardware FIFO used to interface with the LCD controller. 
The LCD controller has to send commands to the ILI controller specified by the user, or pixel data. Since the components operate at different frequencies, we had to interpose a FIFO. 
All the configuration can be provided by the user through the following register map. 

![image](https://user-images.githubusercontent.com/23176335/178516793-e9b5bc3f-e97f-4485-87d2-40733ef774af.png)

## More Information
Report: https://drive.google.com/file/d/1zMULhoCsnjM_YXiwNWF954S0zQ_t0bnZ/view?usp=sharing
