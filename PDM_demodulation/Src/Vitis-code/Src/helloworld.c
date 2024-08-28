/******************************************************************************
* Copyright (C) 2023 Advanced Micro Devices, Inc. All Rights Reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/
/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xgpiops.h"
#include "xparameters.h"
#include "xstatus.h"
#include "xplatform_info.h"
#include "xbasic_types.h"
#include "xinterrupt_wrap.h"
#include "xil_exception.h"
#include "xscutimer.h"


#define	XGPIOPS_BASEADDR	XPAR_XGPIOPS_0_BASEADDR
#define printf			xil_printf	/* Smalller foot-print printf */
#define GPIO_BANK	XGPIOPS_BANK2  /* Bank 2 of the GPIO Device */
#define Input_Bank_Pin 16
#define INTC_INTERRUPT_ID_0 61  // IRQ_F2P[0:0]

#define offset 54
#define width 18

#define buff 300000
//#define buff 10000
#define TIMER_LOAD_VALUE	30 //0xFFFF

#define exp 10000

// global instances

static XScuGic intc; // instance of interrupt controller
XGpioPs Gpio;	/* The driver instance for GPIO Device. */
#ifndef TESTAPP_GEN
XScuTimer TimerInstance;	/* Cortex A9 Scu Private Timer Instance */
#endif

// declarations

void flush_buffer(void);
void clear_buffer(void);
u32 combine(u32 data[width]);
int init_gpio(UINTPTR BaseAddress);
int init_timer(XScuTimer *TimerInstancePtr, UINTPTR BaseAddress);
int init_intr(XGpioPs *Gpio, UINTPTR BaseAddress);
int init_intr_system();
static void IntrHandler(void *CallBackRef);

// globals

volatile int ind;
volatile u32 buffer[buff];
volatile int full;

int main()
{
    int Status;

    init_platform();

    print("Hello mfs\n\r");
    
    Status = init_gpio(XGPIOPS_BASEADDR);
    if (Status != XST_SUCCESS) {
         return XST_FAILURE;
    }
    clear_buffer();

    //Status = init_timer(&TimerInstance, XPAR_SCUTIMER_BASEADDR);
    //Status = init_intr(&Gpio, XGPIOPS_BASEADDR);
    Status = init_intr_system(&Gpio, XGPIOPS_BASEADDR);
    if (Status != XST_SUCCESS) {
         return XST_FAILURE;
    }

    while(1)
    {
        if (full == 1)
        {
            Xil_ExceptionDisable();
            //XGpioPs_IntrDisable(&Gpio, GPIO_BANK, (1 << Input_Bank_Pin));
            flush_buffer();
            //XScuTimer_EnableAutoReload(&TimerInstance);
            //XScuTimer_Start(&TimerInstance);
            //XGpioPs_IntrEnable(&Gpio, GPIO_BANK, (1 << Input_Bank_Pin));
            Xil_ExceptionEnable();
        }
    }
    
    
    cleanup_platform();
    while(1);
    return Status;
}

void clear_buffer(void)
{
   for (int i=0; i<buff; i++)
    {
        buffer[i] = 0;
    }

    full = 0;
    ind = 0; 

    printf("Cleared buffer\r\n");
}

void flush_buffer(void)
{
    for (int i=0; i<buff; i++)
    {   
        printf("0x%x\r\n", buffer[i]);
    }

    full = 0;
    ind = 0;
    printf("Flushed buffer\r\n");
}

u32 combine(u32 data[width])
{
    u32 result = 0;
    for (int i=0; i<width; i++)
    {
        result |= (data[i] << i);
    }

    return result;
}

int init_gpio(UINTPTR BaseAddress)
{
    int Status;
    XGpioPs_Config *ConfigPtr;

    /* Initialize the GPIO driver. */
	ConfigPtr = XGpioPs_LookupConfig(BaseAddress);

	Status = XGpioPs_CfgInitialize(&Gpio, ConfigPtr,
				       ConfigPtr->BaseAddr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    printf("Initialization complete\r\n");

    /* Set the direction for the specified pins to be input. */
    for (int i=0; i<width; i++)
    {
        XGpioPs_SetDirectionPin(&Gpio, i+offset, 0x0);
    }

    printf("Direcion on pins set\r\n");

    return XST_SUCCESS;
}

int init_timer(XScuTimer * TimerInstancePtr,	UINTPTR BaseAddress)
{
    int Status;
    XScuTimer_Config *ConfigPtr;

    /* Initialize the Scu Private Timer driver. */
    ConfigPtr = XScuTimer_LookupConfig(BaseAddress);
    
    Status = XScuTimer_CfgInitialize(TimerInstancePtr, ConfigPtr,
					ConfigPtr->BaseAddr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    /*
	 * Perform a self-test to ensure that the hardware was built correctly.
	 */
	Status = XScuTimer_SelfTest(TimerInstancePtr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    /*
	 * Connect the device to interrupt subsystem so that interrupts
	 * can occur.
	 */
   Status = XSetupInterruptSystem(TimerInstancePtr, &IntrHandler,
                                    TimerInstancePtr->Config.IntrId,
                                    TimerInstancePtr->Config.IntrParent,
                                    XINTERRUPT_DEFAULT_PRIORITY);
	/*
	 * Enable the timer interrupts for timer mode.
	 */
	XScuTimer_EnableInterrupt(TimerInstancePtr);

    if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    XScuTimer_EnableAutoReload(TimerInstancePtr);

    XScuTimer_LoadTimer(TimerInstancePtr, TIMER_LOAD_VALUE);

    XScuTimer_Start(TimerInstancePtr);
    
    printf("Started timer\r\n");

    return XST_SUCCESS;
}

int init_intr(XGpioPs *Gpio,	UINTPTR BaseAddress)
{
    int Status;
    XGpioPs_Config *ConfigPtr;

    /* Initialize the Scu Private Timer driver. */
    ConfigPtr = XGpioPs_LookupConfig(BaseAddress);

    /*
	 * Connect the device to interrupt subsystem so that interrupts
	 * can occur.
	 */
     /* Enable falling edge interrupts for all the pins in GPIO bank. */
    XGpioPs_SetIntrType(Gpio, GPIO_BANK, 0x00, 0xFFFFFFFF, 0x00);

    /* Set the handler for gpio interrupts. */
	XGpioPs_SetCallbackHandler(Gpio, (void *)Gpio, IntrHandler);

    /* Enable the GPIO interrupts of GPIO Bank. */
	XGpioPs_IntrEnable(Gpio, GPIO_BANK, (1 << Input_Bank_Pin));
        
    Status = XSetupInterruptSystem(Gpio, &XGpioPs_IntrHandler,
				       ConfigPtr->IntrId,
				       ConfigPtr->IntrParent,
				       XINTERRUPT_DEFAULT_PRIORITY);
    if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}
    XGpioPs_SetCallbackHandler(Gpio, (void *)Gpio, IntrHandler);
	/*
	 * Enable the timer interrupts for timer mode.
	 */
    
    printf("Started interrupt system\r\n");

    return XST_SUCCESS;
}

// sets up the interrupt system and enables interrupts for IRQ_F2P[1:0]
int init_intr_system() {

    int result;
    XScuGic *intc_instance_ptr = &intc;
    XScuGic_Config *intc_config;

    // get config for interrupt controller
    //intc_config = XScuGic_LookupConfig(XPAR_PS7_SCUGIC_0_DEVICE_ID);
    intc_config = XScuGic_LookupConfig(XPAR_XSCUGIC_0_BASEADDR);
    if (NULL == intc_config) {
        return XST_FAILURE;
    }

    // initialize the interrupt controller driver
    result = XScuGic_CfgInitialize(intc_instance_ptr, intc_config, intc_config->CpuBaseAddress);

    if (result != XST_SUCCESS) {
        return result;
    }

    // set the priority of IRQ_F2P[0:0] to 0xA0 (highest 0xF8, lowest 0x00) and a trigger for a rising edge 0x3.
    XScuGic_SetPriorityTriggerType(intc_instance_ptr, INTC_INTERRUPT_ID_0, 0xA0, 0x3);

    // connect the interrupt service routine isr0 to the interrupt controller
    result = XScuGic_Connect(intc_instance_ptr, INTC_INTERRUPT_ID_0, (Xil_ExceptionHandler)IntrHandler, (void *)&intc);

    if (result != XST_SUCCESS) {
        return result;
    }

    // enable interrupts for IRQ_F2P[0:0]
    XScuGic_Enable(intc_instance_ptr, INTC_INTERRUPT_ID_0);



    if (result != XST_SUCCESS) {
        return result;
    }


    // initialize the exception table and register the interrupt controller handler with the exception table
    Xil_ExceptionInit();

    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, intc_instance_ptr);

    // enable non-critical exceptions
    Xil_ExceptionEnable();

    

    s32 res = XScuGic_SelfTest(intc_instance_ptr);
    
    printf("This part works: %d", (int)res);

    return XST_SUCCESS;
}

static void IntrHandler(void *CallBackRef)
{
	//XScuTimer *TimerInstancePtr = (XScuTimer *) CallBackRef;
//    u32 data[width];
//    u32 buf_data;


	/*
	 * Check if the timer counter has expired, checking is not necessary
	 * since that's the reason this function is executed, this just shows
	 * how the callback reference can be used as a pointer to the instance
	 * of the timer counter that expired, increment a shared variable so
	 * the main thread of execution can see the timer expired.
	 */
//	if (XScuTimer_IsExpired(TimerInstancePtr)) {
//		XScuTimer_ClearInterruptStatus(TimerInstancePtr);
//		TimerExpired++;
		if (ind == buff) {
			//XScuTimer_DisableAutoReload(TimerInstancePtr);
            full = 1;
            //XScuTimer_Stop(TimerInstancePtr);
            Xil_ExceptionDisable();
		}
        else 
        {
//            for (int i=0; i<width;i++)
//            {
//                data[i] = XGpioPs_ReadPin(&Gpio, i+offset);
//            }
//            buf_data = combine(data);
//            buffer[ind] = buf_data;
            buffer[ind] = XGpioPs_Read(&Gpio, GPIO_BANK);
            ind++;
        }
	//}

}

