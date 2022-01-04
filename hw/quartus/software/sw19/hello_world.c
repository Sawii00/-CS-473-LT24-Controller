/*
 * "Hello World" example.
 *
 * This example prints 'Hello from Nios II' to the STDOUT stream. It runs on
 * the Nios II 'standard', 'full_featured', 'fast', and 'low_cost' example
 * designs. It runs with or without the MicroC/OS-II RTOS and requires a STDOUT
 * device in your system's hardware.
 * The memory footprint of this hosted application is ~69 kbytes by default
 * using the standard reference design.
 *
 * For a reduced footprint version of this template, and an explanation of how
 * to reduce the memory footprint for a given application, see the
 * "small_hello_world" template.
 *
 */

#include <inttypes.h>
#include "system.h"
#include "io.h"
#include "stdio.h"
#include "stdarg.h"

#define IMAGE_ADDRESS 0
#define IMAGE_LENGTH 4
#define FLAGS 8
#define COMMAND_REG 10
#define N_PARAMS 12
#define PARAM(n) 14 + n * 2

void set_flag(uint16_t val)
{
	uint16_t flags = IORD_16DIRECT(LCD_0_BASE, FLAGS);
	IOWR_16DIRECT(LCD_0_BASE, FLAGS,  val);
}

void reset_lcd()
{
	set_flag(0x4);
	uint16_t flags = IORD_16DIRECT(LCD_0_BASE, FLAGS);

	while(flags & 0x4)
	{
		flags = IORD_16DIRECT(LCD_0_BASE, FLAGS);
	}
}
/*
void send_command(uint16_t cmd, uint16_t n, ...)
{
	va_list argp;
	va_start(argp, n);

	uint16_t i = 0;

	IOWR_16DIRECT(LCD_0_BASE, COMMAND_REG, cmd);
	IOWR_16DIRECT(LCD_0_BASE, N_PARAMS, n);


	while(i < n)
	{
		uint16_t param = (uint16_t)va_arg(argp, int);
		IOWR_16DIRECT(LCD_0_BASE, PARAM(i), param);
		++i;
	}
	va_end(argp);

	IOWR_16DIRECT(LCD_0_BASE, FLAGS, 0x2); //send command flag
	uint16_t flags = IORD_16DIRECT(LCD_0_BASE, FLAGS);
	while(flags & 0x2)
	{
		flags = IORD_16DIRECT(LCD_0_BASE, FLAGS);
	}
}
*/

void send_command(uint16_t cmd, uint16_t n, uint16_t* params)
{
	uint16_t i = 0;



	IOWR_16DIRECT(LCD_0_BASE, COMMAND_REG, cmd);
	IOWR_16DIRECT(LCD_0_BASE, N_PARAMS, n);


	while(i < n)
	{
		IOWR_16DIRECT(LCD_0_BASE, PARAM(i), params[i]);
		++i;
	}
	IOWR_16DIRECT(LCD_0_BASE, FLAGS, 0x2); //send command flag
	uint16_t flags = IORD_16DIRECT(LCD_0_BASE, FLAGS);
	while(flags & 0x2)
	{
		flags = IORD_16DIRECT(LCD_0_BASE, FLAGS);
	}
}

void start_lcd()
{
	//set_flag(0x1);
	uint16_t flags = IORD_16DIRECT(LCD_0_BASE, FLAGS);
	printf("flags: %x \n", flags);
	IOWR_16DIRECT(LCD_0_BASE, FLAGS,0x1);
	flags = IORD_16DIRECT(LCD_0_BASE, FLAGS);
	printf("flags: %x \n", flags);

	while(flags & 0x1)
	{

		flags = IORD_16DIRECT(LCD_0_BASE, FLAGS);
	}
}

void init_lcd()
{
	send_command(0x11, 0, (uint16_t []){ 0x09, 0x0a});
	send_command(0xcf, 3, (uint16_t []){ 0x0, 0x81, 0xc0});
	send_command(0xed, 4, (uint16_t []){ 0x64, 0x03, 0x12, 0x81});
	send_command(0xe8, 3, (uint16_t []){ 0x85, 0x01, 0x0798});
	send_command(0xcb, 5, (uint16_t []){ 0x39, 0x2c, 0x00, 0x34, 0x02});
	send_command(0xf7, 1, (uint16_t []){ 0x20});
	send_command(0xea, 2, (uint16_t []){ 0x00, 0x00});
	send_command(0xb1, 2, (uint16_t []){ 0x00, 0x1b});
	send_command(0xb6, 2, (uint16_t []){ 0x0a, 0xa2});
	send_command(0xc0, 1, (uint16_t []){ 0x05});
	send_command(0xc1, 1, (uint16_t []){ 0x11});
	send_command(0xc5, 2, (uint16_t []){ 0x45, 0x45});
	send_command(0xc7, 1, (uint16_t []){ 0xa2});
	send_command(0x36, 1, (uint16_t []){ 0x08}); //RGB
	send_command(0xf2, 1, (uint16_t []){ 0x00});
	send_command(0x26, 1, (uint16_t []){ 0x01});
	send_command(0xe0, 15, (uint16_t []){ 0xf, 0x26, 0x24, 0xb, 0xe, 0x8, 0x4b, 0xa8, 0x3b, 0x0a, 0x14, 0x06, 0x10, 0x09, 0x00});
	send_command(0xe1, 15, (uint16_t []){ 0x0, 0x1c, 0x20, 0x4, 0x10, 0x8, 0x34, 0x47, 0x44, 0x05, 0xb, 0x9, 0x2f, 0x36, 0x0f});
	send_command(0x2a, 4, (uint16_t []){ 0x0, 0x0, 0x0, 0xef});
	send_command(0x2b, 4, (uint16_t []){ 0x0, 0x0, 0x01, 0x3f});
	send_command(0x3a, 1, (uint16_t []){ 0x55}); //RGB
	send_command(0xf6, 3, (uint16_t []){ 0x01, 0x30, 0x0});
	send_command(0x29, 0, (uint16_t []){ });
}
void configure_image(uint32_t image_address, uint32_t image_size)
{
	IOWR_32DIRECT(LCD_0_BASE, IMAGE_ADDRESS, image_address);
	IOWR_32DIRECT(LCD_0_BASE, IMAGE_LENGTH, image_size);
}

void init_image(uint32_t *image_address, uint32_t image_size)
{
	uint32_t i = 0;
	while(i < image_size / sizeof(uint16_t))
	{
		image_address[i] = 0xAB;
		++i;
	}
}

void fill_memory(uint32_t image_size){
int check;
	for(uint32_t i=0; i< image_size;i=i+4){
		IOWR_32DIRECT(HPS_0_BRIDGES_BASE,i,0xF800F800);
		check = IORD_32DIRECT(HPS_0_BRIDGES_BASE, i);
		if(check != 0xf800f800){
			printf("--");
		}
	}
}


int main()
{

	printf("reset\n");
	reset_lcd();
	printf("init\n");
	init_lcd();
	volatile int i;
	for(i=0;i<10000;i++);
	printf("init done\n");
	uint32_t image_size = 320 * 480 * sizeof(uint16_t);
	uint32_t image_address = HPS_0_BRIDGES_BASE;
	printf("init image\n");
	//init_image(image_address, image_size);
	fill_memory(image_size);
	printf("init image done\n");
	printf("configure done\n");
	printf("memory filled\n");
	printf("start");
	configure_image(HPS_0_BRIDGES_BASE, image_size);
	start_lcd();
	printf("start done\n");
	return 0;
}
